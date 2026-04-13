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

echo "[+] Disk staging complete! Launching archinstall..."
archinstall
