#!/bin/bash
# Exit immediately if a command exits with a non-zero status
set -e

echo "[*] Wiping /dev/nvme0n1..."
sgdisk --zap-all /dev/nvme0n1

echo "[*] Creating partitions..."
sgdisk -n 1:0:+1G -t 1:ef00 /dev/nvme0n1
sgdisk -n 2:0:0 -t 2:8300 /dev/nvme0n1
partprobe /dev/nvme0n1

echo "[*] Formatting partitions..."
mkfs.fat -F3 /dev/nvme0n1p1
mkfs.btrfs -f /dev/nvme0n1p2

echo "[*] Creating BTRFS subvolumes..."
mount /dev/nvme0n1p2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
umount /mnt

echo "[*] Mounting root subvolume with zstd compression..."
mount -o compress=zstd,subvol=@ /dev/nvme0n1p2 /mnt

echo "[*] Creating mount points..."
mkdir -p /mnt/{home,var/log,var/cache/pacman/pkg,boot}

echo "[*] Mounting remaining subvolumes and boot..."
mount -o compress=zstd,subvol=@home /dev/nvme0n1p2 /mnt/home
mount -o compress=zstd,subvol=@log /dev/nvme0n1p2 /mnt/var/log
mount -o compress=zstd,subvol=@pkg /dev/nvme0n1p2 /mnt/var/cache/pacman/pkg
mount /dev/nvme0n1p1 /mnt/boot

echo "[*] Downloading and installing base system (pacstrap)..."
pacstrap -K /mnt base linux linux-firmware intel-ucode btrfs-progs networkmanager nano sudo git base-devel hyprland kitty polkit mesa vulkan-intel intel-media-driver

echo "[*] Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo "[*] Chrooting to configure the system..."
arch-chroot /mnt /bin/bash <<EOF
set -e

# 1. Locale & Hostname
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "arch-laptop" > /etc/hostname

# 2. NetworkManager
systemctl enable NetworkManager

# 3. Users and Passwords
# Setting root password to match just in case
echo "root:kalaof34" | chpasswd

# Creating the user 'Hide'
useradd -m -G wheel -s /bin/bash Hide
echo "Hide:kalaof34" | chpasswd

# Granting wheel group sudo access without a password prompt for the install phase
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# 4. Bootloader Setup
bootctl install

# Creating systemd-boot entry
cat <<BOOT > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=/dev/nvme0n1p2 rw rootfstype=btrfs
BOOT

# Setting systemd-boot defaults
cat <<LOADER > /boot/loader/loader.conf
default arch.conf
timeout 3
console-mode max
editor no
LOADER

EOF

echo "[+] Installation complete! System is fully staged."
echo "[+] Type 'umount -R /mnt' and then 'reboot'."
