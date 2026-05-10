#!/bin/bash
set -e

LOCK_FILE="/tmp/restore.lock"
RESTORE_MARK="/app/data/.restore-complete"

exec 200>$LOCK_FILE
flock -n 200 || exit 1

mkdir -p /app/data

if [ -f "$RESTORE_MARK" ]; then
    echo "Restore already completed"
    exit 0
fi

echo "Restoring backup from R2..."

TMP_DIR="/tmp/r2-restore"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

rclone copy r2:termix-backup "$TMP_DIR" \
    --fast-list \
    --transfers 4 \
    --checkers 8

if [ -f "$TMP_DIR/termix.db" ]; then
    sqlite3 "$TMP_DIR/termix.db" "PRAGMA wal_checkpoint(FULL);"
fi

cp -a "$TMP_DIR/." /app/data/

touch "$RESTORE_MARK"

rm -rf "$TMP_DIR"

echo "Restore completed"
