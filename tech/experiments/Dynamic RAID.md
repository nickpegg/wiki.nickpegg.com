# Background
Many RAID systems are pretty rigid:
- Once you set up a group of drives, you can't resize the group by adding/removing drives
- You can't mix and match sizes in a meaningful way - it will only use as much as your smallest drive on each drive
	- If you have a group of a 1TB drive and two 2TB drives, it's as if you only have 3 1TB drives
	- Some RAID systems can expand to a new minimum-drive size, but only when _all_ drives in the group are at least that size

Synology has a way of working around this that they call [Synology Hybrid RAID (SHR)](https://kb.synology.com/en-us/DSM/tutorial/What_is_Synology_Hybrid_RAID_SHR), coming in a SHR-1 flavor (RAID-5 like, 1 drive of redundancy) and SHR-2 flavor (RAID-6 like, 2 drive redundancy).

At a basic level, SHR works by striping many disparate RAID groups across the drives in order to bin-pack them, where not all drives will have all RAID groups. This is easier to show with a picture, see the link to SHR above for an example


# Methods
Requirements:
- Some sort of software RAID system where we can create and delete RAID groups as we need
- Some sort of logical volume system that can combine multiple RAID groups into a logical pool. Must support arbitrarily adding/removing devices.
- Some way of evacuating a RAID group in case we need to reconfigure it (permanently add/remove drives)

MD RAID and ZFS RAID fit the bill for the RAID part. LVM fits the bill for logical volumes and has a way to evacute physical volumes for removal from a volume group.

- [ ] Does ZFS support adding/removing devices willy-nilly from pools?

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


# Test Implementation
TODO


# Performance
We're likely going to pay a performance penalty in exchange for flexibility. How bad is it?

TODO