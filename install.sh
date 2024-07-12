#!/usr/bin/env bash
# -*- mode: bash-ts -*-

# Default screen title can be overwritten in screen menu
screen_title="ITG Machine"

### Whiptail interface
# Each function re-sets wt_status and wt_out
msgbox() {
    local message="$1";
    local height=10
    local lines=0

    lines=$(echo "$message" | wc -l)
    [[ $lines -gt 4 ]] && height=25

    whiptail --title "$screen_title" \
	     --backtitle "Use <up>/<down> to navigate, <enter> to select, <tab> to switch between buttons." \
	     --scrolltext \
             --msgbox "$message" $height 80

    wt_status=$?
    unset wt_out
}

yesnobox() {
    local message="$1"

    whiptail --title "$screen_title" \
	     --backtitle "Use <up>/<down> to navigate, <enter> to select, <tab> to switch between buttons." \
             --yesno "$message" 10 80

    wt_status=$?
    unset wt_out

    return $wt_status
}

inputbox() {
    local message="$1"
    local default="$2"
    wt_out=$(whiptail --title "$screen_title" \
		      --backtitle "Use <up>/<down> to navigate, <enter> to select, <tab> to switch between buttons." \
		      --inputbox "$message" 10 80 \
                      "$default" 3>&1 1>&2 2>&3)
    wt_status=$?
}

passbox() {
    local message="$1"
    local default="$2"
    wt_out=$(whiptail --title "$screen_title" \
		      --backtitle "Use <up>/<down> to navigate, <enter> to select, <tab> to switch between buttons." \
		      --passwordbox "$message" 10 80 \
                      "$default" 3>&1 1>&2 2>&3)
    wt_status=$?
}

textbox() {
    local file="$1";

    whiptail --title "$screen_title" \
	     --backtitle "Use <up>/<down> to navigate, <enter> to select, <tab> to switch between buttons." \
             --scrolltext \
             --textbox "$file" 25 80

    wt_status=$?
    unset wt_out
}

radiobox() {
    local text="Choose item from the list below:"
    if [[ -n "$1" ]]; then text="$1"; fi; shift

    local items=("$@")

    while :; do
	wt_out=$(whiptail --title "$screen_title" \
			  --backtitle "Use <up>/<down> to navigate, <space> to select, <tab> to switch between buttons." \
			  --ok-button "Select" \
			  --cancel-button "Back" \
			  --notags \
			  --radiolist "$text" \
                          25 80 16 \
                          "$@" 3>&1 1>&2 2>&3)
	wt_status=$?

	if [[ $wt_status -ne 0 ]]; then break; fi
	if [[ -n "$wt_out" ]]; then break; fi
	msgbox "Nothing was selected. HINT: Use space to select an item."
    done

    return "$wt_status"
}

menubox() {
    # screen title can be changed in submenu
    # this way we recursively persist it for the selected menu
    local title="$screen_title"
    local selected="none"
    local text="Select an action:"

    if [[ -n "$1" ]]; then text="$1"; fi; shift

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
	wt_status=$?
	selected="$wt_out"

	if [[ $wt_status -ne 0 ]]; then break; fi
	if [[ "$wt_out" == screen_* ]]; then $wt_out; else break; fi
    done
}

# Runs command and delays so you can see result
run() {
    local status
    # Run command
    "$@"
    status=$?

    [[ $status -eq 0 ]] || (echo "Exist status $status. Press enter to continue"; read -r)

    return $status
}


fstab_flash() {
    cat << EOF > /tmp/fstab
/dev/disk/by-path/pci-0000:00:13.2-usb-0:6:1.0-scsi-0:0:0:0-part1       /mnt/P1 auto    rw,noatime,noauto,user  0       0
/dev/disk/by-path/pci-0000:00:13.2-usb-0:6:1.0-scsi-0:0:0:0             /mnt/P1 auto    rw,noatime,noauto,user  0       0

/dev/disk/by-path/pci-0000:00:13.2-usb-0:5:1.0-scsi-0:0:0:0-part1       /mnt/P2 auto    rw,noatime,noauto,user  0       0
/dev/disk/by-path/pci-0000:00:13.2-usb-0:5:1.0-scsi-0:0:0:0             /mnt/P2 auto    rw,noatime,noauto,user  0       0
EOF

}

### Ensure functions
ensure_root() {
    if [[ $UID -ne 0 ]]; then
        msgbox "You must run this program as root"
	exit 1
    fi
}

ensure_apt_update() {
    if [[ -z "$ITGMACHINE_APT_UPDATED" ]]; then
	run apt -o APT::Update::Error-Mode=any update
	ITGMACHINE_APT_UPDATED=true
    fi
}

ensure_apt_package() {
    ensure_apt_update

    apt install "$@"
    apt_status=$?
    [[ $apt_status -eq 0 ]] || (echo "Exist status $apt_status. Press enter to continue"; read -r)
}

ensure_command() {
    cmd="$1"
    package="${2:-$cmd}"

    command -v "$cmd" &> /dev/null && return

    yesnobox "Command $cmd was not found.\nInstall $package?" \
	&& ensure_apt_package "$package"
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
	    return
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

    inputbox "Enter Debian repository URL:" "$url"
    if [[ $wt_status -ne 0 ]]; then return; fi
    url="$wt_out"

    inputbox "Enter Debian Release" "$release"
    if [[ $wt_status -ne 0 ]]; then return; fi
    release="$wt_out"

    inputbox "Enter Debian components" "$components"
    if [[ $wt_status -ne 0 ]]; then return; fi
    components="$wt_out"

    yesnobox "Replace source.list with:\nURL: $url\nRelease: $release\nComponents: $components?"
    if [[ $wt_status -eq 0 ]]; then
	echo "deb $url $release $components" > /etc/apt/sources.list
	screen_apt_update 1
    fi
}

screen_apt_update() {
    force="$1"
    if [[ -n "$force" ]]; then unset ITGMACHINE_APT_UPDATED; fi

    if [[ -z "$ITGMACHINE_APT_UPDATED" ]]; then
	apt update
	ITGMACHINE_APT_UPDATED=true
    fi
}

screen_apt_upgrade() {
    screen_apt_update

    screen_title="ITG Machine - Upgrading"
    run apt dist-upgrade
}


screen_itgmania_install() {
    version="$1"

    if [[ -z "$version" ]]; then
        inputbox "Enter ITGmania version in form: X.Y.Z"
	if [[ $wt_status -ne 0 ]]; then return; fi
        version="$wt_out"
    fi

    install_itgmania "$version"

    ensure_apt_package
    ensure_apt_package libusb-0.1-4 libgl1 libglvnd0 libglu1-mesa libxtst6 libxinerama1 libgdk-pixbuf-2.0-0 libgtk-3-0t64

    # yesnobox "Install libusb library for lights driver support?"
    # if [[ $wt_status -eq 0 ]]; then
    #	ensure_apt_package libusb-0.1-4
    # fi
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

screen_disk_primary() {
    screen_title="ITG Machine - Disk"

    local disks
    local radioitems=()

    disks=$(lsblk -dnpP -o NAME,MODEL)

    while read -r line; do
	eval "$line"
	radioitems+=("$NAME" "$NAME ($MODEL)" off)
    done <<< "$disks"
    unset NAME
    unset MODEL

    radiobox "Select primary drive where system is installed:" "${radioitems[@]}" || return
    primary_disk="$wt_out"
    msgbox "You have selected $primary_disk as primary disk."
}

screen_disk_partitions() {
    local radioitems=()
    local partitions
    local pttype

    if [[ -z "$primary_disk" ]]; then
	msgbox "Primary disk is not selected. It should look like /dev/sda or /dev/nvme0n1."
	return 1
    fi
    pttype=$(lsblk -dn -o PTTYPE "$primary_disk")
    if [[ ! "$pttype" == "gptx" ]]; then
	msgbox "The parition type is not GPT ($pttype). Installer
can't use PARTLABEL to detect and mount root, backup and songs
partitions.

WARNING! You can't use filesystem's LABEL or UUID because
filesystem's metadata will be copied with filesystem backup or
restore procedure.

Installer will offer you to use partition device directly. Sometimes
it is reliable if you insert additional disks."
    fi

    return

    partitions=$(lsblk -npP -o NAME,PARTLABEL,LABEL,TYPE)

    while read -r line; do
	eval "$line"

	radioitems+=("$NAME" "$NAME ($MODEL)" off)
    done <<< "$partitions"
    unset NAME
    unset PARTLABEL
    unset LABEL
    unset TYPE

    radiobox "Select primary drive where system is installed:" "${radioitems[@]}" || return
    primary_disk="$wt_out"
    msgbox "You have selected $primary_disk as primary disk."


    root_dev=$(blkid -t PARTLABEL=root -o device "$primary"*)
    backup_dev=$(blkid -t PARTLABEL=backup -o device "$primary"*)
    songs_dev=$(blkid -t PARTLABEL=songs -o device "$primary"*)

    echo $root_dev
    echo $backup_dev
    echo $songs_dev
    run /bin/false


}

screen_network_manager() {
    screen_title="ITG Machine - Network Manager"
    screen_apt_update

    run apt install network-manager
}

screen_uefi_kernel() {
    if ! mountpoint -q /boot/efi; then
	whiptail --msgbox "It looks like /boot/efi is not mounted." 8 80
	return
    fi

    mkdir -p /boot/efi/EFI/itgmachine
    cp /vmlinuz /boot/efi/EFI/itgmachine/
    cp /initrd.img /boot/efi/EFI/itgmachine/
    # TODO: screen install hook

    # TODO: -d /dev/disk/nvme
    efibootmgr -c -g -L "ITGMachine Normal Run" \
	       -l '\EFI\itgmachine\vmlinuz' \
	       -u 'root=PARTLABEL=root itgmachine.mode=normal rw quiet nmi_watchdog=0 initrd=\EFI\itgmachine\initrd.img'
    # TODO: -d /dev/disk/nvme
    efibootmgr -c -g -L "ITGMachine Backup" \
	       -l '\EFI\itgmachine\vmlinuz' \
	       -u 'root=PARTLABEL=root itgmachine.mode=backup rw quiet nmi_watchdog=0 initrd=\EFI\itgmachine\initrd.img'
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

    menubox "" "${menuitems[@]}"
}

screen_wifi_connect() {
    local ssid="$1"
    ensure_command nmcli network-manager

    passbox "Enter password for $ssid"
    [[ $wt_status -eq 0 ]] || return

    nmcli device wifi connect "$ssid" password "$wt_out"
    nmcli_status=$?
    [[ $nmcli_status -eq 0 ]] || (echo "Exist status $nmcli_status. Press enter to continue"; read -r)
}

screen_sound_pipewire() {
    ensure_apt_package pipewire pipewire-audio wireplumber

    # wpctl get|set-volume ID 0.8
}

screen_sddm() {
    ensure_apt_package --no-install-recommends \
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
    msgbox "After initial installation and upgrade new critical
packages may be upgraded. If network manager is installed it is
also good time to check weather everything is working.
Reboot machine and continue system setup from where you where."

    yesnobox "Reboot?" && run reboot
}

screen_system_first() {
    screen_title="ITG Machine - System"

    menubox "" \
	    screen_network_dhclient "Ad-hoc connect to the network " \
	    screen_apt_repository "Setup Debian Repository" \
            screen_apt_upgrade "Upgrade Debian" \
            screen_network_manager "Setup Network Manager" \
            screen_network_wifi "Setup WiFi Network (optional)" \
	    screen_first_reboot "Reboot after initial setup"
}


screen_system_second() {
    screen_title="ITG Machine - System (Continue)"

    menubox "" \
	    screen_disk_primary "Select primary disk" \
	    screen_disk_partitions "Detect ITG Machine partitions" \
	    screen_pacdrive "Setup Linux PacDrive" \
	    screen_uefi_kernel "Install kernel to UEFI partition" \
            screen_sound_pipewire "Setup Pipewire" \
	    screen_grub "Configure GRUB" \
	    screen_openssh "Install openssh server" \
	    screen_efi "Configure EFI" \
	    screen_sddm "Configure SDDM to run ITGMania"
}

screen_itgmania() {
    screen_title="ITG Machine - ITG Mania"

    menubox "" \
	    "screen_itgmania_install 0.9.0" "Install ITGmania 0.9.0" \
	    "screen_itgmania_install 0.8.0" "Install ITGmania 0.8.0" \
	    "screen_itgmania_install" "Install ITGmania other version" \
	    screen_boogiestats "Configure Boogie Stats"
}

screen_troubleshoot() {
    screen_title="ITG Machine - Troubleshoot"

    menubox "" \
	    screen_check_disk_layout "Check disk layout"
}

screen_main() {
    screen_title="ITG Machine - Main"

    menubox "" \
	    screen_system_first "Setup System (first boot)" \
	    screen_system_second "Setup System (second boot)" \
	    screen_itgmania "Setup ITG Mania" \
	    screen_troubleshoot "Troubleshoot ITG Machine"
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

