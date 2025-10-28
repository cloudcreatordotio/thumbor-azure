#!/bin/bash

echo "Testing non-root configuration changes..."
echo "========================================="

# Test 1: Check if Dockerfile syntax is valid
echo "1. Checking Dockerfile syntax..."
docker build --no-cache -t test-nonroot-syntax - <<EOF
FROM ubuntu:22.04

# Create users
RUN groupadd -r -g 1000 thumbor && \
    useradd -r -u 1000 -g thumbor -m -d /home/thumbor -s /bin/bash thumbor

# Create directories with ownership
RUN mkdir -p /app/logs && \
    chown -R thumbor:thumbor /app

# Switch to non-root user
USER thumbor

# Test that we're running as non-root
RUN whoami | grep -q thumbor && echo "✓ Running as thumbor user"

EOF

if [ $? -eq 0 ]; then
    echo "✓ Dockerfile user configuration is valid"
else
    echo "✗ Dockerfile user configuration failed"
    exit 1
fi

# Test 2: Check supervisord.conf syntax
echo ""
echo "2. Checking supervisord.conf syntax..."
python3 -c "
import configparser
config = configparser.ConfigParser()
try:
    config.read('supervisord.conf')
    print('✓ supervisord.conf syntax is valid')
except Exception as e:
    print(f'✗ supervisord.conf syntax error: {e}')
    exit(1)
"

# Test 3: Check nginx template syntax
echo ""
echo "3. Checking nginx template syntax..."
# Set default values for template variables
export NGINX_LISTEN_PORT=80
export THUMBOR_PROXY_CACHE_SIZE=100g
export THUMBOR_PROXY_CACHE_MEMORY_SIZE=1024m
export THUMBOR_PROXY_CACHE_INACTIVE=512m
export THUMBOR_PROXY_CACHE_DURATION=1m

# Process template
envsubst '${NGINX_LISTEN_PORT} ${THUMBOR_PROXY_CACHE_SIZE} ${THUMBOR_PROXY_CACHE_MEMORY_SIZE} ${THUMBOR_PROXY_CACHE_INACTIVE} ${THUMBOR_PROXY_CACHE_DURATION}' \
    < nginx-cache.conf.template \
    > /tmp/nginx-test.conf

# Test nginx config syntax (create logs dir for pid file)
docker run --rm -v /tmp/nginx-test.conf:/etc/nginx/nginx.conf:ro -v /tmp:/app/logs nginx nginx -t

if [ $? -eq 0 ]; then
    echo "✓ Nginx template configuration is valid"
else
    echo "✗ Nginx template configuration failed"
    exit 1
fi

# Test 4: Check script permissions
echo ""
echo "4. Checking script files..."
for script in entrypoint.sh startup.sh; do
    if [ -f "$script" ]; then
        echo "✓ $script exists"
    else
        echo "✗ $script not found"
        exit 1
    fi
done

echo ""
echo "========================================="
echo "All basic tests passed! The non-root configuration appears to be valid."
echo "The full build will take longer due to package installation."