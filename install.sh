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

itgmania_user=itg
itgmania_home=/home/itg

### Whiptail interface
# Each function unsets or returns wt_out
msgbox() {
    local message="$1"
    unset wt_out # nothing to out

    whiptail --title "$screen_title" \
	     --backtitle "Use <up>/<down> to navigate, <enter> to select, <tab> to switch between buttons." \
	     --scrolltext \
             --msgbox "$message" 0 0
}

yesnobox() {
    local message="$1"
    unset wt_out # nothing to out

    whiptail --title "$screen_title" \
	     --backtitle "Use <up>/<down> to navigate, <enter> to select, <tab> to switch between buttons." \
             --yesno "$message" 0 0
}

inputbox() {
    local message="$1"
    local default="$2"
    unset wt_out
    wt_out=$(whiptail --title "$screen_title" \
		      --backtitle "Use <up>/<down> to navigate, <enter> to select, <tab> to switch between buttons." \
		      --inputbox "$message" 12 80 \
                      "$default" 3>&1 1>&2 2>&3)
}

passbox() {
    local message="$1"
    local default="$2"
    wt_out=$(whiptail --title "$screen_title" \
		      --backtitle "Use <up>/<down> to navigate, <enter> to select, <tab> to switch between buttons." \
		      --passwordbox "$message" 12 80 \
                      "$default" 3>&1 1>&2 2>&3)
}

textbox() {
    local file="$1";
    unset wt_out # nothing to out

    whiptail --title "$screen_title" \
	     --backtitle "Use <up>/<down> to navigate, <enter> to select, <tab> to switch between buttons." \
             --scrolltext \
             --textbox "$file" 0 0
}

radiobox() {
    local text="Choose item from the list below:"
    local wtst

    if [[ $(($# % 3)) -eq 1 ]]; then text="$1"; shift; fi
    local items=("$@")

    wt_out=$(whiptail --title "$screen_title" \
		      --backtitle "Use <up>/<down> to navigate, <space> to select, <tab> to switch between buttons." \
		      --ok-button "Select" \
		      --cancel-button "Back" \
		      --notags \
		      --radiolist "$text" \
                      0 0 0 \
                      "${items[@]}" 3>&1 1>&2 2>&3)
}

checkbox() {
    local text="Choose items from the list below:"
    local wtst

    if [[ $(($# % 3)) -eq 1 ]]; then text="$1"; shift; fi
    local items=("$@")

    wt_out=$(whiptail --title "$screen_title" \
		      --backtitle "Use <up>/<down> to navigate, <space> to select, <tab> to switch between buttons." \
		      --ok-button "Select" \
		      --cancel-button "Back" \
		      --notags \
		      --separate-output \
		      --checklist "$text" \
                      0 0 0 \
                      "${items[@]}" 3>&1 1>&2 2>&3)
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
                          0 0 0 \
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

screen_ensure_root() {
    if [[ $UID -ne 0 ]]; then
        msgbox "You must run this program as root"
	exit 1
    fi
}

screen_reboot() {
    yesnobox "Reboot ITG Machine?" && run reboot
}

screen_directory_create() {
    if [[ $# -eq 0 ]]; then return 1; fi

    [[ -d "$1" ]] || run mkdir -p "$1"
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

screen_apt_package() {
    screen_title="ITG Machine - Package install"
    screen_apt_update && run apt install "$@"
}

screen_ensure_command() {
    if [[ $# -lt 2 ]]; then
	msgbox "BUG: Too few arguments in ensure command screen: '$*'"
	return 1
    fi

    local cmd="$1"
    local screen="$2"

    if command -v "$cmd" &> /dev/null; then return 0; fi

    yesnobox "Command $cmd was not found. The error will be fixed now. Continue?" && $screen
}

screen_console_tools() {
    screen_title="ITG Machine - Console Tools"

    yesnobox "Install vim mc htop?" \
	     && screen_apt_package vim mc htop
}

screen_network_dhclient() {
    screen_title="ITG Machine - DHCLIENT"

    msgbox "You current network configuration is displayed below.
If you pluged in any wired connection this will try dhclient to set it up.
If you already have Internet connection, say no.

If you did it already as said in the README, also say no.

    $(ip addr)"

    yesnobox "Try dhclient?" && run dhclient
}

screen_network_manager() {
    screen_title="ITG Machine - Network Manager"
    screen_apt_update && run apt install network-manager
}

screen_wifi_connect() {
    local ssid="$1"

    screen_ensure_command nmcli network-manager \
	&& passbox "Enter password for $ssid" \
	&& run nmcli device wifi connect "$ssid" password "$wt_out"
}

screen_wifi() {
    screen_title="ITG Machine - WIFI"
    screen_ensure_command nmcli screen_network_manager

    local menuitems=()
    local wifi_networks

    wifi_networks=$(nmcli -g SSID,RATE,BARS device wifi list)

    while IFS=: read -r ssid rate bars; do
        menuitems+=("screen_wifi_connect $ssid")
        menuitems+=("$ssid ($rate $bars)")
    done <<< "$wifi_networks"

    menubox "${menuitems[@]}"
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

    screen_directory_create "$itgmachine_efi_dir"
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

    screen_directory_create "$(dirname "$hook")" || return 1

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
	yesnobox "UEFI Boot Entry '$bootlabel' is already exist:\n$bootentry\nDelete existing?" \
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

NOTE: If $(readlink -f /initrd.img) file is too big to copy on EFI partition, try to optimize the initramfs size by setting 'MODULES=dep' in '/etc/initramfs-tools/initramfs.conf' and running 'update-initramfs -k all -c -v'.

Continue?" || return 1

    true \
	&& screen_uefi_dir \
	&& screen_kernel_uefi_hook \
	&& screen_initramfs_uefi_hook \
	&& screen_uefi_bootmgr \
	&& msgbox "All checks have passed! You are on UEFI now. If something goes wrong you still have your previous boot options. You can choose different boot options from UEFI Boot Menu."
}

screen_openssh() {
    screen_apt_package openssh-server
}

screen_vsftpd() {
    screen_apt_package vsftpd \
	&& run sed -i 's/#write_enable=YES/write_enable=YES/' /etc/vsftpd.conf \
	&& run systemctl restart vsftpd
}

screen_sound_pipewire() {
    screen_apt_package pipewire pipewire-audio wireplumber
}

screen_crudini() {
    screen_apt_package crudini
}

screen_itgmania_dependencies() {
    screen_apt_package libusb-0.1-4 libgl1 libglvnd0 libglu1-mesa libxtst6 \
		       libxinerama1 libgdk-pixbuf-2.0-0 libgtk-3-0t64
}

screen_itgmania_download() {
    local ghapi="https://api.github.com/repos/itgmania/itgmania/releases?page=1&per_page=5"
    local releases='https://github.com/itgmania/itgmania/releases/download/.*Linux-no-songs.tar.gz'
    local cache=/var/cache/itgmachine
    local menuitems=()
    local archive_url archive_name archive_file archive_dir

    while read -r archive_url; do
	menuitems+=("$archive_url" "$(basename "$archive_url")")
    done < <(wget -qO- "$ghapi" | grep -o "$releases")

    menubox "Select ITGmania version from the list below:" "${menuitems[@]}" || return 1
    archive_url="$wt_out"
    archive_name="$(basename "$archive_url")"
    archive_file="$cache/$archive_name"
    archive_dir="/usr/local/games/$(basename "$archive_name" .tar.gz)"

    screen_directory_create "$cache" || return 1

    [[ -f "$archive_file" ]] || run wget -q --tries 3 --show-progress -O "$archive_file" "$archive_url" \
	|| { msgbox "Failed to download $archive_name from url:\n$url"; return 1; }

    screen_directory_create "$archive_dir" || return 1

    [[ -x "$archive_dir/itgmania" ]] || run tar -C "$archive_dir" -xf "$archive_file" --strip-components 2 \
	|| { msgbox "Can't unpack ITGmania from archive: $archive_file"; return 1; }

    run ln -sfn "$archive_dir" /usr/local/games/itgmania || { msgbox "Can't update symlink"; return 1; }

    msgbox "ITGmania has been cached and installed.
Also symlink /usr/local/games/itgmania has been updated.
Name: $archive_name
DIR: $archive_dir"
}

screen_itgmania_sddm() {
    screen_apt_package --no-install-recommends --no-install-suggests sddm || return 1

    screen_directory_create /etc/sddm.conf.d || return 1
    cat << EOF > /etc/sddm.conf.d/autologin.conf
[Autologin]
User=$itgmania_user
Session=itgmania
Relogin=true
EOF

    screen_directory_create /usr/local/share/xsessions || return 1
    cat << EOF > /usr/local/share/xsessions/itgmania.desktop
[Desktop Entry]
Type=XSession
Exec=/usr/local/games/itgmania/itgmania
DesktopNames=ITGmania
Name=ITGmania (X11)
EOF
}

screen_itgmania_user() {
    local userent
    local _x

    inputbox "By default installer will use user 'itg' and home '/home/itg'. But you can change the user.
Current user: $itgmania_user
Current home: $itgmania_home

Please enter the existing username that will be used to run ITGmania:" "$itgmania_user" || return 1
    if userent=$(getent passwd "$wt_out"); then
	IFS=: read -r itgmania_user _x _x _x _x itgmania_home _x <<< "$userent"
    else
	msgbox "User $wt_out does not exist. Try again"
	return 1
    fi

}

screen_itgmania_prefs() {
    if [[ ! -d "$itgmania_home" ]]; then msgbox "Home directory does not exist. Select an existing user"; return 1; fi

    if [[ ! -d "$itgmania_home/.itgmania/Save" ]]; then
	screen_directory_create "$itgmania_home/.itgmania/Save" \
	    && run chown "$itgmania_user:$itgmania_user" "$itgmania_home/.itgmania" \
	    && run chown "$itgmania_user:$itgmania_user" "$itgmania_home/.itgmania/Save" \
		|| return 1
    fi

    screen_ensure_command crudini screen_crudini || return 1

    local prefs="$itgmania_home/.itgmania/Save/Preferences.ini"
    run crudini --ini-options=nospace --set "$prefs" "$1" "$2" "$3"
}

screen_itgmania_configure() {
    if yesnobox "Set arcade style navigation?"; then
	screen_itgmania_prefs "Options" "ArcadeOptionsNavigation" "1"
    else
	screen_itgmania_prefs "Options" "ArcadeOptionsNavigation" "0"
    fi

    if yesnobox "Never play sounds during the attract mode, which is
the mode where the game displays a demo or other visuals to attract
players when not in use?"; then
	screen_itgmania_prefs "Options" "AttractSoundFrequency" "Never"
    else
	screen_itgmania_prefs "Options" "AttractSoundFrequency" "EveryTime"
    fi

    if yesnobox "Turn off joysticks auto mapping?"; then
	screen_itgmania_prefs "Options" "AutoMapOnJoyChange" "0"
    else
	screen_itgmania_prefs "Options" "AutoMapOnJoyChange" "1"
    fi

    if inputbox "Set uniq machine name" "$(hostname -f)"; then
	screen_itgmania_prefs "Options" "MachineName" "$wt_out"
    else
	screen_itgmania_prefs "Options" "MachineName" ""
    fi

    if yesnobox "Use only dedicated menu buttons for navigation?"; then
	screen_itgmania_prefs "Options" "OnlyDedicatedMenuButtons" "1"
    else
	screen_itgmania_prefs "Options" "OnlyDedicatedMenuButtons" "0"
    fi

    if yesnobox "Turn off Vsync (recommended)?"; then
	screen_itgmania_prefs "Options" "Vsync" "0"
    else
	screen_itgmania_prefs "Options" "Vsync" "1"
    fi

    if yesnobox "Set full screen mode (recommended)?"; then
	screen_itgmania_prefs "Options" "Windowed" "0"
    else
	screen_itgmania_prefs "Options" "Windowed" "1"
    fi
}

screen_simplylove_gsapi() {
    local slgs="/usr/local/games/itgmania/Themes/Simply Love/Scripts/SL-Helpers-GrooveStats.lua"
    sed -i "s|.*local url_prefix = .*|        local url_prefix = \"$1\"|" "$slgs"
}

screen_boogiestats() {
    if yesnobox "Turn on BoogieStats?"; then
	screen_itgmania_prefs "Options" "HttpAllowHosts" "*.groovestats.com,boogiestats.andr.host"
	screen_simplylove_gsapi "https://boogiestats.andr.host/"
    else
	screen_itgmania_prefs "Options" "HttpAllowHosts" "*.groovestats.com"
	screen_simplylove_gsapi "https://api.groovestats.com/"
    fi
}

screen_itgmania_inputdevices() {
    screen_title="ITG Machine - Input Devices"
    local checkitems=()
    local dev

    msgbox "ITG Mania allows to explicitly define which joysticks in which order to load. This is very useful when you have two similar pad joystick which do initialization in different order randomly. Specifying input device by uniq id can freeze the order so keymap configuration is always correct. You can manually specify your devices using comma in Preferences.ini:
InputDeviceOrder=/dev/input/by-id/p1-joystick,/dev/input/by-id/p2-joystick
or
InputDeviceOrder=/dev/input/by-path/u1-joystick,/dev/input/by-path/u2-joystick

Now trying to detect joysticks 'by-id'"

    if [[ ! -d "/dev/input/by-id" ]]; then
	msgbox "Udev hasn't found any input devices by-id. Try to find them and add manually"
	return 1
    fi

    for dev in /dev/input/by-id/*-joystick; do
	[[ -c "$dev" ]] || continue
	[[ "$dev" == *-event-joystick ]] && continue

	checkitems+=("$dev" "$(basename "$dev")" "on")
    done

    checkbox "Select your joysticks used for pads and control if any:" "${checkitems[@]}" || return 1
    if [[ -n "$wt_out" ]]; then
	screen_itgmania_prefs "Options" "InputDeviceOrder" "$(echo -n "$wt_out" | tr '\n' ',')"
    else
	screen_itgmania_prefs "Options" "InputDeviceOrder" ""
    fi
}

screen_udev_ghettio() {
    yesnobox "GHETT-io joystick (v3) resets in a loop until a read attempt. This fix will add udev rule to automatically read joystick device using dd endlessly immediately after joystick is connected. Expected joystick has vendor id 16d0 and product id 0d02. You can run lsusb to see vendor and product ids.

Add ghettio udev rule?" \
	&& cat << EOF > /etc/udev/rules.d/80-ghettio-joystick.rules \
	&& run udevadm control --reload-rules
# Workaround for ghettio: read joystick immediately so it stop resets in a loop:
KERNEL=="js*", ATTRS{idVendor}=="16d0", ATTRS{idProduct}=="0d02", ACTION=="add", RUN+="/usr/bin/systemd-run dd if=/dev/input/%k of=/dev/null"
EOF
}

screen_pacdrive() {
    screen_itgmania_user || return 1

    [[ "$(getent group input)" == *"$itgmania_user"* ]] \
	|| run adduser "$itgmania_user" input \
	|| return 1

    screen_itgmania_prefs "Options" "LightsDriver" "LinuxPacDrive"
}

# # For usb profiles required
# screen_fstab_validate() {
#     local out

#     if ! out=$(findmnt --verify); then
#	msgbox "/etc/fstab validation failed:\n$out"
#	return 1
#     fi
# }

# screen_fstab() {
#     screen_title="ITG Machine - FSTab"

#     local updates
#     local fstabroot
#     local fstabsongs

#     #screen_partition_validate "$root_partition" || return 1
#     #screen_partition_validate "$songs_partition" || return 1

#     if [[ "$root_partition" != "SKIP" ]]; then
#	if fstabroot=$(findmnt -n --fstab -o SOURCE --target /); then
#	    updates="$updates s|$fstabroot|$root_partition|;"
#	else
#	    msgbox "Installer couldn't detect root in fstab. Running validation.."
#	    screen_fstab_validate
#	fi
#     fi

#     if [[ "$songs_partition" != "SKIP" ]]; then
#	if fstabsongs=$(findmnt -n --fstab -o SOURCE --target /home/itg/.itgmania/Songs); then
#	    updates="$updates s|$fstabsongs|$songs_partition|;"
#	else
#	    echo "$songs_partition	/home/itg/.itgmania/Songs	ext4	discard,noatime,nodiratime,errors=remount-ro	0	0" >> /etc/fstab
#	    screen_fstab_validate
#	fi
#     fi

#     sed -i.bak "$updates" /etc/fstab
# }

# fstab_flash() {
#     # todo: songs nofail, usb nofail
#     cat << EOF > /tmp/fstab
# /dev/disk/by-path/pci-0000:00:13.2-usb-0:6:1.0-scsi-0:0:0:0-part1       /mnt/P1 auto    rw,noatime,noauto,user  0       0
# /dev/disk/by-path/pci-0000:00:13.2-usb-0:6:1.0-scsi-0:0:0:0             /mnt/P1 auto    rw,noatime,noauto,user  0       0

# /dev/disk/by-path/pci-0000:00:13.2-usb-0:5:1.0-scsi-0:0:0:0-part1       /mnt/P2 auto    rw,noatime,noauto,user  0       0
# /dev/disk/by-path/pci-0000:00:13.2-usb-0:5:1.0-scsi-0:0:0:0             /mnt/P2 auto    rw,noatime,noauto,user  0       0
# EOF

# }

# screen_pacdrive() {
#     cat << EOF > /etc/udev/rules.d/75-linux-pacdrive.rules
# SUBSYSTEM=="usb", ATTRS{idVendor}=="d209", ATTRS{idProduct}=="150[0-9]", MODE="0666"
# EOF
# }

screen_system() {
    screen_title="ITG Machine - System"

    menubox \
	screen_network_dhclient "Ad-hoc connect to the network " \
	screen_apt_repository "Setup Debian Repository" \
        screen_apt_upgrade "Upgrade Debian" \
        screen_network_manager "Install Network Manager" \
        screen_wifi "Setup WiFi Network (optional)" \
	screen_console_tools "Install useful console tools" \
	screen_openssh "Install openssh server (optional)" \
	screen_vsftpd "Install simple FTP server (vsftpd)" \
	screen_uefi "Install kernel to UEFI partition" \
        screen_sound_pipewire "Install Pipewire audio system" \
	screen_video_intel "Install Intel video drivers (not implemented)" \
	screen_video_nvidia "Install NVidia video drivers (not implemented)" \
	screen_video_amd "Install AMD video drivers (not implemented)" \
	screen_reboot "Reboot after initial setup and upgrade"
}

screen_itgmania() {
    screen_title="ITG Machine - ITG Mania"
    menubox \
	screen_itgmania_user "Select ITGmania user" \
	screen_itgmania_dependencies "Install ITGmania runtime dependencies" \
	screen_itgmania_download "Download ITGmania for Linux" \
	screen_itgmania_sddm "Configure SDDM to run ITGMania" \
	screen_itgmania_configure "Configure ITGmania" \
	screen_itgmania_inputdevices "Configure input device order" \
	screen_boogiestats "Configure BoogieStats" \
	screen_reboot "Reboot to your new ITG Machine!"
}

screen_tweaks() {
    screen_title="ITG Machine - Tweaks"
    menubox \
	screen_udev_ghettio "Fix ghettio endless reset under Linux" \
	screen_pacdrive "Configure Linux PacDrive" \
	screen_itgmania_usbprofiles "Configure USB Profiles (TODO)"
}

screen_main() {
    screen_title="ITG Machine - Main"

    menubox \
	screen_system "Setup System" \
	screen_itgmania "Setup ITG Mania" \
	screen_tweaks "Apply miscellaneous tweaks"
}

# TUI is based on whiptail. We must check it manually before anything else
if ! command -v whiptail &> /dev/null; then
    echo "whiptail is not available. Graphic install is not possible!"
    echo "This should not happen because whiptail has important priority"
    echo "and installed automatically with any Debian. Not nice"

    # This is not nice: !69=!(0b1000101)=(0b0111010)=58
    exit 58
fi

screen_ensure_root
screen_main
