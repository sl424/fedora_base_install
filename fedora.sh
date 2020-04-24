#!/usr/bin/env bash
set -e

TIMEZONE="/usr/share/zoneinfo/America/Los_Angeles"
HOSTNAME="fedoralinux"
USER_NAME="sl424"

#EFI_PART="/dev/sda1"
#ROOT_PART="/dev/sda5"
#ROOT_UUID=$(lsblk $ROOT_PART -o UUID | tail -n 1)

ROOT_PARTLABEL="FEDORA"
ESP_DIRECTORY="/boot/efi"


pkgs="iwl7260-firmware NetworkManager-wifi  
sway swaylock swayidle waybar mesa-dri-drivers wl-clipboard  
brightlight alsa-utils 
git vim  
xorg-x11-server-utils 
unzip wget 
terminus-fonts 
"
#intel-media-driver libva-utils 

function cpdotfile(){
	giturl="https://github.com/sl424/dotfile.git"
	homedir=/home/$USER_NAME
        bash -c "su $USER_NAME -c \" git clone --separate-git-dir=$homedir/.dotfiles $giturl $homedir/tmp \" "
        bash -c "su $USER_NAME -c \" cd $homedir/tmp; for file in .*; do if [ -f $file ]; then cp -r $file $homedir; fi; done \" "
        bash -c "su $USER_NAME -c \" konfig checkout t450s \" "
}

lowbat_dir="/etc/udev/rules.d/99-lowbat.rules"
lowbat="# Suspend the system when battery level drops to 9% or lower \n \
SUBSYSTEM==\"power_supply\", ATTR{status}==\"Discharging\", ATTR{capacity}==\"[0-9]\", RUN+=\"/usr/bin/systemctl suspend\"   \n \
SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="auto" \n\
SUBSYSTEM=="pci", ATTR{power/control}="auto" \n\
## Remove NVIDIA devices, if present \n\
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{remove}="1" \n\
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{remove}="1" \n\
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{remove}="1" \n\
"

thinkpad_dir="/etc/modprobe.d/thinkpad.conf"
thinkpad="# change the default sound card of the same name                           \n\
# options snd_hda_intel power_save=1                                                \n\
# options snd_hda_intel index=1,0                                                   \n\
# enable thinkpad_acpi fan                                                        \n\
# options thinkpad_acpi fan_control=1                                               \n\
# options i915 enable_psr=1                                                         \n\
# options i915 modeset=1                                                            \n\
# options i915 fastboot=1                                                            \n\
# options mds=full,nosmt \n\
# options psmouse synaptics_intertouch=1 \n\
"

lid_dir="/etc/systemd/logind.conf"
lid="HandleLidSwitch=ignore"

function hwmod(){
# 1.2 hardware tweaks
##################################################
	echo -e $lowbat >> $lowbat_dir
	echo -e $thinkpad >> $thinkpad_dir
	echo -e $lid >> $lid_dir
}


function systemd() {
    bootctl --path="$ESP_DIRECTORY" install

    mkdir -p "$ESP_DIRECTORY/F/"
    mkdir -p "$ESP_DIRECTORY/loader/"
    mkdir -p "$ESP_DIRECTORY/loader/entries/"

    loaderconf="# systemd-boot config \n\
    timeout 5 \n\
    default fedora \n\
    editor 0 \n\
    console-mode max"
    echo -e $loaderconf >  "$ESP_DIRECTORY/loader/loader.conf"


    echo "title Fedora Linux" >> "$ESP_DIRECTORY/loader/entries/fedora.conf"

	vm=$(cd /boot; ls vmlinuz-*86*)
	cp /boot/$vm $ESP_DIRECTORY/F/vmlinuz
    echo "efi /F/vmlinuz" >> "$ESP_DIRECTORY/loader/entries/fedora.conf"

	initram=$(cd /boot; ls initramfs-*86*)
	cp /boot/$initram $ESP_DIRECTORY/F/initramfs.img
    echo "initrd /F/initramfs.img" >> "$ESP_DIRECTORY/loader/entries/fedora.conf"

    echo "options root=PARTLABEL=$ROOT_PARTLABEL rw" >> "$ESP_DIRECTORY/loader/entries/fedora.conf"
    echo "options rhgb quiet" >> "$ESP_DIRECTORY/loader/entries/fedora.conf"
}

function packages() {
    if [ -n "$pkgs" ]; then
        dnf_install "$pkgs"
    fi
}

function add_repo(){
	dnf install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
}

function dnf_install() {
    PACKAGES=$1
    for TRY in {1..5}
    do
        dnf --assumeyes install $PACKAGES
        if [ $? == 0 ]; then
            break
        else
            sleep 10
        fi
    done
}

function chroot(){
 mount $ROOT_PART /mnt
 mount $EFI_PART /mnt/boot/efi
 cd /mnt
 mount -t proc /proc proc/
 mount --rbind /sys sys/
 mount --rbind /dev dev/
 mount --rbind /run run/
 cp /etc/resolv.conf etc/resolv.conf
 chroot /mnt 
}

function configure() {
    #timedatectl set-ntp true
    ln -s -f $TIMEZONE /etc/localtime
	echo $HOSTNAME > /etc/hostname
}

function add_fonts(){
	pkgver=2.1.0
	pkgdir=""
	source="https://github.com/ryanoasis/nerd-fonts/releases/download/v$pkgver/Inconsolata.zip"
	wget $source 
	unzip Inconsolata.zip -d tmp; cd tmp
	find . -iname "*.otf" -not -iname "*Windows Compatible.otf" -execdir install -Dm644 {} "$pkgdir/usr/share/fonts/OTF/{}"
}

function main() {
    chroot
    add_repo
    packages
    hwmod
    configure
    cpdotfile
}

#main
if [ ! -z $1 ]; then
	$1
else
	echo " fedora.sh [ chroot | add_repo | packages | hwmod | configure | cpdotfile | systemd ]"
fi
