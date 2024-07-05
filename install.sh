#!/usr/bin/env bash
# -*- mode: bash-ts -*-

# shellcheck disable=SC2164
ROOT_DIR=$(cd "$(dirname "$0")"; pwd)

ITGMACHINE_CACHE=/var/cache/itgmachine
ITGMACHINE_INSTALL=/usr/local/games
# ITGMANIA_INSTALL_PATH=/usr/local/games
# TODO: load /etc/default/itgmachine config

title="ITG Machine"

mgsbox() {
    whiptail --title "I've got no roots" \
	     --ok-button "no root" \
	     --msgbox "You must run this program under root" 8 80

}


ensure_root() {
    if [[ $UID -ne 0 ]]; then
	whiptail --title "I've got no roots" \
		 --ok-button "no root" \
		 --msgbox "You must run this program under root" 8 80
	exit 1
    fi
}

ensure_apt_update() {
    if [[ -z "$ITGMACHINE_APT_UPDATED" ]]; then
	apt update
	ITGMACHINE_APT_UPDATED=true
    fi
}

ensure_apt_package() {
    ensure_apt_update

    apt install -y "$1"
}

ensure_command() {
    cmd="$1"
    package="${2:-$cmd}"

    command -v "$cmd" &> /dev/null && return

    if whiptail --title "$package" \
		--yes-button "Install" \
		--yesno "Command $cmd was not found.\nInstall $package?" 10 80; then
	ensure_apt_package "$package"
    fi
}

ensure_itgmachine_cache() {
    mkdir -p $ITGMACHINE_CACHE
}

install_itgmania() {
    archive="ITGmania-$1-Linux-no-songs.tar.gz"
    name=$(basename $archive .tar.gz)
    url="https://github.com/itgmania/itgmania/releases/download/v$1/ITGmania-$1-Linux-no-songs.tar.gz"

    ensure_itgmachine_cache
    ensure_command curl

    if [[ ! -f "$ITGMACHINE_CACHE/$archive" ]]; then

	if ! curl -fL --progress-bar -o "$ITGMACHINE_CACHE/$archive" "$url"; then
	    whiptail --title "ITG Mania Download" \
		     --ok-button "Back" \
		     --msgbox "Failed to download version: $version from\n$url" 10 80
	    return
	fi

    fi

    mkdir -p /usr/local/games/$name
    tar -C /usr/local/games/$name -xf "$ITGMACHINE_CACHE/$archive" $name/itgmania --strip-components 2
    ln -sfn /usr/local/games/$name /usr/local/games/itgmania
}

screen_apt_set_mirror() {
    url="https://ftp.debian.org/debian"
    dist="testing"
    components="main contrib non-free non-free-firmware"

    _answer=$(whiptail --title "ITG Machine - APT" \
		       --inputbox "Enter Debian repository url" 8 80 "$url" \
		       3>&1 1>&2 2>&3)
    _status=$?
    if [[ $_status -ne 0 ]]; then return; fi
    url="$_answer"

    _answer=$(whiptail --title "ITG Machine - APT" \
		       --inputbox "Enter Debian distrib" 8 80 "$dist" \
		       3>&1 1>&2 2>&3)
    _status=$?
    if [[ $_status -ne 0 ]]; then return; fi
    dist="$_answer"

    _answer=$(whiptail --title "ITG Machine - APT" \
		       --inputbox "Enter Debian components" 8 80 "$components" \
		       3>&1 1>&2 2>&3)
    _status=$?
    if [[ $_status -ne 0 ]]; then return; fi
    components="$_answer"

    if whiptail --title "ITG Machine - APT Mirror" \
		--yes-button "Replace!" \
		--yesno "Reaplce source.list with:\ndeb $url $dist $components?" 12 80; then
	echo 'deb https://ftp.debian.org/debian testing main contrib non-free non-free-firmware' > /etc/apt/sources.list
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

    apt dist-upgrade
}

screen_apt() {
    while :; do
	_choice=$(whiptail --title "ITG Machine - APT" \
			   --ok-button "Select" \
			   --cancel-button "Back" \
			   --notags \
			   --clear \
			   --menu "" 25 80 17 \
			   screen_apt_set_mirror "Set debian mirror to Debian Testing" \
			   screen_apt_update "Perform apt update" \
			   screen_apt_upgrade "Perform dist upgrade" \
			   3>&1 1>&2 2>&3)
	_status=$?
	if [[ $_status -ne 0 ]]; then break; fi
	if [[ "$_choice" == screen_* ]]; then $_choice; else break; fi
    done
}

screen_readme() {
    whiptail --title "README" \
	     --ok-button "Back" \
	     --scrolltext \
	     --textbox "$ROOT_DIR/README.md" 25 80
}

screen_itgmania_install() {
    version="$1"

    if [[ -z "$version" ]]; then
	version=$(whiptail --title "ITG Mania Install" \
			   --inputbox "Enter ITGmania version in form: X.Y.Z" 8 80 \
			   3>&1 1>&2 2>&3)
	_status=$?
	if [[ $_status -ne 0 ]]; then return; fi
    fi
    install_itgmania $version
}

screen_itgmania() {
    while :; do
	_choice=$(whiptail --title "ITG Machine - ITG Mania" \
			   --ok-button "Select" \
			   --cancel-button "Exit" \
			   --notags \
			   --menu "" 25 80 17 \
			   "screen_itgmania_install 0.9.0" "Install ITGmania 0.9.0" \
			   "screen_itgmania_install 0.8.0" "Install ITGmania 0.8.0" \
			   "screen_itgmania_install" "Install ITGmania other version" \
			   3>&1 1>&2 2>&3)
	_status=$?
	if [[ $_status -ne 0 ]]; then break; fi
	if [[ "$_choice" == screen_* ]]; then $_choice; else break; fi
    done
}

screen_mount_songs() {
    user=itg
    mkdir -p /home/itg/.itgmania/Songs
    chown itg:itg /home/itg/.itgmania
    chown itg:itg /home/itg/.itgmania/Songs

    if ! mountpoint -q /home/itg/.itgmania/Songs; then
	mount -o discard,noatime,nodiratime,errors=remount-ro PARTLABEL=songs /home/itg/.itgmania/Songs
    fi

    grep /home/itg/.itgmania/Songs /etc/fstab ||
	echo "PARTLABEL=songs	/home/itg/.itgmania/Songs	ext4	discard,noatime,nodiratime,errors=remount-ro	0	0" >> /etc/fstab

    # This changes permissions inside mounted partition
    chown itg:itg /home/itg/.itgmania/Songs/.
}

screen_disk() {
    whiptail --title "ITG Machine - WARN" \
	     --ok-button "Continue" \
	     --msgbox "Consult with README before proceed" 8 80

    while :; do
	_choice=$(whiptail --title "ITG Machine - Disk" \
			   --ok-button "Select" \
			   --cancel-button "Exit" \
			   --notags \
			   --menu "" 25 80 17 \
			   "screen_mount_songs" "Make Songs mount point" \
			   3>&1 1>&2 2>&3)
	_status=$?
	if [[ $_status -ne 0 ]]; then break; fi
	if [[ "$_choice" == screen_* ]]; then $_choice; else break; fi
    done
}

screen_networkmanager() {
    screen_apt_update

    apt install network-manager
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

screen_system() {
    while :; do
	# TODO:
	_choice=$(whiptail --title "ITG Machine - System" \
			   --ok-button "Select" \
			   --cancel-button "Exit" \
			   --notags \
			   --clear \
			   --menu "" 25 80 17 \
			   screen_networkmanager "Install Network Manager" \
			   screen_uefi_kernel "Install kernel to UEFI partition" \
			   3>&1 1>&2 2>&3)
	_status=$?
	if [[ $_status -ne 0 ]]; then break; fi
	if [[ "$_choice" == screen_* ]]; then $_choice; else break; fi
    done
}

screen_main() {
    while :; do
	_choice=$(whiptail --title "ITG Machine" \
			   --ok-button "Select" \
			   --cancel-button "Exit" \
			   --notags \
			   --clear \
			   --menu "" 25 80 17 \
			   screen_apt "Configure APT" \
			   screen_system "Configure System" \
			   screen_disk "Configure disk" \
			   screen_itgmania "ITG Mania" \
			   screen_grub "Configure GRUB" \
			   screen_efi "Configure EFI" \
			   screen_upgrades "Configure unattended upgrades" \
			   screen_boogiestats "Configure Boogie Stats" \
			   3>&1 1>&2 2>&3)
	_status=$?
	if [[ $_status -ne 0 ]]; then break; fi
	if [[ "$_choice" == screen_* ]]; then $_choice; else break; fi
    done
}

ensure_root
screen_main
