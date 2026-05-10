#!/bin/bash

echo "Restoring backup from R2..."

mkdir -p /app/data

rclone --config /app/.config/rclone/rclone.conf sync r2:termix-backup /app/data

echo "Restore complete"
