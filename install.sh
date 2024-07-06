#!/usr/bin/env bash
# -*- mode: bash-ts -*-

# shellcheck disable=SC2164
# ROOT_DIR=$(cd "$(dirname "$0")"; pwd)

ITGMACHINE_CACHE=/var/cache/itgmachine
# ITGMACHINE_INSTALL=/usr/local/games

msgbox() {
    local message="$1";

    whiptail --title "$screen_title" \
             --msgbox "$message" 8 80

    wt_status=$?
    unset wt_out
}

yesnobox() {
    local message="$1"

    whiptail --title "$screen_title" \
             --yesno "$message" 8 80

    wt_status=$?
    unset wt_out
}

inputbox() {
    local message="$1"
    local default="$2"
    wt_out=$(whiptail --title "$screen_title" \
		      --inputbox "$message" 8 80 \
                      "$default" 3>&1 1>&2 2>&3)
    wt_status=$?
}

passbox() {
    local message="$1"
    local default="$2"
    wt_out=$(whiptail --title "$screen_title" \
		      --passwordbox "$message" 8 80 \
                      "$default" 3>&1 1>&2 2>&3)
    wt_status=$?
}

textbox() {
    local file="$1";

    whiptail --title "$screen_title" \
             --scrolltext \
             --textbox "$file" 25 80

    wt_status=$?
    unset wt_out
}

menubox() {
    local title="$screen_title"
    while :; do
	wt_out=$(whiptail --title "$title" \
			  --ok-button "Select" \
			   --cancel-button "Exit" \
			   --notags \
			   --menu "" \
                           25 80 16 \
                           "$@" 3>&1 1>&2 2>&3)
	wt_status=$?

	if [[ $wt_status -ne 0 ]]; then break; fi
	if [[ "$wt_out" == screen_* ]]; then $wt_out; else break; fi
    done
}

ensure_root() {
    if [[ $UID -ne 0 ]]; then
        msgbox "You must run this program as root"
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

    yesnobox "Command $cmd was not found.\nInstall $package?"
    if [[ $wt_status -eq 0 ]]; then
	ensure_apt_package "$package"
    fi
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
	    whiptail --title "ITG Mania Download" \
		     --ok-button "Back" \
		     --msgbox "Failed to download version: $version from\n$url" 10 80
	    return
	fi

    fi

    mkdir -p "/usr/local/games/$name"
    tar -C "/usr/local/games/$name" -xf "$ITGMACHINE_CACHE/$archive" "$name/itgmania" --strip-components 2
    ln -sfn "/usr/local/games/$name" /usr/local/games/itgmania
}

screen_install_itgmania() {
    local version="0.9.0"

    inputbox "Enter ITGMania version" "$version"
    if [[ $wt_status -ne 0 ]]; then return; fi
    version="$wt_out"

    install_itgmania "$version"

}

screen_apt_repository() {
    local url="https://ftp.debian.org/debian"
    local release="testing"
    local components="main contrib non-free non-free-firmware"

    screen_title="ITG Machine - APT"

    inputbox "Enter Debian repository URL:" "$url"
    if [[ $wt_status -ne 0 ]]; then return; fi
    url="$wt_out"

    inputbox "Enter Debian Release" "$release"
    if [[ $wt_status -ne 0 ]]; then return; fi
    release="$wt_out"

    inputbox "Enter Debian components" "$components"
    if [[ $wt_status -ne 0 ]]; then return; fi
    components="$wt_out"

    yesnobox "Replace source.list with:\ndeb $url $release $components?"
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

    apt dist-upgrade
}


screen_itgmania_install() {
    version="$1"

    if [[ -z "$version" ]]; then
        inputbox "Enter ITGmania version in form: X.Y.Z"
	if [[ $wt_status -ne 0 ]]; then return; fi
        version="$wt_out"
    fi

    install_itgmania "$version"
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
    screen_title="ITG Machine - System"
    menubox screen_apt_repository "Configure Debian Testing repository" \
            screen_apt_upgrade "Perform Debian Upgrade" \
	    screen_uefi_kernel "Install kernel to UEFI partition" \
            screen_install_networkmanager "Install Network Manager" \
            screen_sound_alsa "Setup Alsa (not ready)" \
            screen_sound_pipewire "Setup Pipewire"

}

screen_itgmania() {
    screen_title="ITG Machine - ITG Mania"
    menubox "screen_install_itgmania 0.9.0" "Install ITGmania 0.9.0" \
	    "screen_itgmania_install 0.8.0" "Install ITGmania 0.8.0" \
	    "screen_itgmania_install" "Install ITGmania other version"
}

screen_main() {
    screen_title="ITG Machine"
    ensure_root

    menubox screen_system "Manage System" \
	    screen_disk "Configure disk" \
	    screen_itgmania "ITG Mania" \
	    screen_grub "Configure GRUB" \
	    screen_efi "Configure EFI" \
	    screen_upgrades "Configure unattended upgrades" \
	    screen_boogiestats "Configure Boogie Stats"
}

screen_main
