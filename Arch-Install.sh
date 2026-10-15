#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# CONFIGURATION (HDD Optimized, No Encryption)
# ==========================================
DISK="/dev/sda"               # Target HDD (e.g., /dev/sda)
HOSTNAME="archlinux"
USERNAME="user"
PASSWORD="password"           # Change this to your secure password
TIMEZONE="America/New_York"
LOCALE="en_US.UTF-8"
# ==========================================

echo "===> Starting Arch Linux Btrfs Installation (No Encryption)..."

# 1. Verify UEFI mode
if [ ! -d /sys/firmware/efi/efivars ]; then
    echo "Error: System is not booted in UEFI mode." >&2
    exit 1
fi

# 2. Partitioning
echo "===> Partitioning $DISK..."
wipefs -a "$DISK"
sgdisk -Z "$DISK"

# Create EFI partition (1G) and Root partition (Rest)
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$DISK"
sgdisk -n 2:0:0 -t 2:8300 -c 2:"ROOT" "$DISK"

PART_EFI="${DISK}1"
PART_ROOT="${DISK}2"

# 3. Format Partitions & Create Btrfs Subvolumes
echo "===> Formatting partitions..."
mkfs.fat -F32 "$PART_EFI"
mkfs.btrfs -L archroot -f "$PART_ROOT"

echo "===> Creating Btrfs subvolumes..."
mount "$PART_ROOT" /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@snapshots

umount /mnt

# 4. Mount Subvolumes
echo "===> Mounting subvolumes for installation..."
mount -o noatime,compress=zstd:1,subvol=@ "$PART_ROOT" /mnt

mkdir -p /mnt/{boot,home,var/log,var/cache/pacman/pkg,.snapshots}

mount -o noatime,compress=zstd:1,subvol=@home "$PART_ROOT" /mnt/home
mount -o noatime,compress=zstd:1,subvol=@log "$PART_ROOT" /mnt/var/log
mount -o noatime,compress=zstd:1,subvol=@pkg "$PART_ROOT" /mnt/var/cache/pacman/pkg
mount -o noatime,compress=zstd:1,subvol=@snapshots "$PART_ROOT" /mnt/.snapshots

# Mount EFI partition
mount "$PART_EFI" /mnt/boot

# 5. Base System Installation
echo "===> Installing base system and essential packages..."
pacstrap /mnt base base-devel linux linux-firmware btrfs-progs grub efibootmgr networkmanager sudo vim git

# 6. Generate Fstab
echo "===> Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# 7. Configure System via Chroot
echo "===> Configuring system inside chroot..."
arch-chroot /mnt /bin/bash <<EOF
# Timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Localization
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# Hostname & Network
echo "$HOSTNAME" > /etc/hostname
systemctl enable NetworkManager

# Root Password
echo "root:$PASSWORD" | chpasswd

# User Setup
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Configure Mkinitcpio (Standard hooks without encrypt)
sed -i 's/^HOOKS=(.*)/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Install and Configure GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF

echo "===> Installation complete! You can now reboot into your new Arch system."