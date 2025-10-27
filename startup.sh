#!/bin/bash
set -e

echo "Starting Thumbor container services..."
echo "======================================="

# Azure Web App provides PORT environment variable
if [ -n "$PORT" ]; then
    echo "Azure PORT detected: $PORT"
    # Update nginx to listen on the Azure-provided port
    sed -i "s/listen 80 default_server;/listen $PORT default_server;/" /etc/nginx/nginx.conf
    sed -i "s/listen \[::\]:80 default_server;/listen [::]:$PORT default_server;/" /etc/nginx/nginx.conf
else
    echo "Using default port 80"
fi

# Initialize Redis data directory
if [ ! -d "/data/redis" ]; then
    mkdir -p /data/redis
    chown redis:redis /data/redis
fi

# Initialize Thumbor storage directories
echo "Initializing storage directories..."
mkdir -p /data/thumbor/storage
mkdir -p /data/thumbor/result_storage
mkdir -p /data/thumbor/cache
mkdir -p /var/cache/nginx
mkdir -p /app/logs

# Set permissions
chmod 755 /data/thumbor/storage
chmod 755 /data/thumbor/result_storage
chmod 755 /data/thumbor/cache
chmod 755 /var/cache/nginx
chmod 755 /app/logs

# Note: Redis connectivity will be handled by supervisord
echo "Redis will be managed by supervisord..."

# Environment variable processing
echo "Processing environment variables..."

# Set default values if not provided
export THUMBOR_NUM_PROCESSES=${THUMBOR_NUM_PROCESSES:-4}
export SECURITY_KEY=${SECURITY_KEY:-MY_SECURE_KEY_CHANGE_THIS_IN_PRODUCTION}
export ALLOW_UNSAFE_URL=${ALLOW_UNSAFE_URL:-True}
export AUTO_WEBP=${AUTO_WEBP:-True}
export CORS_ALLOW_ORIGIN=${CORS_ALLOW_ORIGIN:-*}

# Redis configuration
export REDIS_SERVER_HOST=${REDIS_SERVER_HOST:-localhost}
export REDIS_SERVER_PORT=${REDIS_SERVER_PORT:-6379}
export REDIS_SERVER_DB=${REDIS_SERVER_DB:-0}

# Cache configuration
export THUMBOR_PROXY_CACHE_SIZE=${THUMBOR_PROXY_CACHE_SIZE:-100g}
export THUMBOR_PROXY_CACHE_MEMORY_SIZE=${THUMBOR_PROXY_CACHE_MEMORY_SIZE:-1024m}
export THUMBOR_PROXY_CACHE_INACTIVE=${THUMBOR_PROXY_CACHE_INACTIVE:-512m}
export THUMBOR_PROXY_CACHE_DURATION=${THUMBOR_PROXY_CACHE_DURATION:-1m}

# Update nginx cache settings based on environment variables
echo "Configuring Nginx cache settings..."
if [ -n "$THUMBOR_PROXY_CACHE_SIZE" ]; then
    sed -i "s/max_size=100g/max_size=${THUMBOR_PROXY_CACHE_SIZE}/" /etc/nginx/nginx.conf
fi
if [ -n "$THUMBOR_PROXY_CACHE_MEMORY_SIZE" ]; then
    sed -i "s/keys_zone=thumbor_cache:1024m/keys_zone=thumbor_cache:${THUMBOR_PROXY_CACHE_MEMORY_SIZE}/" /etc/nginx/nginx.conf
fi
if [ -n "$THUMBOR_PROXY_CACHE_INACTIVE" ]; then
    sed -i "s/inactive=512m/inactive=${THUMBOR_PROXY_CACHE_INACTIVE}/" /etc/nginx/nginx.conf
fi
if [ -n "$THUMBOR_PROXY_CACHE_DURATION" ]; then
    sed -i "s/proxy_cache_valid 200 301 302 1m;/proxy_cache_valid 200 301 302 ${THUMBOR_PROXY_CACHE_DURATION};/" /etc/nginx/nginx.conf
    sed -i "s/proxy_cache_valid 404 1m;/proxy_cache_valid 404 ${THUMBOR_PROXY_CACHE_DURATION};/" /etc/nginx/nginx.conf
    sed -i "s/proxy_cache_valid any 1m;/proxy_cache_valid any ${THUMBOR_PROXY_CACHE_DURATION};/" /etc/nginx/nginx.conf
fi

# Update Thumbor configuration with environment variables
if [ -n "$SECURITY_KEY" ]; then
    sed -i "s/Config.SECURITY_KEY = .*/Config.SECURITY_KEY = '$SECURITY_KEY'/" /app/thumbor/thumbor.conf
fi

# Test nginx configuration
echo "Testing Nginx configuration..."
nginx -t || {
    echo "Nginx configuration test failed!"
    exit 1
}

# Azure specific: Handle SSH for debugging (port 2222)
if [ "$ENABLE_SSH" = "true" ]; then
    echo "Enabling SSH on port 2222 for Azure debugging..."
    mkdir -p /run/sshd
    /usr/sbin/sshd -D -p 2222 &
fi

# Clean up any stale pid files
rm -f /var/run/supervisord.pid
rm -f /var/run/nginx.pid

# Start supervisord
echo "Starting supervisord..."
echo "======================================="
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf