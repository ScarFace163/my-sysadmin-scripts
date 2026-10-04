#!/usr/bin/env bash

set -euo pipefail

/usr/local/bin/script.sh &
monitor_pid=$!

python3 -u -m http.server 8080 --bind 0.0.0.0 --directory /data &
server_pid=$!

trap 'kill "$monitor_pid" "$server_pid" 2>/dev/null || true; wait "$monitor_pid" "$server_pid" 2>/dev/null || true' EXIT
trap 'exit 0' TERM INT

wait -n "$monitor_pid" "$server_pid"
exit 1
