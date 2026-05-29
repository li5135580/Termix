#!/bin/bash

echo "Creating rclone config..."

cat > /root/.config/rclone/rclone.conf <<EOF
[r2]
type = s3
provider = Cloudflare
access_key_id = ${R2_ACCESS_KEY_ID}
secret_access_key = ${R2_SECRET_ACCESS_KEY}
endpoint = ${R2_ENDPOINT}
acl = private
EOF

echo "Restoring backup..."

bash /restore.sh

echo "Starting supervisor..."

/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
