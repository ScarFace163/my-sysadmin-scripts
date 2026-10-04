#!/usr/bin/env bash

set -euo pipefail

if (( EUID != 0 )); then
    echo 'Run with sudo' >&2
    exit 1
fi

source /etc/my-app/storage.conf

for disk in /mnt/raid-lab/disk1.img /mnt/raid-lab/disk2.img /mnt/raid-lab/disk3.img; do
    if [[ ! -f "$disk" || -L "$disk" ]]; then
        echo "Missing or linked disk: $disk" >&2
        exit 1
    fi
    if [[ -z "$(losetup -j "$disk")" ]]; then
        losetup -f --show "$disk"
    fi
done

udevadm settle

if ! blkid -U "$RAID_UUID" >/dev/null 2>&1; then
    mdadm --assemble --scan --config=/etc/my-app/mdadm.conf
fi

vgchange -ay vg_data
udevadm settle

mount_volume() {
    local uuid=$1 directory=$2

    if [[ -L "$directory" ]]; then
        echo "Linked mount directory: $directory" >&2
        exit 1
    fi

    if mountpoint -q "$directory"; then
        if [[ "$(findmnt -rn -o UUID --mountpoint "$directory")" != "$uuid" ]]; then
            echo "Unexpected volume at $directory" >&2
            exit 1
        fi
    else
        mkdir -p "$directory"
        mount -U "$uuid" "$directory"
    fi
}

mount_volume "$RAID_UUID" /mnt/raid
mount_volume "$LOGS_UUID" /mnt/logs
