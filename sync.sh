#!/bin/bash

while true
do
    echo "Syncing to R2..."

    rclone --config /app/.config/rclone/rclone.conf sync /app/data r2:termix-backup \
      --fast-list \
      --transfers 4 \
      --checkers 8 \
      --exclude "*.log" \
      --exclude "cache/**" \
      --exclude "tmp/**"

    sleep 30
done
