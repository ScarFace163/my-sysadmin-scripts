#!/usr/bin/env bash

set -u

INTERVAL_SECONDS=5
LOG_FILE="${LOG_FILE:-monitor.log}"
MAX_SAMPLES="${MAX_SAMPLES:-0}"

for command_name in date free df uptime sleep; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Ошибка: команда %s не найдена.\n' "$command_name" >&2
        exit 1
    fi
done

if ! [[ "$MAX_SAMPLES" =~ ^[0-9]+$ ]]; then
    printf 'Ошибка: MAX_SAMPLES должно быть целым неотрицательным числом.\n' >&2
    exit 1
fi

if ! touch "$LOG_FILE" 2>/dev/null; then
    printf 'Ошибка: невозможно записать в %s.\n' "$LOG_FILE" >&2
    exit 1
fi

sample_count=0

while true; do
    {
        printf '%s\n' "--- $(date '+%Y-%m-%d %H:%M:%S') ---"
        free -h
        df -h
        uptime
        printf '\n'
    } >>"$LOG_FILE"

    sample_count=$((sample_count + 1))

    if (( MAX_SAMPLES > 0 && sample_count >= MAX_SAMPLES )); then
        break
    fi

    sleep "$INTERVAL_SECONDS"
done
