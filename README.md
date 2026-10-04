# Resource monitoring lab

Скрипт каждые пять секунд записывает время, состояние памяти, дисков и нагрузку системы; HTTP-сервер отдаёт этот лог через Nginx и HTTPS.

## Подготовка Ubuntu 22.04

```bash
cd ~/my-sysadmin-scripts
sudo apt update
sudo apt install -y docker.io docker-compose-v2 docker-buildx mdadm lvm2 nginx openssl curl
```

## Учебное хранилище

На новой машине сначала выполни:

```bash
sudo ./setup-storage.sh
```

Скрипт создаёт три файла по 512 МиБ в `/mnt/raid-lab` и получает свободные loop-устройства через `losetup --show`.

- Два файла образуют RAID 1 `/dev/md0`, смонтированный в `/mnt/raid`.
- Третий файл используется для LVM: `vg_data/lv_logs` на 200 МиБ, смонтированный в `/mnt/logs`.

Это первоначальная настройка: при существующих файлах, массиве или группе томов скрипт отказывается от повторного создания.

## Проверка Docker

```bash
sudo docker build -t my-script .
sudo docker run -e MAX_SAMPLES=1 my-script bash -c '/usr/local/bin/script.sh && cat /data/monitor.log'
sudo docker ps -a
```

`MAX_SAMPLES=1` ограничивает проверочный запуск одним замером; по умолчанию мониторинг работает непрерывно.
Образ содержит `procps` для мониторинга и `python3` для HTTP-сервера.
`start-service.sh` запускает оба процесса и завершает контейнер, если любой из них неожиданно остановился.

## HTTPS и автозапуск

После создания хранилища:

```bash
sudo ./setup-service.sh
```

Скрипт собирает образ, создаёт контейнер `my-app`, устанавливает конфиг Nginx и включает systemd-службы.

- Compose подключает `/mnt/logs` к `/data`; лог сохраняется на LVM-томе.
- HTTP-сервер контейнера доступен на VM через `127.0.0.1:8080`.
- Nginx перенаправляет HTTP на HTTPS и передаёт запросы контейнеру.
- Самоподписанный сертификат создаётся для `my-app.local`, localhost и текущего IP машины.
- Приватный ключ находится в `/etc/ssl/private/my-app.key`, сертификат — в `/etc/ssl/certs/my-app.crt`.
- `restore-storage.service` после перезагрузки подключает существующие файлы-диски и монтирует тома по UUID без форматирования.
- `my-app.service` запускает контейнер после Docker и восстановления хранилища.

UUID томов и описание массива сохраняются на VM в `/etc/my-app/`.
Повторный запуск `setup-service.sh` пересобирает и пересоздаёт контейнер, сохраняя данные и сертификат.

Проверка на VM:

```bash
curl -I http://127.0.0.1:8080/monitor.log
sudo nginx -t
curl -kI https://127.0.0.1/
sudo systemctl status my-app --no-pager
sudo systemctl is-enabled my-app
sudo journalctl -u my-app -n 15 --no-pager
```

`-k` используется для учебного самоподписанного сертификата.
Проверить сертификат без отключения проверки можно так:

```bash
curl --cacert /etc/ssl/certs/my-app.crt -I https://127.0.0.1/monitor.log
```

С Mac лог доступен по адресу `https://<IP-адрес-VM>/monitor.log`.

## Управление

После настройки сервисом управляет systemd:

```bash
sudo systemctl stop my-app
sudo systemctl start my-app
sudo systemctl restart my-app
```

Для обновления образа и конфигурации повторно выполни `sudo ./setup-service.sh`.
`free` и `uptime` внутри контейнера показывают данные ядра VM, а `df` — файловые системы, доступные контейнеру.

## Материалы

- `sample_output.txt` — пример запуска из ДЗ1.
- `part1_output.txt` — результаты проверки первой части ДЗ2.
