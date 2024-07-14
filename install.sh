#!/usr/bin/env bash
# -*- mode: bash-ts -*-

# If you think I forgot about set -e:
# Nope, I didn't. It just does not work as you expected:
#     set -e
#     somefunc() {
#             echo true
#             false
#             echo should not run
#     }
#     somefunc || true
# Prints "should not run"

set -u

# Global variables keep installer state
# Default screen title can be overwritten in screen menu
screen_title="ITG Machine"

itgmachine_apt_updated="false"
itgmachine_efi_dir="/boot/efi/EFI/itgmachine"

### Whiptail interface
# Each function unsets or returns wt_out
msgbox() {
    local message="$1"
    local height=10
    local lines=0
    unset wt_out # nothing to out

    lines=$(echo "$message" | wc -w)
    if [[ "$lines" -gt 40 ]]; then height=25; fi

    whiptail --title "$screen_title" \
	     --backtitle "Use <up>/<down> to navigate, <enter> to select, <tab> to switch between buttons." \
	     --scrolltext \
             --msgbox "$message" $height 80
}

yesnobox() {
    local message="$1"
    local height=10
    local lines=0
    unset wt_out # nothing to out

    lines=$(echo "$message" | wc -w)
    if [[ "$lines" -gt 40 ]]; then height=25; fi

    whiptail --title "$screen_title" \
	     --backtitle "Use <up>/<down> to navigate, <enter> to select, <tab> to switch between buttons." \
             --yesno "$message" $height 80
}

inputbox() {
    local message="$1"
    local default="$2"
    unset wt_out
    wt_out=$(whiptail --title "$screen_title" \
		      --backtitle "Use <up>/<down> to navigate, <enter> to select, <tab> to switch between buttons." \
		      --inputbox "$message" 10 80 \
                      "$default" 3>&1 1>&2 2>&3)
}

passbox() {
    local message="$1"
    local default="$2"
    wt_out=$(whiptail --title "$screen_title" \
		      --backtitle "Use <up>/<down> to navigate, <enter> to select, <tab> to switch between buttons." \
		      --passwordbox "$message" 10 80 \
                      "$default" 3>&1 1>&2 2>&3)
}

textbox() {
    local file="$1";
    unset wt_out # nothing to out

    whiptail --title "$screen_title" \
	     --backtitle "Use <up>/<down> to navigate, <enter> to select, <tab> to switch between buttons." \
             --scrolltext \
             --textbox "$file" 25 80
}

radiobox() {
    local text="Choose item from the list below:"
    local wtst

    if [[ $(($# % 3)) -eq 1 ]]; then text="$1"; shift; fi
    local items=("$@")

    while :; do
	wt_out=$(whiptail --title "$screen_title" \
			  --backtitle "Use <up>/<down> to navigate, <space> to select, <tab> to switch between buttons." \
			  --ok-button "Select" \
			  --cancel-button "Back" \
			  --notags \
			  --radiolist "$text" \
                          25 80 16 \
                          "${items[@]}" 3>&1 1>&2 2>&3)
	wtst=$?
	if [[ $wtst -ne 0 ]]; then return $wtst; fi
	if [[ -n "$wt_out" ]]; then return 0; fi

	msgbox "Nothing was selected. HINT: Use space to select an item."
    done

    # never can get here
    return 100
}

checkbox() {
    local text="Choose items from the list below:"
    local wtst

    if [[ $(($# % 3)) -eq 1 ]]; then text="$1"; shift; fi
    local items=("$@")

    while :; do
	wt_out=$(whiptail --title "$screen_title" \
			  --backtitle "Use <up>/<down> to navigate, <space> to select, <tab> to switch between buttons." \
			  --ok-button "Select" \
			  --cancel-button "Back" \
			  --notags \
			  --checklist "$text" \
                          25 80 16 \
                          "${items[@]}" 3>&1 1>&2 2>&3)
	wtst=$?
	if [[ $wtst -ne 0 ]]; then return $wtst; fi
	if [[ -n "$wt_out" ]]; then return 0; fi

	msgbox "Nothing was selected. HINT: Use space to select an item."
    done

    # never can get here
    return 100
}

menubox() {
    # screen title can be changed in submenu
    # this way we recursively persist it for the selected menu
    local title="$screen_title"
    local selected="none"
    local text="Select an action:"
    local wtst

    if [[ $(($# % 2)) -eq 1 ]]; then text="$1"; shift; fi
    local items=("$@")

    while :; do
	wt_out=$(whiptail --title "$title" \
			  --backtitle "Use <up>/<down> to navigate, <enter> to select, <tab> to switch between buttons." \
			  --ok-button "Select" \
			  --cancel-button "Back" \
			  --notags \
			  --default-item "$selected" \
			  --menu "$text" \
                          25 80 16 \
                          "${items[@]}" 3>&1 1>&2 2>&3)
	wtst=$?
	selected="$wt_out"
	if [[ $wtst -ne 0 ]]; then return $wtst; fi
	if [[ "$wt_out" == screen_* ]]; then $wt_out; else return 0; fi
    done

    # never can get here
    return 100
}

# Runs command and delays so you can see result
run() {
    "$@" || { echo "Exist status $?. Press enter to continue"; read -r; return 1; }
}

screen_console_tools() {
    screen_title="ITG Machine - Console Tools"

    yesnobox "Install vim mc curl git htop?" \
	     && screen_apt_package vim mc curl git htop
}

screen_fstab_validate() {
    local out

    if ! out=$(findmnt --verify); then
	msgbox "/etc/fstab validation failed:\n$out"
	return 1
    fi
}

screen_fstab() {
    screen_title="ITG Machine - FSTab"

    local updates
    local fstabroot
    local fstabsongs

    #screen_partition_validate "$root_partition" || return 1
    #screen_partition_validate "$songs_partition" || return 1

    if [[ "$root_partition" != "SKIP" ]]; then
	if fstabroot=$(findmnt -n --fstab -o SOURCE --target /); then
	    updates="$updates s|$fstabroot|$root_partition|;"
	else
	    msgbox "Installer couldn't detect root in fstab. Running validation.."
	    screen_fstab_validate
	fi
    fi

    if [[ "$songs_partition" != "SKIP" ]]; then
	if fstabsongs=$(findmnt -n --fstab -o SOURCE --target /home/itg/.itgmania/Songs); then
	    updates="$updates s|$fstabsongs|$songs_partition|;"
	else
	    echo "$songs_partition	/home/itg/.itgmania/Songs	ext4	discard,noatime,nodiratime,errors=remount-ro	0	0" >> /etc/fstab
	    screen_fstab_validate
	fi
    fi

    sed -i.bak "$updates" /etc/fstab
}


fstab_flash() {
    # todo: songs nofail, usb nofail
    cat << EOF > /tmp/fstab
/dev/disk/by-path/pci-0000:00:13.2-usb-0:6:1.0-scsi-0:0:0:0-part1       /mnt/P1 auto    rw,noatime,noauto,user  0       0
/dev/disk/by-path/pci-0000:00:13.2-usb-0:6:1.0-scsi-0:0:0:0             /mnt/P1 auto    rw,noatime,noauto,user  0       0

/dev/disk/by-path/pci-0000:00:13.2-usb-0:5:1.0-scsi-0:0:0:0-part1       /mnt/P2 auto    rw,noatime,noauto,user  0       0
/dev/disk/by-path/pci-0000:00:13.2-usb-0:5:1.0-scsi-0:0:0:0             /mnt/P2 auto    rw,noatime,noauto,user  0       0
EOF

}

ensure_root() {
    if [[ $UID -ne 0 ]]; then
        msgbox "You must run this program as root"
	exit 1
    fi
}

screen_apt_package() {
    screen_title="ITG Machine - Package install"
    screen_apt_update && run apt install "$@"
}

ensure_command() {
    cmd="$1"
    package="${2:-$cmd}"

    command -v "$cmd" &> /dev/null && return 0

    yesnobox "Command $cmd was not found.\nInstall $package?" \
	&& screen_apt_package "$package"
}

ensure_itgmachine_cache() {
    mkdir -p $ITGMACHINE_CACHE
}

install_itgmania() {
    archive="ITGmania-$1-Linux-no-songs.tar.gz"
    name=$(basename "$archive" .tar.gz)
    url="https://github.com/itgmania/itgmania/releases/download/v$1/ITGmania-$1-Linux-no-songs.tar.gz"

    ensure_itgmachine_cache
    ensure_command curl

    if [[ ! -f "$ITGMACHINE_CACHE/$archive" ]]; then
	if ! curl -fL --progress-bar -o "$ITGMACHINE_CACHE/$archive" "$url"; then
	    msgbox "Failed to download version: $version from\n$url"
	    return 1
	fi
    fi

    mkdir -p "/usr/local/games/$name"
    tar -C "/usr/local/games/$name" -xf "$ITGMACHINE_CACHE/$archive" "$name/itgmania" --strip-components 2
    ln -sfn "/usr/local/games/$name" /usr/local/games/itgmania
}

screen_apt_repository() {
    screen_title="ITG Machine - APT"

    local url="https://ftp.debian.org/debian"
    local release="testing"
    local components="main contrib non-free non-free-firmware"

    true \
	&& inputbox "Enter Debian repository URL:" "$url" \
	&& url="$wt_out" \
	&& inputbox "Enter Debian Release:" "$release" \
	&& release="$wt_out" \
	&& inputbox "Enter Debian components:" "$components" \
	&& components="$wt_out" \
	&& yesnobox "Replace source.list with:\ndeb $url $release $components" \
	&& echo "deb $url $release $components" > /etc/apt/sources.list \
	&& screen_apt_update 1
}

screen_apt_update() {
    if [[ $# -gt 0 ]]; then itgmachine_apt_updated="false"; fi
    if [[ "$itgmachine_apt_updated" == "true" ]]; then return 0; fi

    run apt -o APT::Update::Error-Mode=any update \
	&& itgmachine_apt_updated="true"
}

screen_apt_upgrade() {
    screen_title="ITG Machine - Upgrading"
    screen_apt_update && run apt dist-upgrade
}

screen_itgmania_install() {
    version="$1"

    if [[ -z "$version" ]]; then
        inputbox "Enter ITGmania version in form: X.Y.Z" || return 1
        version="$wt_out"
    fi

    install_itgmania "$version" \
	&& screen_apt_package libusb-0.1-4 libgl1 libglvnd0 libglu1-mesa libxtst6 libxinerama1 libgdk-pixbuf-2.0-0 libgtk-3-0t64
}

screen_mount_songs() {
    local user=itg
    local itgmania=/home/itg/.itgmania
    local songs=$itgmania/Songs

    [[ -d "$itgmania" ]] || mkdir "$itgmania"
    chown itg:itg $itgmania
    chown itg:itg $itgmania/Songs

    if ! mountpoint -q /home/itg/.itgmania/Songs; then
	mount -o discard,noatime,nodiratime,errors=remount-ro PARTLABEL=songs /home/itg/.itgmania/Songs
    fi

    grep /home/itg/.itgmania/Songs /etc/fstab ||
	echo "PARTLABEL=songs	/home/itg/.itgmania/Songs	ext4	discard,noatime,nodiratime,errors=remount-ro	0	0" >> /etc/fstab

    # This changes permissions inside mounted partition
    chown itg:itg /home/itg/.itgmania/Songs/.
}

screen_disk_validate() {
    if [[ -z "$current_disk" ]]; then
	msgbox "Current disk is empty. Select disk from menu:
Setup System (second boot) -> Select disk"
	return 1
    fi

    if [[ ! -b "$current_disk" ]]; then
	msgbox "WARNING: Current disk '$current_disk' does not look like block device.
This is unexpected situation by installer.
Probably you need to sumbit a bug."
	return 1
    fi
}

screen_disk() {
    screen_title="ITG Machine - Disk"

    local menuitems=()

    while read -r varline; do
	eval "local $varline"
	menuitems+=("$NAME|$PTTYPE" "$NAME ($MODEL) $PTTYPE")
    done < <(lsblk -dnpP -o NAME,MODEL,PTTYPE)

    menubox "Select drive where system is installed:" "${menuitems[@]}" || return 1
    IFS='|' read -r current_disk current_disk_pttype <<< "$wt_out"

    screen_disk_validate
}

screen_partition_validate() {
    local partition="$1"

    if [[ $# -eq 0 ]]; then partition="$current_partition"; fi
    if [[ "$partition" == "SKIP" ]]; then return 0; fi

    if [[ -z "$partition" ]]; then
	msgbox "Current partition is not set"
	return 1
    fi

    if [[ ! -b "$partition" ]]; then
	msgbox "WARNING: Current partition '$partition' does not look like block device.
This is unexpected situation by installer.
Probably you need to sumbit a bug."
	return 1
    fi
}

screen_partition_select() {
    local message="$1"
    local menuitems=()

    screen_disk_validate || return 1

    while read -r varline; do
	eval "local $varline"
	menuitems+=("$NAME|$PARTLABEL|$PARTN" "$NAME $PARTLABEL $LABEL $FSTYPE $UUID")
    done < <(lsblk -npP -o NAME,PARTLABEL,LABEL,FSTYPE,UUID,PARTN -Q 'TYPE=="part"' "$current_disk")
    menuitems+=("SKIP|SKIP|0" "Skip partition configuration")

    menubox "$message" "${menuitems[@]}" || return 1
    IFS='|' read -r current_partition current_partition_label current_partition_no <<< "$wt_out"

    screen_partition_validate
}

screen_partition_setlabel() {
    local partlabel="$1"

    screen_disk_validate || return 1
    screen_partition_validate || return 1

    if [[ "$current_partition" == "SKIP" ]]; then
	msgbox "Refuse set PARTLABEL='$partlabel', partition skipped"
	return 2
    fi

    if [[ -z "$partlabel" ]]; then
	inputbox "Partition '$current_partition' has label '$current_partition_label'.
Enter new partition label:" || return 1
	partlabel="$wt_out"
    fi

    if [[ "$current_partition_label" == "$partlabel" ]]; then return 0; fi

    yesnobox "Set partition label for '$current_disk' partion number '$current_partition_no'?
partition: $current_partition
old label: $current_partition_label
new label: $partlabel" || return 1

    run sfdisk --part-label "$current_disk" "$current_partition_no" "$partlabel" \
	&& current_partition_label="$partlabel"
}

screen_partitions_gpt() {
    screen_title="ITG Machine - Partitions (GPT)"

    screen_disk_validate || return 1

    root_partition=$(blkid -t PARTLABEL=root -o device "$current_disk"*)
    backup_partition=$(blkid -t PARTLABEL=backup -o device "$current_disk"*)
    songs_partition=$(blkid -t PARTLABEL=songs -o device "$current_disk"*)

    if [[ -n "$root_partition" ]]; then
	msgbox "Root partition ($root_partition) has been auto-detected by partition label."
	root_partition="PARTLABEL=root"
    else
	screen_partition_select "Select root partition" || return 1; root_partition="$current_partition"
	screen_partition_setlabel root && root_partition="PARTLABEL=root"
    fi

    if [[ -n "$backup_partition" ]]; then
	msgbox "Backup partition ($backup_partition) has been auto-detected by partition label."
	backup_partition="PARTLABEL=backup"
    else
	screen_partition_select "Select backup partition" || return 1; backup_partition="$current_partition"
	screen_partition_setlabel backup && backup_partition="PARTLABEL=backup"
    fi

    if [[ -n "$songs_partition" ]]; then
	msgbox "Songs partition ($songs_partition) has been auto-detected by partition label."
	songs_partition="PARTLABEL=songs"
    else
	screen_partition_select "Select songs partition" || return 1; songs_partition="$current_partition"
	screen_partition_setlabel songs && songs_partition="PARTLABEL=songs"
    fi

    return 0
}

screen_partitions_manual() {
    screen_title="ITG Machine - Partitions (other)"

    screen_disk_validate || return 1

    msgbox "The partition type is not GPT. Installer
won't use PARTLABEL to detect and mount root, backup and songs
partitions.

WARNING! You can't use filesystem's LABEL or UUID because
filesystem's metadata will be copied with filesystem backup or
restore procedure.

Installer will offer you to use partition device directly. Sometimes
it is not reliable if you insert additional disks."

    screen_partition_select "Select root partition manually:" || return 1
    root_partition="$current_partition"
    screen_partition_select "Select backup partition manually:" || return 1
    backup_partition="$current_partition"
    screen_partition_select "Select songs partition manually:" || return 1
    songs_partition="$current_partition"

    return 0
}

screen_partitions() {
    screen_disk_validate || return 1

    if [[ "$current_disk_pttype" == "gpt" ]]; then
	screen_partitions_gpt || return 1
    else
	screen_partitions_manual || return 1
    fi

    msgbox "The following configuration will be used:
       main disk: $current_disk
  root partition: $root_partition
backup partition: $backup_partition
 songs partition: $songs_partition"
}

screen_network_manager() {
    screen_title="ITG Machine - Network Manager"
    screen_apt_update && run apt install network-manager
}

screen_uefi_dir() {
    if ! mountpoint -q /boot/efi; then
	msgbox "It looks like /boot/efi is not mounted. Do you have UEFI? Check and try again."
	return 1
    fi

    if [[ ! -d "/boot/efi/EFI" ]]; then
	msgbox "While your /boot/efi partition is mounted, there is no EFI directory. Something went wrong here."
	return 1
    fi

    if [[ -d "$itgmachine_efi_dir" ]]; then return 0; fi

    mkdir "$itgmachine_efi_dir" || { msgbox "Unable to create $itgmachine_efi_dir"; return 1; }
}

screen_kernel_uefi_hook() {
    local hook=/etc/kernel/postinst.d/zz-update-efi

    if [[ -x "$hook" && -f "$itgmachine_efi_dir/vmlinuz" ]]; then return 0; fi

    cat << EOF > "$hook" || { msgbox "Unable to create kernel hook: $hook"; return 1; }
#!/bin/sh
cp -v /vmlinuz $itgmachine_efi_dir

EOF
    chmod +x "$hook"
    run "$hook" || { msgbox "Error while running $hook"; return 1; }

    [[ -f "$itgmachine_efi_dir/vmlinuz" ]] || {
	msgbox "Something went wrong with kernel hook. File $itgmachine_efi_dir/vmlinuz was not found"
	return 1
    }
}

screen_initramfs_uefi_hook() {
    local hook=/etc/initramfs/post-update.d/zz-update-efi

    if [[ -x "$hook" && -f "$itgmachine_efi_dir/initrd.img" ]]; then return 0; fi

    mkdir -p "$(dirname "$hook")" || { msgbox "Unable to create directory for $hook"; return 1; }
    cat << EOF > "$hook" || { msgbox "Unable to create initramfs hook: $hook"; return 1; }
#!/bin/sh
cp -v /initrd.img $itgmachine_efi_dir

EOF
    chmod +x "$hook"
    run "$hook" || { msgbox "Error while running $hook"; return 1; }

    [[ -f "$itgmachine_efi_dir/initrd.img" ]] || {
	msgbox "Something went wrong with initramfs hook. File $itgmachine_efi_dir/initrd.img was not found"
	return 1
    }
}

screen_uefi_bootmgr() {
    local bootlabel="ITG Machine"
    local fstabroot fstabefi disk bootentry bootnum

    # Get root fs as in fstab
    fstabroot=$(findmnt -n --fstab -o SOURCE --target /)
    if [[ -z "$fstabroot" ]]; then
	msgbox "Unable to detect rootfs in /etc/fstab. This is unexpected"
	return 1;
    fi

    # Get efi boot, but resolve to a device name
    fstabefi=$(findmnt -ne --fstab -o SOURCE --target /boot/efi)
    if [[ -z "$fstabefi" ]]; then
	msgbox "Unable to detect EFI partition in /etc/fstab. Do you have it?"
	return 1;
    fi

    # Get disk by fstabefi device name
    disk=$(lsblk -ndpo pkname "$fstabefi")
    if [[ -z "$disk" ]]; then
	msgbox "Unable to detect disk for EFI partition $fstabefi. Bug in lsblk?"
	return 1;
    fi

    if bootentry=$(efibootmgr -u | grep "$bootlabel"); then
	bootnum="${bootentry:4:4}"
	yesnobox "UEFI Boot Entry '$bootlabel' is already exist:\n $bootentry\nDelete existing?" \
	    && run efibootmgr -b "$bootnum" -B || return 1
    fi

    run efibootmgr -c -g -L "$bootlabel" \
	-d "$disk" \
	-l '\EFI\itgmachine\vmlinuz' \
	-u "root=$fstabroot rw quiet nmi_watchdog=0 initrd=\\EFI\\itgmachine\\initrd.img"
}

screen_uefi() {
    screen_title="ITG Machine - UEFI"

    yesnobox "This can improve the boot time of your ITG Machine. When you turn on the machine, UEFI loads first. It then boots something from the EFI Boot partition, usually the Grub bootloader. Grub has its own settings and countdown timer, then it loads the ram disk (initramfs) and the kernel (vmlinuz). The kernel then initializes and runs the OS loader, which is Systemd in Debian. This setup skips Grub and directly loads the kernel when UEFI starts, making the boot process faster.

Continue?" || return 1

    true \
	&& screen_uefi_dir \
	&& screen_kernel_uefi_hook \
	&& screen_initramfs_uefi_hook \
	&& screen_uefi_bootmgr \
	&& msgbox "All checks have passed! You are on UEFI now. If something goes wrong you still have your previous boot options. You can choose different boot options from UEFI Boot Menu."
}

screen_network_wifi() {
    screen_title="ITG Machine - WIFI"
    ensure_command nmcli network-manager

    local menuitems=()
    local wifi_networks

    wifi_networks=$(nmcli -g SSID,RATE,BARS device wifi list)

    while IFS=: read -r ssid rate bars; do
        menuitems+=("screen_wifi_connect $ssid")
        menuitems+=("$ssid ($rate $bars)")
    done <<< "$wifi_networks"

    menubox "${menuitems[@]}"
}

screen_wifi_connect() {
    local ssid="$1"

    ensure_command nmcli network-manager \
	&& passbox "Enter password for $ssid" \
	&& run nmcli device wifi connect "$ssid" password "$wt_out"
}

screen_sound_pipewire() {
    screen_apt_package pipewire pipewire-audio wireplumber
    # wpctl get|set-volume ID 0.8
}

screen_sddm() {
    screen_apt_package --no-install-recommends \
		       --no-install-suggests \
		       sddm

    mkdir -p /etc/sddm.conf.d
    cat << EOF > /etc/sddm.conf.d/autologin.conf
[Autologin]
User=itg
Session=itgmania
Relogin=true
EOF

    mkdir -p /usr/local/share/xsessions
    cat << EOF > /usr/local/share/xsessions/itgmania.desktop
[Desktop Entry]
Type=XSession
Exec=/usr/local/games/itgmania/itgmania
# TryExec=/usr/local/games/itgmania/itgmania
DesktopNames=ITGMania
Name=ITGMania (X11)
EOF

}

screen_pacdrive() {
    cat << EOF > /etc/udev/rules.d/75-linux-pacdrive.rules
SUBSYSTEM=="usb", ATTRS{idVendor}=="d209", ATTRS{idProduct}=="150[0-9]", MODE="0666"
EOF
}

screen_network_dhclient() {
    screen_title="ITG Machine - DHCLIENT"

    msgbox "You current network configuration is displayed below.
If you pluged in any wired connection try dhclient to set it up.
If you already have Internet connection, say no.

    $(ip addr)"

    yesnobox "Try dhclient?" && run dhclient
}

screen_first_reboot() {

    msgbox "After initial installation and upgrade new critical packages may be upgraded.

If network manager is installed it is also good time to check weather everything is working.

If you installed UEFI Linux then it is expected to be loaded instead of Grub.

Reboot machine and continue system setup from where you where."

    yesnobox "Reboot?" && run reboot
}

screen_openssh() {
    screen_apt_package openssh-server
}

screen_vsftpd() {
    screen_apt_package vsftpd \
	&& run sed -i 's/#write_enable=YES/write_enable=YES/' /etc/vsftpd.conf \
	&& run systemctl restart vsftpd
}

screen_system_first() {
    screen_title="ITG Machine - System"

    menubox \
	screen_network_dhclient "Ad-hoc connect to the network " \
	screen_apt_repository "Setup Debian Repository" \
        screen_apt_upgrade "Upgrade Debian" \
        screen_network_manager "Setup Network Manager" \
        screen_network_wifi "Setup WiFi Network (optional)" \
	screen_console_tools "Install useful console tools" \
	screen_openssh "Install openssh server (optional)" \
	screen_vsftpd "Install simple FTP server (vsftpd)" \
	screen_uefi "Install kernel to UEFI partition" \
	screen_first_reboot "Reboot after initial setup"
}

screen_system_second() {
    screen_title="ITG Machine - System (Continue)"

    menubox \
	screen_disk "Select disk" \
	screen_partitions "Select partitions" \
	screen_grub "Configure GRUB" \
	screen_efi "Configure EFI"
}

screen_itgmania() {
    screen_title="ITG Machine - ITG Mania"
    menubox \
	"screen_itgmania_install 0.9.0" "Install ITGmania 0.9.0" \
	"screen_itgmania_install 0.8.0" "Install ITGmania 0.8.0" \
	"screen_itgmania_install" "Install ITGmania other version" \
        screen_sound_pipewire "Setup Pipewire" \
	screen_pacdrive "Setup Linux PacDrive (TODO)" \
	screen_sddm "Configure SDDM to run ITGMania" \
	screen_itgmania_usbprofiles "Configure USB Profiles (TODO)" \
	screen_itgmania_configure "Configure ITGmania (TODO)" \
	screen_boogiestats "Configure Boogie Stats (TODO)"
}

screen_main() {
    screen_title="ITG Machine - Main"

    menubox \
	screen_system_first "Setup System (first boot)" \
	screen_system_second "Setup System (second boot)" \
	screen_itgmania "Setup ITG Mania"
}

# TUI is based on whiptail. We must check it manually before anything else
if ! command -v whiptail &> /dev/null; then
    echo "whiptail is not available. Graphic install is not possible!"
    echo "This should not happen because whiptail has important priority"
    echo "and installed automatically with any Debian. Not nice"

    # This is not nice: !69=!(0b1000101)=(0b0111010)=58
    exit 58
fi

ensure_root
screen_main
