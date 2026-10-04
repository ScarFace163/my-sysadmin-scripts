#!/usr/bin/env bash

set -euo pipefail

if (( EUID != 0 )); then
    printf 'Run with sudo: sudo ./setup-storage.sh\n' >&2
    exit 1
fi

for tool in dd losetup mdadm pvcreate vgcreate lvcreate vgs mkfs.ext4 mount mountpoint; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Missing command: %s\n' "$tool" >&2
        exit 1
    fi
done

# Refuse to overwrite an existing lab or any existing array/volume group.
for disk in /mnt/raid-lab/disk1.img /mnt/raid-lab/disk2.img /mnt/raid-lab/disk3.img; do
    if [[ -e "$disk" || -L "$disk" ]]; then
        printf 'Lab disk already exists: %s; nothing was formatted.\n' "$disk" >&2
        exit 1
    fi
done

if [[ -e /dev/md0 ]] || vgs vg_data >/dev/null 2>&1; then
    printf 'Array md0 or volume group vg_data already exists.\n' >&2
    exit 1
fi

for directory in /mnt/raid-lab /mnt/raid /mnt/logs; do
    if [[ -L "$directory" ]] || mountpoint -q "$directory"; then
        printf 'Unsafe or mounted target: %s\n' "$directory" >&2
        exit 1
    fi
    if [[ -d "$directory" && -n "$(ls -A "$directory")" ]]; then
        printf 'Target directory is not empty: %s\n' "$directory" >&2
        exit 1
    fi
done

mkdir -p /mnt/raid-lab /mnt/raid /mnt/logs

for number in 1 2 3; do
    dd if=/dev/zero of="/mnt/raid-lab/disk${number}.img" bs=1M count=512 status=none
done

LOOP1=$(losetup -f --show /mnt/raid-lab/disk1.img)
LOOP2=$(losetup -f --show /mnt/raid-lab/disk2.img)
LOOP3=$(losetup -f --show /mnt/raid-lab/disk3.img)
printf 'Lab devices: %s %s %s\n' "$LOOP1" "$LOOP2" "$LOOP3"

mdadm --create /dev/md0 --level=1 --raid-devices=2 --run "$LOOP1" "$LOOP2"
mkfs.ext4 /dev/md0
mount /dev/md0 /mnt/raid

pvcreate --yes "$LOOP3"
vgcreate vg_data "$LOOP3"
lvcreate --yes -L 200M -n lv_logs vg_data
mkfs.ext4 /dev/vg_data/lv_logs
mount /dev/vg_data/lv_logs /mnt/logs

mdadm --wait /dev/md0
cat /proc/mdstat
lvs
df -h /mnt/raid /mnt/logs
