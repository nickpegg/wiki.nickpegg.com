# Background
Many RAID systems are pretty rigid:

* Once you set up a group of drives, you can't resize the group by adding/removing drives
* You can't mix and match sizes in a meaningful way - it will only use as much as your smallest drive on each drive
	* If you have a group of a 1TB drive and two 2TB drives, it's as if you only have 3 1TB drives
	* Some RAID systems can expand to a new minimum-drive size, but only when _all_ drives in the group are at least that size

Synology has a way of working around this that they call [Synology Hybrid RAID (SHR)](https://kb.synology.com/en-us/DSM/tutorial/What_is_Synology_Hybrid_RAID_SHR), coming in a SHR-1 flavor (RAID-5 like, 1 drive of redundancy) and SHR-2 flavor (RAID-6 like, 2 drive redundancy).

At a basic level, SHR works by striping many disparate RAID groups across the drives in order to bin-pack them, where not all drives will have all RAID groups. This is easier to show with a picture, see the link to SHR above for an example


# Methods
Requirements:

- Some sort of software RAID system where we can create and delete RAID groups as we need
- Some sort of logical volume system that can combine multiple RAID groups into a logical pool. Must support arbitrarily adding/removing devices.
- Some way of evacuating a RAID group in case we need to reconfigure it (permanently add/remove drives)

MD RAID and ZFS RAID fit the bill for the RAID part. LVM fits the bill for logical volumes and has a way to evacute physical volumes for removal from a volume group. For ZFS, it doesn't appear you can remove top-level raidz vdevs from a pool, so a pool of multiple raidzs won't work.

Possbile methods:

- LVM on MD RAID
- LVM using ZFS block devices on ZFS RAID
	- This seems really greasy, ZFS has the ability to create block devices (ZVOLs) but ZFS seems to want to fill LVM's role



# Design
## Metadata
With a partitioning/RAID scheme this complex, we need to be able to store metadata to describe the layout. 

I'm thinking that each drive can hold a small ext4 partition at the beginning and store a YAML file that describes the layout. This isn't the most space-efficient thing in the world, but is very straightforward for troubleshooting purposes by humans - mount the drive, inspect the YAML, edit if needed.

The metadata should contain:

- A UUID for identifying the pool
- An only-increasing version number, so that if we read conflicting metadata files from multiple drives, the one with the highest version number is the one we can trust

## Stripe Size
"Stripe Size" here refers to the size of a given RAID group that's striped across the drives. 

Since we want to maintain the ability to drain a stripe for maintenance, e.g. permanent removal of a drive, we want to either maintain a blank slot for a strip on each drive, or only allow operations if the pool has as much free space as one stripe (to be able to drain it). Therefore, the stripe size should be fairly small to not waste a bunch of space.

The Synology doc on SHR shows the stripes being as large as their smallest drive. I'm thinking instead that the stripe size should be like 1%, 5%, or 10% of the smallest drive. If say we leave room for one 5% stripe on each drive, that could be considerable overhead (150 GB on a 3000 GB drive), but may be acceptable. For example this sort of over-provisioning is often done when deploying redundant servers, for example.

Also leaving space for one stripe at the end can also help us account for drives which are not precisely the same size, like a 3TB drive may be different between manufacturers.


Something that may force our hand on strip size: GPT only supports 128 partitions. This means the minimum stripe size must be greater than: (largest drive size) / 128.

Extreme example, 20TB drive mixed with a 1TB drive:

- 20000 GB / 128 = 156.25 GB min stripe size
- 156.25 / 1000 = 15.625%



# Test - Manual Implementation
Disk setup:

- 1x 100 mb
- 2x 150 mb
- 3x 200 mb

We won't create a metadata partition, instead will just keep track of everything ourselves. This is a PoC and handy for benchmarks.

## Install pkgs
```
sudo apt install mdadm zfsutils-linux lvm2
```

## Create fake disks
```bash
truncate -s100m disk1
truncate -s200m disk{2..3}
truncate -s300m disk{4..6}

for i in {1..6}; do losetup /dev/loop$i /root/disk$i; done

# Create partitions
for disk in /dev/loop{1..6}; do
	fdisk $disk << EOF
g
n
1

+90M
w
EOF
done

for disk in /dev/loop{2..6}; do
	fdisk $disk << EOF
n
2

+99M
w
EOF
done

for disk in /dev/loop{4..6}; do
	fdisk $disk << EOF
n
3

+99M
w
EOF
done

# Tell the kernel about the new partitions
for i in {1..6}; do partx -a /dev/loop$i; done
```

## LVM on MD
```shell
# Create MD arrays
mdadm --create /dev/md/slice0 --level 5 --raid-devices=6 /dev/loop{1..6}p1
mdadm --create /dev/md/slice1 --level 5 --raid-devices=5 /dev/loop{2..6}p2
mdadm --create /dev/md/slice2 --level 5 --raid-devices=3 /dev/loop{4..6}p3
cat /proc/mdstat
# Note that MD gives auto-generated names for these arrays in /proc/mdstat. /etc/md/* are symlinks to /dev/md*.

# Create VG using the MD arrays as PVs
vgcreate pool /dev/md/slice{0..2}
vgs
# VSize: 1012m

# Can remove a PV
vgreduce pool /dev/md/slice2
vgs


# Teardown
vgremove pool
pvremove /dev/md/slice*
for dev in $(ls /dev/md/slice*); do mdadm --stop $dev; done
for dev in $(ls /dev/loop*p*); do mdadm --zero-superblock $dev; done
```

## LVM on ZFS
```shell 
zpool create pool1 raidz /dev/loop{1..6}p1
zpool create pool2 raidz /dev/loop{2..6}p2
zpool create pool3 raidz /dev/loop{4..6}p3

# These are really messy numbers. They don't equal the size of the pool, there seems to be some overhead with ZFS here
zfs create -V 275M pool1/vol
zfs create -V 220M pool2/vol
zfs create -V 80M pool3/vol

# Create VG
vgcreate test /dev/zvol/pool*/vol
vgs
# VSize: 564m

# Teardown
vgremove test
pvremove /dev/zvol/pool*/vol
zpool destroy pool1
zpool destroy pool2
zpool destroy pool3
for dev in $(ls /dev/loop*p*); do dd if=/dev/zero bs=1M of=$dev; done
```


# Performance
We're likely going to pay a performance penalty in exchange for flexibility. How bad is it?

Test 1, ext4 on the MD arrays

Test 2, ext4 on a LV that's across all the MD arrays

