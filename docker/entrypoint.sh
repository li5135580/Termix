#!/bin/bash

set -eu

PUID=${PUID:-1000}
PGID=${PGID:-1000}

# =========================
# User Permission Setup
# =========================

if [ "$(id -u)" = "0" ]; then

    if [ "$PUID" = "0" ]; then

        echo "Running as root (PUID=0 PGID=$PGID)"

        chown -R root:root \
            /app/data \
            /app/uploads \
            /tmp/nginx \
            /home/node/.config 2>/dev/null || true

    else

        echo "Setting up user permissions (PUID=$PUID PGID=$PGID)"

        groupmod -o -g "$PGID" node 2>/dev/null || true
        usermod -o -u "$PUID" node 2>/dev/null || true

        mkdir -p /home/node/.config/rclone

        chown -R node:node \
            /app/data \
            /app/uploads \
            /tmp/nginx \
            /home/node/.config 2>/dev/null || true

        echo "User node is now UID=$PUID GID=$PGID"

        exec gosu node:node "$0" "$@"

    fi

fi

# =========================
# ENV
# =========================

export PORT=${PORT:-8080}
export ENABLE_SSL=${ENABLE_SSL:-false}
export SSL_PORT=${SSL_PORT:-8443}

export SSL_CERT_PATH=${SSL_CERT_PATH:-/app/data/ssl/termix.crt}
export SSL_KEY_PATH=${SSL_KEY_PATH:-/app/data/ssl/termix.key}

export DATA_DIR=${DATA_DIR:-/app/data}

export RCLONE_CONFIG=/home/node/.config/rclone/rclone.conf

# =========================
# Directories
# =========================

mkdir -p \
    /tmp/nginx \
    /app/data \
    /app/uploads \
    /app/data/ssl \
    /home/node/.config/rclone \
    /app/data/opkssh

chmod 755 \
    /app/data \
    /app/uploads \
    /app/data/ssl \
    /app/data/opkssh 2>/dev/null || true

# =========================
# Nginx Config
# =========================

echo "========================================"
echo "Configuring web UI on port $PORT"
echo "========================================"

if [ "$ENABLE_SSL" = "true" ]; then

    echo "SSL ENABLED"

    NGINX_CONF_SOURCE="/app/nginx/nginx-https.conf.template"

else

    echo "SSL DISABLED"

    NGINX_CONF_SOURCE="/app/nginx/nginx.conf.template"

fi

envsubst '${PORT} ${SSL_PORT} ${SSL_CERT_PATH} ${SSL_KEY_PATH}' \
    < "$NGINX_CONF_SOURCE" \
    > /tmp/nginx/nginx.conf

# =========================
# Writable Check
# =========================

echo "========================================"
echo "Checking directories"
echo "========================================"

[ -w /app/data ] && echo "Data writable" || echo "WARNING: data not writable"

[ -w /app/uploads ] && echo "Uploads writable" || echo "WARNING: uploads not writable"

[ -w /app/data/opkssh ] && echo "OPKSSH writable" || echo "WARNING: OPKSSH not writable"

# =========================
# Rclone Config
# =========================

echo "========================================"
echo "Creating rclone config"
echo "========================================"

cat > "$RCLONE_CONFIG" <<EOF
[r2]
type = s3
provider = Cloudflare
access_key_id = ${R2_ACCESS_KEY_ID}
secret_access_key = ${R2_SECRET_ACCESS_KEY}
endpoint = https://${R2_ENDPOINT}
acl = private
no_check_bucket = true
EOF

chmod 600 "$RCLONE_CONFIG"

echo "========================================"
echo "Testing R2 connection"
echo "========================================"

rclone lsd r2: >/dev/null 2>&1 || {
    echo "CRITICAL: R2 connection failed"
    exit 1
}

echo "R2 connection successful"

# =========================
# Restore
# =========================

echo "========================================"
echo "Restoring backup from R2"
echo "========================================"

bash /restore.sh || {
    echo "WARNING: restore failed"
}

# =========================
# SQLite Safety
# =========================

rm -f /app/data/*.sqlite-wal 2>/dev/null || true
rm -f /app/data/*.sqlite-shm 2>/dev/null || true

# =========================
# SSL
# =========================

if [ "$ENABLE_SSL" = "true" ]; then

    DOMAIN=${SSL_DOMAIN:-localhost}

    if [ ! -f "$SSL_CERT_PATH" ] || [ ! -f "$SSL_KEY_PATH" ]; then

        echo "Generating SSL certificate"

        cat > /app/data/ssl/openssl.conf <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=US
ST=State
L=City
O=Termix
OU=IT
CN=$DOMAIN

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF

        openssl genrsa -out "$SSL_KEY_PATH" 2048

        openssl req -new -x509 \
            -key "$SSL_KEY_PATH" \
            -out "$SSL_CERT_PATH" \
            -days 365 \
            -config /app/data/ssl/openssl.conf \
            -extensions v3_req

        chmod 600 "$SSL_KEY_PATH"
        chmod 644 "$SSL_CERT_PATH"

        rm -f /app/data/ssl/openssl.conf

    fi

fi

# =========================
# Start nginx
# =========================

echo "========================================"
echo "Starting nginx"
echo "========================================"

nginx -c /tmp/nginx/nginx.conf || {
    echo "CRITICAL: nginx failed"
    exit 1
}

# =========================
# Delay Sync Startup
# =========================

echo "========================================"
echo "Waiting for backend stabilization"
echo "========================================"

sleep 15

# =========================
# Background Sync
# =========================

echo "========================================"
echo "Starting background R2 sync"
echo "========================================"

(
    while true; do

        echo "$(date): Syncing to R2..."

        rclone copy /app/data/ r2:termix-backup \
            --transfers=1 \
            --checkers=1 \
            --fast-list \
            --ignore-errors \
            --exclude "*.sqlite-shm" \
            --exclude "*.sqlite-wal" || true

        echo "$(date): Sync completed"

        sleep 300

    done
) &

# =========================
# Start Backend
# =========================

echo "========================================"
echo "Starting backend services"
echo "========================================"

cd /app

export NODE_ENV=production

if [ -f package.json ]; then

    VERSION=$(grep '"version"' package.json | sed 's/.*"version": *"\([^"]*\)".*/\1/')

    [ -n "$VERSION" ] && export VERSION

fi

exec node dist/backend/backend/starter.js
