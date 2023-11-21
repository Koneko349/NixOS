#!/bin/bash

# Ensure running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# 1. Scan for disks
disks=($(lsblk -dpno NAME,TYPE | grep 'disk' | awk '{print $1}'))

# Present the available disks
echo "Available disks:"
for i in "${!disks[@]}"; do
    echo "$i: ${disks[i]}"
done

# 2. Prompt for disk selection
read -p "Enter the disk number you want to install NIXOS on: " disknum

if [[ ! "${disknum}" =~ ^[0-9]+$ ]] || [[ "${disknum}" -lt 0 ]] || [[ "${disknum}" -ge "${#disks[@]}" ]]; then
    echo "Invalid selection."
    exit 1
fi

selected_disk="${disks[disknum]}"

# Check if it's an NVMe drive to adjust partition naming
if [[ $selected_disk =~ nvme ]]; then
    partition_suffix="p"
else
    partition_suffix=""
fi

# 3. Partition and format the selected disk
echo "Partitioning $selected_disk..."
sgdisk --zap-all "${selected_disk}"
sgdisk --new=1:0:+1G --typecode=1:ef00 --change-name=1:"boot" "${selected_disk}"
sgdisk --new=2 --typecode=2:8300 --change-name=2:"nixos" "${selected_disk}"

# Format the boot partition
mkfs.vfat -n "boot" "${selected_disk}${partition_suffix}1"

# Set up the LUKS encrypted partition
echo "Please provide a password for the encrypted partition:"
cryptsetup luksFormat --type luks2 "${selected_disk}${partition_suffix}2"
cryptsetup open "${selected_disk}${partition_suffix}2" nixosEncrypted

# Format LUKS partition with btrfs
mkfs.btrfs /dev/mapper/nixosEncrypted
mount -t btrfs /dev/mapper/nixosEncrypted /mnt
btrfs subvolume create /mnt/root
#btrfs subvolume create /mnt/home
#btrfs subvolume create /mnt/nixos-config
#btrfs subvolume create /mnt/logs
umount /mnt

# Mount tmpfs at /mnt
mount -t tmpfs -o size=4G,mode=755 tmpfs /mnt

# Create required directories in tmpfs
mkdir -p /mnt/{boot,home,nix,etc/nixos,var/log}

# Mount the boot partition at /mnt/boot
mount "${selected_disk}${partition_suffix}1" /mnt/boot

# Mount the btrfs filesystem at /mnt/nix
mount -o noatime,nodiratime,subvol=root -t btrfs /dev/mapper/nixosEncrypted /mnt/nix
#mount -o noatime,nodiratime,subvol=nixos-config -t btrfs /dev/mapper/nixosEncrypted /mnt/etc/nixos
#mount -o noatime,nodiratime,subvol=logs -t btrfs /dev/mapper/nixosEncrypted /mnt/var/log
#mount -o noatime,nodiratime,subvol=logs -t btrfs /dev/mapper/nixosEncrypted /mnt/home

# Make required directories
mkdir -p /mnt/nix/persist/

# Run nixos-generate-config
nixos-generate-config --root /mnt

#replace configuration.nix from git repo

# Provision /etc/nixos/smb-secrets
read -p "Enter SMB username: " smb_username
read -sp "Enter SMB password: " smb_password
echo
credentials_file="/mnt/etc/nix/smb-secrets"
echo "username = $smb_username" > "$credentials_file"
echo "password = $smb_password" >> "$credentials_file"
chmod 600 "$credentials_file"
echo "SMB credentials file has been created at $credentials_file"

# Define the path to the configuration file
config_file="/mnt/etc/nixos/hardware-configuration.nix"

# Set initial user password
read -sp "Enter the password to hash: " user_password
echo
# Hash the password
hashed_password=$(echo "$user_password" | mkpasswd -m SHA-512 -s)
# Define the path for the NixOS configuration file
config_nix="/mnt/etc/nixos/configuration.nix"
# Replace the existing initialHashedPassword value
sed -i "s|initialHashedPassword = \".*\"|initialHashedPassword = \"$hashed_password\"|g" "$config_nix"
echo "Password hash has been added to $config_nix"

# Use sed to modify the file in place
sed -i '/fileSystems."\/" =/ , /fsType = "tmpfs";/ {
    s/device = "tmpfs";/device = "none";/
    /fsType = "tmpfs";/a\    options = [ "defaults" "size=4G" "mode=755" ];
}' "$config_file"

sed -i '/fsType = "btrfs";/!b;n;s/options = \[\(.*\)\];/options = [ "noatime" "nodiratime"\1];/' "$config_file"