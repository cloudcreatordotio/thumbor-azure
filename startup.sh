#!/bin/bash
set -e

echo "Starting Thumbor container services..."
echo "======================================="

# Azure Web App provides PORT environment variable
if [ -n "$PORT" ]; then
    echo "Azure PORT detected: $PORT"
    # Note: Port configuration is now handled via NGINX_LISTEN_PORT at build time
    # For runtime Azure port changes, we'll need to regenerate the config
    if [ "$PORT" != "$NGINX_LISTEN_PORT" ]; then
        echo "WARNING: Runtime PORT ($PORT) differs from build-time NGINX_LISTEN_PORT ($NGINX_LISTEN_PORT)"
        echo "Container was built for port $NGINX_LISTEN_PORT"
        # In production, you'd want to rebuild the image with the correct PORT
    fi
else
    echo "Using configured port: ${NGINX_LISTEN_PORT:-80}"
fi

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

# Cache configuration (these are now build-time configs)
export THUMBOR_PROXY_CACHE_SIZE=${THUMBOR_PROXY_CACHE_SIZE:-100g}
export THUMBOR_PROXY_CACHE_MEMORY_SIZE=${THUMBOR_PROXY_CACHE_MEMORY_SIZE:-1024m}
export THUMBOR_PROXY_CACHE_INACTIVE=${THUMBOR_PROXY_CACHE_INACTIVE:-512m}
export THUMBOR_PROXY_CACHE_DURATION=${THUMBOR_PROXY_CACHE_DURATION:-1m}

# Note: Thumbor configuration uses os.environ.get() so it reads environment variables directly
echo "Thumbor will use environment variables for configuration"

# Test nginx configuration
echo "Testing Nginx configuration..."
nginx -t || {
    echo "Nginx configuration test failed!"
    exit 1
}

# Start supervisord
echo "Starting supervisord..."
echo "======================================="
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf