# NOT READY YET


# Introduction

This tool is designed to automate the process of setting up a
dedicated **ITG Machine** within a **Debian GNU Linux**
environment. The objective is to operate it on a standalone machine
without any other users or programs.

**ITGMania** and several essential utilities will be deployed on the
machine. Auto login and auto start will be configured.

# WARNING

Certain actions performed by this tool involve managing machine's disk
and partitions. Exercise caution when using this tool. There are no
guarantees provided.

# Install Debian

## USB

Installer expects you install minimal **GNU Debian Linux** version
**using netinst cd image**.

Use, for example the following link:
https://cdimage.debian.org/cdimage/daily-builds/daily/arch-latest/amd64/iso-cd/debian-testing-amd64-netinst.iso

## Firmware

Non free firmware is not included into Debian Installer by
default. Download them if needed:
https://cdimage.debian.org/cdimage/firmware/trixie/20240701/firmware.tar.gz

## Network

If network is not available (because firmware is missing) ignore it
and proceed without network configuration. We will deal with it later.

## Setup user

Installer creates default user and it will be used for running **ITG
Machine**.  By default `itg` user will be used.

## UEFI

**ITG Machine** is running with `UEFI` without GRUB

## Disk

To make backups work an additional partition same size as root should
be created.  This partition will be used as raw backup. **ITG
Machine** can be later backed up via boot menu option by copying root
partition. Backup partition can be smaller then root partition, but it
still must be larger than total used space. Better keep size same.
Under rescue circumstances it will be possible to restore data back
from backup partition or even boot directly from backup.

`Songs` folder takes most of the space but less important from system
point of view, so we can keep it on separate partition and exclude
from backups.

The following layout is recommended:

- UEFI: 200 MB, Boot flag on
- Root: 35 GB, Ext4, /, SET PARTLABEL=root
  - You can make root partition less or more depending on your drive capacity
  - OS and ITGMania takes less than 1 GB
  - Log files, ITGMania save files can take some space
  - Additional packages, drivers can take some space too
  - For experiments, installing SDK, building **ITGMania** from scratch more space is needed
  - 20-35 GB is enough for experiments, install additional games
- Backup: 35 GB, do nothing, SET PARTLABEL=backup
  - Same size as Root partition
  - Can be smaller until total used space by Root fits in partition
  - However, not recommended to make it smaller
- Songs: 100 GB+, Ext4, do not mount partition, SET PARTLABEL=songs
  - It depends on your songs' collection
- Any other partitions you need

For running **ITGMania** with enough RAM swap is not required.

## Reboot

Reboot to your fresh installed system, install required firmware, etc.



# ITG Machine Installer

Copy this project onto target machine and run `./install.sh`.


This tool:

- Downloads **ITGMania** archives into *ITGMACHINE_CACHE*
  (/var/cache/itgmachine)
- Installs **ITGMania** into *ITGMACHINE_INSTALL* (/usr/local/games)
- Creates or updates */usr/local/games/itgmania* symlink

