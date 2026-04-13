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
mkfs.fat -F32 /dev/nvme0n1p1
mkfs.btrfs -f /dev/nvme0n1p2

echo "[*] Creating BTRFS subvolumes..."
mount /dev/nvme0n1p2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
umount /mnt

echo "[*] Mounting subvolumes..."
mount -o compress=zstd,subvol=@ /dev/nvme0n1p2 /mnt
mkdir -p /mnt/{home,var/log,var/cache/pacman/pkg,boot}
mount -o compress=zstd,subvol=@home /dev/nvme0n1p2 /mnt/home
mount -o compress=zstd,subvol=@log /dev/nvme0n1p2 /mnt/var/log
mount -o compress=zstd,subvol=@pkg /dev/nvme0n1p2 /mnt/var/cache/pacman/pkg
mount /dev/nvme0n1p1 /mnt/boot

echo "[*] Downloading base system & GRUB (pacstrap)..."
pacstrap -K /mnt base linux linux-firmware intel-ucode btrfs-progs networkmanager nano sudo git base-devel hyprland kitty polkit mesa vulkan-intel intel-media-driver grub efibootmgr

echo "[*] Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo "[*] Chrooting to configure the system..."
arch-chroot /mnt /bin/bash <<EOF
set -e

# 1. Timezone & Locale
ln -sf /usr/share/zoneinfo/America/Santo_Domingo /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# 2. Hostname
echo "hide-laptop" > /etc/hostname

# 3. NetworkManager
systemctl enable NetworkManager

# 4. Users and Passwords
echo "root:kalaof34" | chpasswd
useradd -m -G wheel -s /bin/bash Hide
echo "Hide:kalaof34" | chpasswd

# Granting wheel group sudo access
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# 5. GRUB Bootloader Setup
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

EOF

echo "[+] Installation V3 complete! GRUB is staged."
echo "[+] Type 'umount -R /mnt', and 'reboot'."
