#!/bin/bash
set -e

LOCK_FILE="/tmp/r2-sync.lock"

cleanup() {
    echo "Received stop signal, syncing before exit..."

    rclone copy /app/data r2:termix-backup \
        --fast-list \
        --transfers 4 \
        --checkers 8 \
        --exclude "*.log" \
        --exclude "*.sqlite-shm" \
        --exclude "*.sqlite-wal" \
        --exclude "cache/**" \
        --exclude "tmp/**" \
        --exclude "node_modules/**"

    exit 0
}

trap cleanup SIGTERM SIGINT

while true; do

    exec 200>$LOCK_FILE
    flock -n 200 || {
        sleep 10
        continue
    }

    echo "$(date): Syncing to R2..."

    find /app/data -type f -name "*.log" -size +20M -delete || true
    find /app/data -type f -name "*.tmp" -delete || true
done
