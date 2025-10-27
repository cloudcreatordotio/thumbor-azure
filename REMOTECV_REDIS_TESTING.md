# RemoteCV Redis Integration Testing Guide

## Overview

RemoteCV is the computer vision component that performs face and feature detection for Thumbor's smart cropping functionality. This guide provides comprehensive instructions for testing and verifying that RemoteCV is properly using Redis to store its detection calculations.

## Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Thumbor    │────▶│    Redis     │◀────│   RemoteCV   │
│  (Detection  │     │  (Queue &    │     │   (Worker)   │
│   Request)   │     │   Storage)   │     │              │
└──────────────┘     └──────────────┘     └──────────────┘
        │                    │                     │
        └────────────────────┴─────────────────────┘
                    Detection Results
```

## Configuration Summary

### RemoteCV Configuration
- **Command**: `python3.11 -m remotecv.worker --host=localhost --port=6379 --database=0`
- **Redis Connection**: localhost:6379, Database 0
- **Loader**: remotecv.http_loader
- **Log Files**:
  - `/app/logs/remotecv.log`
  - `/app/logs/remotecv-error.log`

### Thumbor Configuration
- **Detector**: `thumbor.detectors.queued_detector.queued_complete_detector`
- **Detector Storage**: `tc_redis.storages.redis_storage` (via mixed_storage)
- **Queue Redis**: localhost:6379, Database 0
- **Face Cascade**: `/usr/share/opencv4/haarcascades/haarcascade_frontalface_alt.xml`

## Quick Test

### 1. Using the Bash Test Script

```bash
# Make the script executable
chmod +x test-remotecv-redis.sh

# Run the test suite
./test-remotecv-redis.sh

# Or specify a custom container name
./test-remotecv-redis.sh my-container-name
```

### 2. Manual Quick Test

```bash
# 1. Clear Redis detection data
docker-compose exec thumbor redis-cli FLUSHDB

# 2. Check initial key count
docker-compose exec thumbor redis-cli DBSIZE

# 3. Request an image with smart cropping (triggers detection)
curl "http://localhost:8080/unsafe/300x300/smart/https://upload.wikimedia.org/wikipedia/commons/thumb/3/33/Cscr-featured.png/240px-Cscr-featured.png"

# 4. Check new key count
docker-compose exec thumbor redis-cli DBSIZE

# 5. Look for detection keys
docker-compose exec thumbor redis-cli --scan --pattern "*detector*"
```

## Monitoring Methods

### 1. Real-Time Redis Monitoring

Monitor all Redis commands in real-time:

```bash
# Watch all Redis commands
docker-compose exec thumbor redis-cli monitor

# Filter for detection-related commands only
docker-compose exec thumbor redis-cli monitor | grep -E "(detector|remotecv|face|feature)"
```

### 2. Redis Web Admin Interface

Access the built-in Redis Admin interface:

1. Open browser: `http://localhost:8080/redis-admin`
2. Navigate to "Key Browser"
3. Search for patterns:
   - `*detector*` - Detection queue and results
   - `*remotecv*` - RemoteCV specific keys
   - `*face*` - Face detection results
   - `*feature*` - Feature detection results

### 3. Log File Monitoring

Monitor RemoteCV activity through logs:

```bash
# Watch RemoteCV logs in real-time
docker-compose exec thumbor tail -f /app/logs/remotecv.log

# Check for errors
docker-compose exec thumbor tail -f /app/logs/remotecv-error.log

# Search for Redis-related log entries
docker-compose exec thumbor grep -i redis /app/logs/remotecv.log
```

### 4. Supervisord Status Check

Verify all services are running:

```bash
# Check all services
docker-compose exec thumbor supervisorctl status

# Check RemoteCV specifically
docker-compose exec thumbor supervisorctl status remotecv

# Restart RemoteCV if needed
docker-compose exec thumbor supervisorctl restart remotecv
```

## Detection Key Patterns

RemoteCV and Thumbor use specific key patterns in Redis:

### Common Key Patterns

| Pattern | Description | Example |
|---------|-------------|---------|
| `thumbor:detector:*` | Detection results | `thumbor:detector:result:{hash}` |
| `thumbor:queued:*` | Queued detection tasks | `thumbor:queued:task:{id}` |
| `remotecv:*` | RemoteCV specific data | `remotecv:detection:{hash}` |
| `*:storage:detector:*` | Detector storage keys | `mixed:storage:detector:{hash}` |

### Inspecting Detection Keys

```bash
# List all detection-related keys
docker-compose exec thumbor redis-cli --scan --pattern "thumbor:*detector*"

# Get the type of a key
docker-compose exec thumbor redis-cli TYPE "key_name"

# View contents of a string key
docker-compose exec thumbor redis-cli GET "key_name"

# View contents of a hash
docker-compose exec thumbor redis-cli HGETALL "key_name"

# Check TTL of a key
docker-compose exec thumbor redis-cli TTL "key_name"
```

## Testing Scenarios

### Test 1: Face Detection

```bash
# Image with faces
curl -o face_test.jpg "http://localhost:8080/unsafe/300x300/smart/filters:face()/https://upload.wikimedia.org/wikipedia/commons/thumb/3/33/Cscr-featured.png/240px-Cscr-featured.png"

# Check Redis for face detection data
docker-compose exec thumbor redis-cli --scan --pattern "*face*"
```

### Test 2: Feature Detection

```bash
# Image with features for smart cropping
curl -o feature_test.jpg "http://localhost:8080/unsafe/300x300/smart/https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Domestic_cat_in_the_grass.jpg/800px-Domestic_cat_in_the_grass.jpg"

# Check Redis for feature detection data
docker-compose exec thumbor redis-cli --scan --pattern "*feature*"
```

### Test 3: Detection Caching

```bash
# First request (should be slow - detection happens)
time curl -s "http://localhost:8080/unsafe/300x300/smart/https://example.com/image.jpg" > /dev/null

# Second request (should be fast - cached detection)
time curl -s "http://localhost:8080/unsafe/300x300/smart/https://example.com/image.jpg" > /dev/null
```

### Test 4: Queue Processing

```bash
# Monitor the queue in real-time
docker-compose exec thumbor redis-cli monitor | grep -i queue

# In another terminal, request multiple images
for i in {1..5}; do
    curl "http://localhost:8080/unsafe/300x300/smart/https://picsum.photos/800/600?random=$i" &
done
```

## Verification Checklist

Use this checklist to verify RemoteCV Redis integration:

- [ ] RemoteCV service is running (`supervisorctl status remotecv`)
- [ ] Redis is accessible (`redis-cli ping`)
- [ ] Detection keys appear in Redis after smart crop requests
- [ ] RemoteCV logs show detection activity
- [ ] Second request for same image is faster (cached)
- [ ] Redis memory usage increases with detection data
- [ ] Queue keys appear during detection processing
- [ ] No errors in RemoteCV error log

## Troubleshooting

### RemoteCV Not Using Redis

**Symptoms:**
- No detection keys in Redis
- Smart cropping still works but slowly
- No RemoteCV entries in Redis monitor

**Solutions:**

1. **Check RemoteCV is running:**
```bash
docker-compose exec thumbor supervisorctl status remotecv
# If not running:
docker-compose exec thumbor supervisorctl start remotecv
```

2. **Verify Redis connection:**
```bash
docker-compose exec thumbor python3.11 -c "
import redis
r = redis.Redis(host='localhost', port=6379, db=0)
print('Redis ping:', r.ping())
"
```

3. **Check configuration:**
```bash
# Verify thumbor.conf has correct settings
docker-compose exec thumbor grep -A5 "REMOTECV\|DETECTOR" /app/thumbor.conf
```

4. **Restart services:**
```bash
docker-compose exec thumbor supervisorctl restart remotecv
docker-compose exec thumbor supervisorctl restart thumbor:*
```

### Detection Keys Missing

**Symptoms:**
- RemoteCV is running but no keys in Redis
- Smart cropping works but no caching

**Solutions:**

1. **Check tc-redis is installed:**
```bash
docker-compose exec thumbor pip list | grep tc-redis
```

2. **Verify mixed storage configuration:**
```bash
docker-compose exec thumbor python3.11 -c "
from thumbor.config import Config
print('Detector Storage:', Config.MIXED_STORAGE_DETECTOR_STORAGE)
"
```

3. **Check Redis memory limit:**
```bash
docker-compose exec thumbor redis-cli CONFIG GET maxmemory
# Should be: 256mb or higher
```

### Performance Issues

**Symptoms:**
- Slow detection even with caching
- High memory usage
- Redis evicting keys

**Solutions:**

1. **Check Redis memory and eviction:**
```bash
docker-compose exec thumbor redis-cli INFO stats | grep evicted
docker-compose exec thumbor redis-cli INFO memory
```

2. **Increase Redis memory limit:**
```bash
docker-compose exec thumbor redis-cli CONFIG SET maxmemory 512mb
```

3. **Check detection queue size:**
```bash
docker-compose exec thumbor redis-cli --scan --pattern "thumbor:queued:*" | wc -l
```

## Python Test Script

Save this as `test_remotecv_redis.py`:

```python
#!/usr/bin/env python3
import redis
import requests
import time
import json
from urllib.parse import quote

# Configuration
REDIS_HOST = 'localhost'
REDIS_PORT = 6379
REDIS_DB = 0
THUMBOR_URL = 'http://localhost:8080'
TEST_IMAGE = 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/33/Cscr-featured.png/240px-Cscr-featured.png'

def test_remotecv_redis():
    """Test RemoteCV Redis integration"""

    # Connect to Redis
    r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=REDIS_DB, decode_responses=True)

    print("1. Testing Redis connection...")
    assert r.ping(), "Redis not responding"
    print("   ✓ Redis connected")

    print("\n2. Clearing detection data...")
    for key in r.scan_iter("*detector*"):
        r.delete(key)
    print("   ✓ Cleared")

    print("\n3. Initial key count...")
    initial_keys = r.dbsize()
    print(f"   Keys: {initial_keys}")

    print("\n4. Requesting image with smart detection...")
    url = f"{THUMBOR_URL}/unsafe/300x300/smart/{TEST_IMAGE}"
    response = requests.get(url)
    assert response.status_code == 200, f"Request failed: {response.status_code}"
    print("   ✓ Image processed")

    print("\n5. Checking for new keys...")
    time.sleep(2)  # Wait for detection to complete
    new_keys = r.dbsize()
    print(f"   Keys after: {new_keys}")
    print(f"   New keys created: {new_keys - initial_keys}")

    print("\n6. Looking for detection keys...")
    detection_keys = list(r.scan_iter("*detector*"))
    remotecv_keys = list(r.scan_iter("*remotecv*"))

    print(f"   Detection keys: {len(detection_keys)}")
    print(f"   RemoteCV keys: {len(remotecv_keys)}")

    if detection_keys:
        print("   Sample keys:")
        for key in detection_keys[:3]:
            key_type = r.type(key)
            ttl = r.ttl(key)
            print(f"     - {key} (type: {key_type}, ttl: {ttl})")

    print("\n7. Testing caching...")
    start = time.time()
    requests.get(url)
    first_time = time.time() - start

    start = time.time()
    requests.get(url)
    second_time = time.time() - start

    print(f"   First request: {first_time:.3f}s")
    print(f"   Second request: {second_time:.3f}s")

    if second_time < first_time * 0.5:
        print("   ✓ Caching working (second request faster)")

    print("\n✅ RemoteCV Redis integration verified!")
    return True

if __name__ == "__main__":
    try:
        test_remotecv_redis()
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        exit(1)
```

Run with:
```bash
docker-compose exec thumbor python3.11 /app/test_remotecv_redis.py
```

## Azure Testing

For Azure deployments:

```bash
# SSH into Azure Web App
az webapp ssh --name YOUR-APP-NAME --resource-group YOUR-RG

# Run the test script
./test-remotecv-redis.sh

# Or manually check
redis-cli DBSIZE
curl "http://localhost/unsafe/300x300/smart/https://example.com/image.jpg"
redis-cli --scan --pattern "*detector*"
```

## Performance Metrics

Monitor RemoteCV performance:

```bash
# Redis memory usage
docker-compose exec thumbor redis-cli INFO memory | grep used_memory_human

# Detection queue length
docker-compose exec thumbor redis-cli --scan --pattern "thumbor:queued:*" | wc -l

# Cache hit ratio (monitor for patterns)
docker-compose exec thumbor redis-cli monitor | grep "GET.*detector"

# RemoteCV processing time (check logs)
docker-compose exec thumbor grep "Processed in" /app/logs/remotecv.log | tail -10
```

## Best Practices

1. **Regular Monitoring**: Check Redis memory usage and eviction stats
2. **TTL Management**: Ensure detection results have appropriate TTLs
3. **Queue Health**: Monitor queue size to prevent backlogs
4. **Memory Limits**: Set appropriate Redis maxmemory for your workload
5. **Logging**: Keep RemoteCV logs for debugging detection issues

## Summary

RemoteCV integration with Redis provides:
- **Cached Detection Results**: Avoid reprocessing same images
- **Queue-Based Processing**: Asynchronous detection handling
- **Persistent Storage**: Detection results survive container restarts (with volumes)
- **Performance Optimization**: Faster smart cropping for repeated images

Use the provided tests and monitoring tools to ensure your RemoteCV instance is properly utilizing Redis for optimal performance.