# Resource monitoring lab

Скрипт каждые пять секунд записывает время, состояние памяти, дисков и нагрузку системы.

## Подготовка Ubuntu 22.04

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2 docker-buildx mdadm lvm2
```

## Учебное хранилище

```bash
sudo ./setup-storage.sh
```

Скрипт создаёт три файла по 512 МиБ в `/mnt/raid-lab` и получает свободные loop-устройства через `losetup --show`.

- Два файла образуют RAID 1 `/dev/md0`, смонтированный в `/mnt/raid`.
- Третий файл используется для LVM: `vg_data/lv_logs` на 200 МиБ, смонтированный в `/mnt/logs`.

Это первоначальная настройка: при существующих файлах, массиве или группе томов скрипт отказывается от повторного создания.
Loop-устройства и монтирования относятся к текущему запуску VM; после перезагрузки их нужно подключить заново без форматирования.

## Docker

```bash
sudo docker build -t my-script .
sudo docker run -e MAX_SAMPLES=1 my-script bash -c '/usr/local/bin/script.sh && cat /data/monitor.log'
sudo docker ps -a
```

`MAX_SAMPLES=1` ограничивает проверочный запуск одним замером; по умолчанию скрипт работает непрерывно.
`procps` в образе обеспечивает наличие `free` и `uptime`.

## Docker Compose и том

Перед запуском проверь, что LVM-том смонтирован:

```bash
mountpoint /mnt/logs
sudo docker compose up -d --build
sudo docker compose ps
sudo tail -18 /mnt/logs/monitor.log
```

Compose подключает `/mnt/logs` к `/data`, поэтому файл `/data/monitor.log` в контейнере сохраняется на учебном LVM-томе.
Пересоздание контейнера сохраняет старые записи и добавляет новые:

```bash
sudo docker compose up -d --force-recreate
sudo tail -18 /mnt/logs/monitor.log
```

Остановка мониторинга:

```bash
sudo docker compose stop
```

`free` и `uptime` внутри контейнера показывают данные ядра VM, а `df` — файловые системы, доступные контейнеру.

## Материалы

- `sample_output.txt` — пример запуска из ДЗ1.
- `part1_output.txt` — результаты проверки Docker, RAID, LVM и сохранности лога.
