#!/usr/bin/env bash

set -euo pipefail

if (( EUID != 0 )); then
    echo 'Run with sudo' >&2
    exit 1
fi

cd "$(dirname "$0")"
mountpoint -q /mnt/raid
mountpoint -q /mnt/logs

mkdir -p /etc/my-app
if [[ ! -f /etc/my-app/storage.conf ]]; then
    echo "RAID_UUID=$(findmnt -rn -o UUID --mountpoint /mnt/raid)" > /etc/my-app/storage.conf
    echo "LOGS_UUID=$(findmnt -rn -o UUID --mountpoint /mnt/logs)" >> /etc/my-app/storage.conf
    mdadm --detail --scan > /etc/my-app/mdadm.conf
fi

if [[ ! -f /etc/ssl/private/my-app.key && ! -f /etc/ssl/certs/my-app.crt ]]; then
    ip=$(hostname -I | awk '{print $1}')
    (
        umask 077
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/ssl/private/my-app.key \
            -out /etc/ssl/certs/my-app.crt \
            -subj '/CN=my-app.local' \
            -addext "subjectAltName=DNS:my-app.local,DNS:localhost,IP:127.0.0.1,IP:$ip"
    )
fi

chmod 0600 /etc/ssl/private/my-app.key
chmod 0644 /etc/ssl/certs/my-app.crt

install -m 0755 restore-storage.sh /usr/local/sbin/restore-storage.sh
install -m 0644 systemd/restore-storage.service /etc/systemd/system/restore-storage.service
install -m 0644 systemd/my-app.service /etc/systemd/system/my-app.service
install -m 0644 nginx/my-app.conf /etc/nginx/sites-available/my-app
ln -sf /etc/nginx/sites-available/my-app /etc/nginx/sites-enabled/my-app

if [[ -L /etc/nginx/sites-enabled/default ]]; then
    unlink /etc/nginx/sites-enabled/default
fi

nginx -t
systemctl daemon-reload
systemctl enable --now docker restore-storage.service

if systemctl is-active --quiet my-app; then
    systemctl stop my-app
fi

docker compose build
docker compose stop
docker compose create --force-recreate

systemctl enable --now my-app nginx
systemctl reload nginx

for attempt in {1..15}; do
    if curl -fsS http://127.0.0.1:8080/monitor.log >/dev/null; then
        echo 'Service is ready'
        exit 0
    fi
    sleep 1
done

echo 'Service did not become ready' >&2
exit 1
