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

The Synology doc on SHR shows the stripes being as large as their smallest drive. I'm thinking instead that the stripe size should be like 1%, 5%, or 10% of the smallest drive. If we leave room for one 5% stripe on each drive, that could be considerable overhead (150 GB on a 3000 GB drive), but may be acceptable. For example this sort of over-provisioning is often done when deploying redundant servers, for example.

Also leaving space for one stripe at the end can also help us account for drives which are not precisely the same size, like a 3TB drive may be different between manufacturers.


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
truncate -s150m disk{2..3}
truncate -s200m disk{4..6}

for i in {1..6}; do losetup /dev/loop$i /root/disk$i; done

# Create partitions
for disk in /dev/loop{1..6}; do
	fdisk $disk << EOF
o
n
p
1
2048
+90M
w
EOF
done

for disk in /dev/loop{2..6}; do
	fdisk $disk << EOF
n
p
2

+50M
w
EOF
done

for disk in /dev/loop{4..6}; do
	fdisk $disk << EOF
n
p
3

+50M
w
EOF
done

# Tell the kernel about the new partitions
for i in {1..6}; do partx -a /dev/loop$i; done
```

## LVM on MD
```shell
# Create MD arrays
mdadm --create /dev/md0 --level 5 --raid-devices=6 /dev/loop{1..6}p1
mdadm --create /dev/md1 --level 5 --raid-devices=5 /dev/loop{2..6}p2
mdadm --create /dev/md2 --level 5 --raid-devices=3 /dev/loop{4..6}p3
cat /proc/mdstat

# Create VG using the MD arrays as PVs
vgcreate test /dev/md{0..2}
vgs 
# VSize: 716m

# Can remove a PV
vgreduce test /dev/md2


# Teardown
mdadm --stop /dev/md0
mdadm --stop /dev/md1
mdadm --stop /dev/md2
```

## LVM on ZFS
```
# TODO
```


# Performance
We're likely going to pay a performance penalty in exchange for flexibility. How bad is it?

TODO