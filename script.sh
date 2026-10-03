#!/usr/bin/env bash

INTERVAL_SECONDS=5

while true; do
    {
        printf '%s\n' "--- $(date '+%Y-%m-%d %H:%M:%S') ---"
        free -h
        df -h
        uptime
        printf '\n'
    } >>monitor.log

    sleep "$INTERVAL_SECONDS"
done
