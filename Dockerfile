FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Add deadsnakes PPA for Python 3.11
RUN apt-get update && apt-get install -y \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update

# Install system dependencies
RUN apt-get install -y \
    # Python 3.11 and related packages \
    python3.11 \
    python3.11-dev \
    python3.11-distutils \
    python3.11-venv \
    python3-pip \
    build-essential \
    # Image processing libraries \
    libcurl4-openssl-dev \
    libssl-dev \
    libjpeg-dev \
    libpng-dev \
    libwebp-dev \
    libgif-dev \
    libexif-dev \
    libboost-python-dev \
    libboost-system-dev \
    libboost-thread-dev \
    webp \
    # OpenCV dependencies \
    libopencv-dev \
    python3-opencv \
    # OpenCV runtime dependencies for RemoteCV
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    # Video processing
    ffmpeg \
    gifsicle \
    # Redis
    redis-server \
    # Nginx with cache purge module
    nginx \
    libnginx-mod-http-cache-purge \
    # Process management
    supervisor \
    # Utilities
    curl \
    wget \
    vim \
    net-tools \
    apache2-utils \
    gettext-base \
    # For privilege dropping in entrypoint
    sudo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create application user and groups
# Note: www-data and redis users already exist from nginx and redis-server packages
RUN groupadd -r -g 1000 thumbor && \
    useradd -r -u 1000 -g thumbor -G www-data,redis -m -d /home/thumbor -s /bin/bash thumbor && \
    # Add www-data user to thumbor group for shared access \
    usermod -a -G thumbor www-data && \
    # Add redis user to thumbor group for shared access
    usermod -a -G thumbor redis

# Install su-exec for privilege dropping (smaller than gosu)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && cd /tmp \
    && wget -O su-exec.tar.gz https://github.com/ncopa/su-exec/archive/v0.2.tar.gz \
    && tar xzf su-exec.tar.gz \
    && cd su-exec-0.2 \
    && make \
    && cp su-exec /usr/local/bin/ \
    && cd / \
    && rm -rf /tmp/su-exec* \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip
RUN python3.11 -m pip install --upgrade pip setuptools wheel

# Install Python packages
COPY requirements.txt /tmp/requirements.txt
RUN python3.11 -m pip install --no-cache-dir --ignore-installed -r /tmp/requirements.txt

# Create application directories with proper ownership
RUN mkdir -p /app/thumbor \
    && mkdir -p /app/logs \
    && mkdir -p /data/thumbor/storage \
    && mkdir -p /data/thumbor/result_storage \
    && mkdir -p /data/thumbor/cache \
    && mkdir -p /var/cache/nginx \
    && mkdir -p /var/log/supervisor \
    && mkdir -p /run/nginx \
    && mkdir -p /run/supervisor \
    && mkdir -p /data/redis \
    && mkdir -p /var/log/nginx \
    && mkdir -p /var/lib/nginx/body \
    && mkdir -p /var/lib/nginx/proxy \
    && mkdir -p /var/lib/nginx/fastcgi \
    && mkdir -p /var/lib/nginx/uwsgi \
    && mkdir -p /var/lib/nginx/scgi \
    && chown -R thumbor:thumbor /app \
    && chown -R thumbor:thumbor /data/thumbor \
    && chown -R www-data:www-data /var/cache/nginx \
    && chown -R www-data:www-data /run/nginx \
    && chown -R thumbor:thumbor /run/supervisor \
    && chown -R www-data:thumbor /var/log/nginx \
    && chown -R www-data:thumbor /var/lib/nginx \
    && chown -R redis:redis /data/redis \
    && chown -R thumbor:thumbor /var/log/supervisor \
    && chmod 775 /app/logs \
    && chmod 775 /data/thumbor/storage \
    && chmod 775 /data/thumbor/result_storage \
    && chmod 775 /data/thumbor/cache \
    && chmod 775 /var/cache/nginx \
    && chmod 775 /var/log/nginx \
    && chmod 775 /var/lib/nginx \
    && chmod 775 /run/supervisor

# Set default environment variables for nginx templating
ARG NGINX_LISTEN_PORT=80
ARG THUMBOR_PROXY_CACHE_SIZE=100g
ARG THUMBOR_PROXY_CACHE_MEMORY_SIZE=1024m
ARG THUMBOR_PROXY_CACHE_INACTIVE=512m
ARG THUMBOR_PROXY_CACHE_DURATION=1m

ENV NGINX_LISTEN_PORT=${NGINX_LISTEN_PORT}
ENV THUMBOR_PROXY_CACHE_SIZE=${THUMBOR_PROXY_CACHE_SIZE}
ENV THUMBOR_PROXY_CACHE_MEMORY_SIZE=${THUMBOR_PROXY_CACHE_MEMORY_SIZE}
ENV THUMBOR_PROXY_CACHE_INACTIVE=${THUMBOR_PROXY_CACHE_INACTIVE}
ENV THUMBOR_PROXY_CACHE_DURATION=${THUMBOR_PROXY_CACHE_DURATION}

# Copy configuration templates and files
COPY nginx-cache.conf.template /tmp/nginx-cache.conf.template
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY thumbor.conf /app/thumbor/thumbor.conf
COPY startup.sh /app/startup.sh
COPY entrypoint.sh /app/entrypoint.sh
COPY redis_admin.py /app/redis_admin.py
COPY setup_redis_admin_auth.sh /app/setup_redis_admin_auth.sh

# Process nginx template at build time
RUN envsubst '${NGINX_LISTEN_PORT} ${THUMBOR_PROXY_CACHE_SIZE} ${THUMBOR_PROXY_CACHE_MEMORY_SIZE} ${THUMBOR_PROXY_CACHE_INACTIVE} ${THUMBOR_PROXY_CACHE_DURATION}' \
    < /tmp/nginx-cache.conf.template \
    > /etc/nginx/nginx.conf \
    && chown www-data:www-data /etc/nginx/nginx.conf \
    && chmod 644 /etc/nginx/nginx.conf
# Keep template for runtime regeneration if needed (e.g., Azure PORT changes)

# Make scripts executable and set proper ownership
RUN chmod +x /app/startup.sh /app/entrypoint.sh /app/setup_redis_admin_auth.sh \
    && chown thumbor:thumbor /app/*.sh /app/*.py \
    && chown thumbor:thumbor /app/thumbor/thumbor.conf

# Configure Redis for container environment
RUN sed -i 's/^bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf \
    && sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf \
    && sed -i 's/^# maxmemory <bytes>/maxmemory 256mb/' /etc/redis/redis.conf \
    && sed -i 's/^# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf \
    && sed -i 's/^dir \/var\/lib\/redis/dir \/data\/redis/' /etc/redis/redis.conf \
    && sed -i 's/^daemonize yes/daemonize no/' /etc/redis/redis.conf

# Redis data directory already created and owned above

# Set working directory
WORKDIR /app

# Azure Web App uses PORT environment variable, default to 80
ENV PORT=80

# Expose port (Azure will override this with PORT env var)
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:${PORT}/healthcheck || exit 1

# Note: We run as root to allow supervisord to switch users
# Individual services run as non-root users via supervisord config

# Start services via entrypoint script
ENTRYPOINT ["/app/entrypoint.sh"]
