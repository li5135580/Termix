#!/bin/bash

set -eu

export RCLONE_CONFIG=/home/node/.config/rclone/rclone.conf

LOCK_FILE="/tmp/r2-sync.lock"

exec 200>$LOCK_FILE

flock -n 200 || exit 0

echo "========================================"
echo "$(date): Syncing to R2..."
echo "========================================"

if [ -f /app/data/termix.db ]; then

    sqlite3 /app/data/termix.db \
        "PRAGMA wal_checkpoint(TRUNCATE);" || true

fi

rclone copy /app/data/ r2:termix-backup \
    --fast-list \
    --transfers 2 \
    --checkers 4 \
    --create-empty-src-dirs \
    --ignore-errors \
    --retries 3 \
    --low-level-retries 10 \
    --exclude "*.log" \
    --exclude "*.sqlite-shm" \
    --exclude "*.sqlite-wal" \
    --exclude "cache/**" \
    --exclude "tmp/**" \
    --exclude ".DS_Store" \
    --exclude "opkssh/**" \
    --s3-upload-concurrency 2 \
    --buffer-size 4M || true

echo "$(date): Sync completed"
