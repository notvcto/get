#!/bin/bash
set -e

echo "[*] Ensuring Git is installed..."
sudo pacman -Syu --needed git

echo "[*] Cloning Dusky bare repository..."
# Using the Hide user home directory
git clone --bare --depth 1 https://github.com/dusklinux/dusky.git $HOME/dusky

echo "[*] Deploying dotfiles to $HOME..."
git --git-dir=$HOME/dusky/ --work-tree=$HOME checkout -f

echo "[*] Dotfiles staged. Launching the Orchestra..."
echo "[!] Stay nearby! This will take 30-60 minutes and ask for your password."

# Giving the script execution permissions just in case
chmod +x $HOME/user_scripts/arch_setup_scripts/ORCHESTRA.sh

# Start the install
$HOME/user_scripts/arch_setup_scripts/ORCHESTRA.sh
