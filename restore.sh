#!/bin/bash

set -Eeuo pipefail

export RCLONE_CONFIG=/home/node/.config/rclone/rclone.conf

echo "========================================"
echo "Restoring backup from R2..."
echo "========================================"

mkdir -p /app/data

rm -f /app/data/*.sqlite-wal 2>/dev/null || true
rm -f /app/data/*.sqlite-shm 2>/dev/null || true

rclone copy r2:termix-backup /app/data \
    --fast-list \
    --transfers 2 \
    --checkers 4 \
    --ignore-errors \
    --retries 3 \
    --low-level-retries 10 \
    --exclude "*.log" \
    --exclude "cache/**" \
    --exclude "tmp/**" \
    --exclude ".DS_Store" \
    --exclude "opkssh/**" || true

chmod -R 755 /app/data 2>/dev/null || true

echo "Restore complete"
