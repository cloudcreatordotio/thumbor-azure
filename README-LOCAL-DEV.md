# Local Development with Docker Compose

This directory contains a Docker Compose configuration for local development and testing of the Thumbor Azure container.

## Quick Start

### 1. Build and Run

```bash
# Build the image
docker-compose build

# Start the service
docker-compose up

# Or run in background
docker-compose up -d

# View logs
docker-compose logs -f
```

### 2. Access Services

The services will be available at:
- **Main endpoint**: `http://localhost:8080`
- **Health check**: `http://localhost:8080/healthcheck`
- **Nginx status**: `http://localhost:8080/nginx-status` (only accessible from localhost)
- **Redis Admin**: `http://localhost:8080/redis-admin` (Web-based Redis management interface)

### 3. Test Image Processing

```bash
# Using unsafe URL (for development only)
curl "http://localhost:8080/unsafe/300x200/smart/https://via.placeholder.com/600x400"

# Download to file
curl "http://localhost:8080/unsafe/300x200/smart/https://via.placeholder.com/600x400" -o test-image.jpg

# Test with filters
curl "http://localhost:8080/unsafe/filters:grayscale()/https://via.placeholder.com/600x400"
```

## Configuration

### Environment Variables

Create a `.env` file from the template:

```bash
cp .env.local .env
# Edit .env with your preferences
```

Key variables you might want to change:

| Variable | Default | Description |
|----------|---------|-------------|
| `THUMBOR_LISTEN_PORT` | 8080 | Port to expose Thumbor on |
| `ALLOW_UNSAFE_URL` | True | Allow unsigned URLs (dev only!) |
| `THUMBOR_NUM_PROCESSES` | 4 | Number of Thumbor worker processes |
| `THUMBOR_PROXY_CACHE_SIZE` | 10g | Maximum cache size |
| `LOG_LEVEL` | DEBUG | Logging verbosity |

### Extra Hosts

The `docker-compose.yml` includes `extra_hosts` entries from your original configuration. These map domain names to internal IP addresses. Update these as needed for your local environment.

## Development Workflow

### Rebuilding After Changes

```bash
# Rebuild the image
docker-compose build

# Recreate containers
docker-compose up -d --force-recreate
```

### Viewing Logs

```bash
# All logs
docker-compose logs -f

# Specific service logs (all services run in one container)
docker-compose logs -f thumbor

# View supervisor logs inside container
docker-compose exec thumbor tail -f /app/logs/supervisord.log

# View Thumbor worker logs
docker-compose exec thumbor tail -f /app/logs/thumbor-1.log

# View Nginx logs
docker-compose exec thumbor tail -f /app/logs/nginx.log

# View Redis logs
docker-compose exec thumbor tail -f /app/logs/redis.log
```

### Accessing the Container

```bash
# Shell access
docker-compose exec thumbor /bin/bash

# Check running processes
docker-compose exec thumbor supervisorctl status

# Restart a specific service
docker-compose exec thumbor supervisorctl restart thumbor:thumbor_1
docker-compose exec thumbor supervisorctl restart nginx
docker-compose exec thumbor supervisorctl restart redis
```

## Redis Management

### Web-Based Redis Admin Interface

The container includes a built-in web-based Redis administration tool:

1. **Access the interface**: Open `http://localhost:8080/redis-admin` in your browser

2. **Features available**:
   - **Dashboard**: Monitor Redis statistics in real-time
   - **Key Browser**: Search and view Redis keys using patterns
   - **Command Executor**: Run Redis commands directly from the web
   - **Key Editor**: Add/edit keys with support for JSON objects
   - **Danger Zone**: Flush databases (use carefully in development)

3. **View Redis Admin logs**:
   ```bash
   docker-compose exec thumbor tail -f /app/logs/redis-admin.log
   ```

### Redis CLI Access

For direct Redis access via command line:

```bash
# Access Redis CLI inside container
docker-compose exec thumbor redis-cli

# Run Redis commands directly
docker-compose exec thumbor redis-cli ping
docker-compose exec thumbor redis-cli info memory
docker-compose exec thumbor redis-cli keys "*"

# Monitor Redis in real-time
docker-compose exec thumbor redis-cli monitor

# Check Redis configuration
docker-compose exec thumbor redis-cli config get "*"
```

### Common Redis Debugging Commands

```bash
# View all Thumbor-related keys
docker-compose exec thumbor redis-cli keys "thumbor:*"

# Check memory usage
docker-compose exec thumbor redis-cli info memory

# Get slow log
docker-compose exec thumbor redis-cli slowlog get 10

# Clear all data (development only!)
docker-compose exec thumbor redis-cli flushdb

# Check Redis persistence
docker-compose exec thumbor ls -la /data/redis/
```

## Persistent Data

The following volumes are created for persistent storage:

- `thumbor-storage` - Image storage
- `thumbor-cache` - Nginx cache
- `thumbor-logs` - Application logs
- `redis-data` - Redis data

### Managing Volumes

```bash
# View volumes
docker volume ls | grep thumbor

# Clear cache (while stopped)
docker-compose down
docker volume rm build_thumbor-cache

# Clear all data
docker-compose down -v

# Backup a volume
docker run --rm -v build_thumbor-storage:/data -v $(pwd):/backup ubuntu tar czf /backup/thumbor-storage-backup.tar.gz -C /data .

# Restore a volume
docker run --rm -v build_thumbor-storage:/data -v $(pwd):/backup ubuntu tar xzf /backup/thumbor-storage-backup.tar.gz -C /data
```

## Testing Different Configurations

### Test with Different Worker Counts

```bash
THUMBOR_NUM_PROCESSES=2 docker-compose up
```

### Test with Different Cache Sizes

```bash
THUMBOR_PROXY_CACHE_SIZE=5g docker-compose up
```

### Test with Signed URLs

1. Update `.env`:
   ```
   ALLOW_UNSAFE_URL=False
   SECURITY_KEY=my-secret-key-12345
   ```

2. Generate signed URL (Python example):
   ```python
   import hashlib
   import base64

   def generate_url(key, path):
       signature = base64.urlsafe_b64encode(
           hashlib.md5((key + path).encode()).digest()
       ).decode().rstrip('=')
       return f"http://localhost:8080/{signature}/{path}"

   url = generate_url("my-secret-key-12345", "300x200/smart/https://via.placeholder.com/600x400")
   print(url)
   ```

## Performance Testing

### Using Apache Bench

```bash
# Test 1000 requests with 10 concurrent
ab -n 1000 -c 10 "http://localhost:8080/unsafe/300x200/smart/https://via.placeholder.com/600x400"
```

### Using wrk

```bash
# Test for 30 seconds with 10 connections
wrk -t4 -c10 -d30s "http://localhost:8080/unsafe/300x200/smart/https://via.placeholder.com/600x400"
```

## Debugging

### Check Service Status

```bash
docker-compose exec thumbor supervisorctl status
```

Expected output:
```
redis                            RUNNING   pid 8, uptime 0:01:23
thumbor:thumbor_1                RUNNING   pid 9, uptime 0:01:23
thumbor:thumbor_2                RUNNING   pid 10, uptime 0:01:23
thumbor:thumbor_3                RUNNING   pid 11, uptime 0:01:23
thumbor:thumbor_4                RUNNING   pid 12, uptime 0:01:23
remotecv                         RUNNING   pid 13, uptime 0:01:23
nginx                            RUNNING   pid 14, uptime 0:01:23
```

### Check Redis Connectivity

```bash
docker-compose exec thumbor redis-cli ping
# Should return: PONG
```

### Check Nginx Configuration

```bash
docker-compose exec thumbor nginx -t
```

### Check Thumbor Configuration

```bash
docker-compose exec thumbor python3.11 -c "import sys; sys.path.insert(0, '/app'); from thumbor.conf import config; print(config.SECURITY_KEY)"
```

## Troubleshooting

### Port Already in Use

If port 8080 is already in use, change it in `.env`:
```
THUMBOR_LISTEN_PORT=8888
```

### Container Won't Start

```bash
# View detailed logs
docker-compose logs

# Check container status
docker-compose ps

# Remove and recreate
docker-compose down
docker-compose up --force-recreate
```

### Images Not Processing

1. Check Thumbor worker logs:
   ```bash
   docker-compose exec thumbor tail -f /app/logs/thumbor-*.log
   ```

2. Verify ALLOWED_SOURCES in `thumbor.conf` includes your source domain

3. Check if the source URL is accessible:
   ```bash
   docker-compose exec thumbor curl -I "https://via.placeholder.com/600x400"
   ```

### Cache Issues

Clear the cache:
```bash
docker-compose exec thumbor find /var/cache/nginx -type f -delete
docker-compose exec thumbor supervisorctl restart nginx
```

## Production vs Development

### Key Differences

| Setting | Development | Production (Azure) |
|---------|-------------|-------------------|
| `ALLOW_UNSAFE_URL` | True | False |
| `SECURITY_KEY` | Simple | Strong random key |
| `LOG_LEVEL` | DEBUG | INFO or WARNING |
| Port | 8080 | Azure provides via PORT env var |
| Cache Size | 10g | 100g+ |
| Memory Limits | 4G | Based on Azure plan |

### Before Deploying to Azure

1. Test with signed URLs:
   ```bash
   ALLOW_UNSAFE_URL=False docker-compose up
   ```

2. Test with production-like settings:
   ```bash
   LOG_LEVEL=WARNING THUMBOR_PROXY_CACHE_SIZE=100g docker-compose up
   ```

3. Run performance tests to ensure adequate worker count

## Cleaning Up

```bash
# Stop services
docker-compose down

# Stop and remove volumes
docker-compose down -v

# Remove images
docker rmi thumbor-azure:latest

# Remove all (nuclear option)
docker-compose down -v --rmi all
```

## Next Steps

Once you've tested locally, you can:

1. Build and push to Azure Container Registry:
   ```bash
   ./build.sh --push --registry <your-acr-name>
   ```

2. Deploy to Azure Web App (see main [README.md](README.md))

## Support

For issues specific to:
- Local development: Check logs and this guide
- Azure deployment: See main [README.md](README.md)
- Thumbor features: https://thumbor.readthedocs.io