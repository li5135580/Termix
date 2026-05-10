#!/bin/sh
set -e

mkdir -p \
    /app/data \
    /app/uploads \
    /app/data/.opk \
    /app/.config/rclone \
    /var/log/supervisor \
    /tmp/nginx

cat > /app/.config/rclone/rclone.conf <<EOF
[r2]
type = s3
provider = Cloudflare
access_key_id = ${R2_ACCESS_KEY_ID}
secret_access_key = ${R2_SECRET_ACCESS_KEY}
endpoint = ${R2_ENDPOINT}
acl = private
EOF

chmod 600 /app/.config/rclone/rclone.conf

bash /restore.sh || true

export PORT=${PORT:-8080}

if [ "$ENABLE_SSL" = "true" ]; then
    envsubst '${PORT} ${SSL_PORT} ${SSL_CERT_PATH} ${SSL_KEY_PATH}' \
    < /app/nginx/nginx-https.conf.template \
    > /tmp/nginx/nginx.conf
else
    envsubst '${PORT}' \
    < /app/nginx/nginx.conf.template \
    > /tmp/nginx/nginx.conf
fi
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
