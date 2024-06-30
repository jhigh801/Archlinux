#!/bin/env bash

# Making Filesystems
mkfs.fat -F32 /dev/sda1 &
mkswap /dev/sda2 &
swapon /dev/sda2 &
mkfs.btrfs /dev/sda3 &

# Mounting Partitions
mount /dev/sda3 /mnt &
btrfs subvolume create @ &
btrfs subvolume create @home &
btrfs su cr @log &
mount -o noatime,compress=lzo,space_cache=v2,subvolume=@ /dev/sda3 /mnt &
mkdir -p /mnt/{boot,home,log} &
mount -o noatime,compress=lzo,space_cache=v2,subvolume=@home /dev/sda3 /mnt/home &
mount -o noatime,compress=lzo,space_cache=v2,subvolume=@log /dev/sda3 /mnt/var/log &
mount /dev/sda1 /mnt/boot &

# timedatectl
timedatectl set-ntp true &
timedatectl set-timezone US/Eastern &
timedatectl status &

# Keyring
pacman-keys --init &
pacman-keys --populate &

# Reflector
sudo reflector -f 30 -l 30 --number 10 --verbose --save /etc/pacman.d/mirrorlist &

# Pacstrap
pacstrap /mnt base linux linux-firmware vim intel-ucode &

# genfstab
genfstab -U /mnt >> /mnt/etc/fstab &

# change root
arch-chroot /mnt &

# localtime
ln -sf /usr/share/zoneinfo/America/Fort_Wayne  /etc/localtime &

# Hwclock
hwclock --systohc &

# Locale
vim ~/etc/locale.gen &
locale-gen &
export LANG=en_US.UTF-8 &
echo "LANG=en_US.UTF-8" >> /etc/locale.conf &

# Hostname
echo "Arch-BTRFS" >> /etc/hostname &

# Host
echo "127.0.0.1   localhost"  >> /etc/host &
echo "::1    localhost"  >>  /etc/host &
echo "127.0.1.1	  Arch-BTRFS.localdomain	Arch-BTRFS"  >> /etc/host &

# Adding Packages
pacman -Syy &
pacman -S grub efibootmgr efivar networkmanager network-manager-applet nm-connection-editor dhcpcd iwd iw bluez bluez-libs wpa_supplicant mtools dosfstools git rsync reflector hplip xdg-user-dirs xdg-utils alsa-utils base-devel inetutils linux-headers pulseaudio-bluetooth pulseaudio pavucontrol &

# Admin PASSWD
passwd root &

# USER add
useradd -mG wheel jon &

# USER Passwd
passwd jon &

# Sudoers List
EDITOR=vim visudo &

# Mkinitcpio
vim /etc/mkinitcpio.conf &

# Grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck /dev/sda &
grub-mkconfig -o /boot/grub/grub.cfg &

# Enabling Services
systemctl enable NetworkManager.service &
systemctl enable bluetooth.service &
systemctl enable dhcpcd.service &

echo "The Script is Complete!"
