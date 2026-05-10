#!/bin/bash

LOCK_FILE="/tmp/r2-sync.lock"

exec 200>$LOCK_FILE

trap "exit 0" SIGTERM SIGINT

while true; do

    flock -n 200 || {
        sleep 10
        continue
    }

    echo "$(date): Syncing to R2..."

    if [ -f /app/data/termix.db ]; then
        sqlite3 /app/data/termix.db \
        "PRAGMA wal_checkpoint(TRUNCATE);" || true
    fi

    rclone copy /app/data r2:termix-backup \
        --fast-list \
        --transfers 2 \
        --checkers 4 \
        --exclude "*.sqlite-shm" \
        --exclude "*.sqlite-wal" \
        --exclude "*.log" \
        --exclude "tmp/**" \
        --exclude "cache/**" \
        --ignore-errors \
        --retries 3 \
        --low-level-retries 10 || true

    echo "$(date): Sync completed"

    sleep 180

done
