#!/bin/bash
set -e

echo "Starting Thumbor container entrypoint..."
echo "======================================="

# Function to check and fix ownership of a directory
fix_ownership() {
    local dir="$1"
    local user="$2"
    local group="$3"

    if [ -d "$dir" ]; then
        # Check if we're running as root and can change ownership
        if [ "$(id -u)" = "0" ]; then
            echo "Adjusting ownership of $dir to $user:$group"
            chown -R "$user:$group" "$dir" 2>/dev/null || true
        else
            # Running as non-root, check if we have write access
            if [ -w "$dir" ]; then
                echo "✓ Write access confirmed for $dir"
            else
                echo "⚠ Warning: No write access to $dir (running as $(whoami))"
                # Try to continue anyway - some operations might still work
            fi
        fi
    else
        # Directory doesn't exist, try to create it
        echo "Creating directory: $dir"
        mkdir -p "$dir" 2>/dev/null || {
            echo "⚠ Warning: Could not create $dir (running as $(whoami))"
        }

        # If running as root, set ownership after creation
        if [ "$(id -u)" = "0" ] && [ -d "$dir" ]; then
            chown -R "$user:$group" "$dir" 2>/dev/null || true
        fi
    fi
}

# Function to handle permission compatibility
handle_permissions() {
    echo "Checking and adjusting permissions..."

    # Application directories
    fix_ownership "/app/logs" "thumbor" "thumbor"
    fix_ownership "/app/thumbor" "thumbor" "thumbor"

    # Thumbor data directories
    fix_ownership "/data/thumbor/storage" "thumbor" "thumbor"
    fix_ownership "/data/thumbor/result_storage" "thumbor" "thumbor"
    fix_ownership "/data/thumbor/cache" "thumbor" "thumbor"

    # Nginx directories
    fix_ownership "/var/cache/nginx" "www-data" "www-data"
    fix_ownership "/run/nginx" "www-data" "www-data"

    # Redis directory
    fix_ownership "/data/redis" "redis" "redis"

    # Supervisor directory
    fix_ownership "/var/log/supervisor" "thumbor" "thumbor"

    # Set proper permissions for directories
    chmod 755 /app/logs 2>/dev/null || true
    chmod 755 /data/thumbor/storage 2>/dev/null || true
    chmod 755 /data/thumbor/result_storage 2>/dev/null || true
    chmod 755 /data/thumbor/cache 2>/dev/null || true
    chmod 755 /var/cache/nginx 2>/dev/null || true
}

# Handle special case for Azure Web Apps
if [ -n "$WEBSITE_INSTANCE_ID" ]; then
    echo "Azure Web App environment detected"

    # Handle dynamic PORT configuration for Azure
    if [ -n "$PORT" ] && [ "$PORT" != "$NGINX_LISTEN_PORT" ]; then
        echo "Regenerating nginx config for Azure PORT: $PORT"
        export NGINX_LISTEN_PORT=$PORT

        # Check if we have the template file
        if [ -f "/tmp/nginx-cache.conf.template" ]; then
            envsubst '${NGINX_LISTEN_PORT} ${THUMBOR_PROXY_CACHE_SIZE} ${THUMBOR_PROXY_CACHE_MEMORY_SIZE} ${THUMBOR_PROXY_CACHE_INACTIVE} ${THUMBOR_PROXY_CACHE_DURATION}' \
                < /tmp/nginx-cache.conf.template \
                > /etc/nginx/nginx.conf
        else
            echo "Warning: Cannot regenerate nginx config - template not found"
        fi
    fi

    # Azure Web Apps may run containers as root initially
    # but we should drop privileges after setup
    if [ "$(id -u)" = "0" ]; then
        echo "Running initial setup as root for Azure compatibility"
        handle_permissions

        # Clean up any stale pid files
        rm -f /var/run/supervisord.pid 2>/dev/null || true
        rm -f /app/logs/nginx.pid 2>/dev/null || true

        # Azure specific: Handle SSH for debugging (port 2222)
        if [ "$ENABLE_SSH" = "true" ]; then
            echo "Enabling SSH on port 2222 for Azure debugging..."
            mkdir -p /run/sshd
            /usr/sbin/sshd -D -p 2222 &
        fi

        # Drop to thumbor user for running services
        echo "Dropping privileges to thumbor user..."
        exec su-exec thumbor /app/startup.sh "$@"
    else
        # Already running as non-root
        exec /app/startup.sh "$@"
    fi
else
    # Non-Azure environment
    handle_permissions

    # Clean up any stale pid files
    rm -f /var/run/supervisord.pid 2>/dev/null || true
    rm -f /app/logs/nginx.pid 2>/dev/null || true

    # Execute the main startup script
    exec /app/startup.sh "$@"
fi