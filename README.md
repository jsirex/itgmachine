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

## Prepare USB Drive

Installer expects you install minimal **GNU Debian Linux** version
**using netinst cd image**.

Use, for example the following link:
https://cdimage.debian.org/cdimage/daily-builds/daily/arch-latest/amd64/iso-cd/debian-testing-amd64-netinst.iso

Or you can take a full CD/DVD installation. It depends on required
software at the very early stage. For example you need to install
**network manager** with WiFi support. Minimal Debian installation
does not have **network manager** or **wpa_supplicant**.

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

**ITG Machine** is running with `UEFI` without GRUB. If you don't have
hardware with `UEFI` support just keep grub and don't select `Install
kernel to UEFI partition`.

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
  - Can be smaller until total used space by `root` fits into partition
  - However, not recommended to make it smaller
- Songs: 100 GB+, Ext4, do not mount partition, SET PARTLABEL=songs
  - It depends on your songs' collection
- Any other partitions you need

For running **ITGMania** with enough RAM swap is not required.

## Reboot

Reboot to your fresh installed system, install required firmware, etc.

# ITG Machine Installer

Copy this project onto target machine and run `./install.sh`.
Curently only `install.sh` is used, so you can do **curl+bash**
magic. At this point it is expected that you have a mininmal Debian
system installed and running.

**Internet access** must be provided. Your options:
- Plug network cable (easiest way). Temporary. Until you install
  everything and go offline or switch to something else
- Plug your phone using USB and choose `USB Tethering` (also easy
  way). Now your phone is an old-gold modem connected to Internet. At
  least it works for Android
- You have configured Internet access somehow

*HINT: If you connected with Android or cabel just type `dhclient` to
setup network. It requires only before you get your network manager.*
