#!/usr/bin/env bash

set -euo pipefail

if (( EUID != 0 )); then
    echo 'Run with sudo' >&2
    exit 1
fi

for disk in /mnt/raid-lab/disk1.img /mnt/raid-lab/disk2.img /mnt/raid-lab/disk3.img; do
    if [[ -e "$disk" || -L "$disk" ]]; then
        echo "Disk already exists: $disk" >&2
        exit 1
    fi
done

if [[ -e /dev/md0 ]] || vgs vg_data >/dev/null 2>&1; then
    echo 'md0 or vg_data already exists' >&2
    exit 1
fi

for directory in /mnt/raid-lab /mnt/raid /mnt/logs; do
    if [[ -L "$directory" ]] || mountpoint -q "$directory"; then
        echo "Directory is linked or mounted: $directory" >&2
        exit 1
    fi
    if [[ -d "$directory" && -n "$(ls -A "$directory")" ]]; then
        echo "Directory is not empty: $directory" >&2
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
