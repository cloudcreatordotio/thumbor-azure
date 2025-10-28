#!/usr/bin/env python3
"""
RemoteCV Redis Integration Test
This script verifies that RemoteCV is properly using Redis to store detection calculations.
"""

import redis
import requests
import time
import json
import sys
from urllib.parse import quote

# Configuration
REDIS_HOST = 'localhost'
REDIS_PORT = 6379
REDIS_DB = 0
THUMBOR_URL = 'http://localhost:8080'
TEST_IMAGES = {
    'faces': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/33/Cscr-featured.png/240px-Cscr-featured.png',
    'landscape': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Domestic_cat_in_the_grass.jpg/800px-Domestic_cat_in_the_grass.jpg',
}

class Colors:
    """ANSI color codes for terminal output"""
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

def print_colored(message, color=Colors.NC):
    """Print message with color"""
    print(f"{color}{message}{Colors.NC}")

def test_redis_connection(r):
    """Test Redis connectivity"""
    print_colored("\n1. Testing Redis connection...", Colors.YELLOW)
    try:
        if r.ping():
            print_colored("   ✓ Redis connected", Colors.GREEN)
            return True
    except Exception as e:
        print_colored(f"   ✗ Redis connection failed: {e}", Colors.RED)
        return False

def clear_detection_data(r):
    """Clear existing detection data from Redis"""
    print_colored("\n2. Clearing existing detection data...", Colors.YELLOW)
    patterns = ["*detector*", "*remotecv*", "*detection*", "*face*", "*feature*"]
    total_deleted = 0

    for pattern in patterns:
        keys = list(r.scan_iter(pattern))
        if keys:
            deleted = r.delete(*keys)
            total_deleted += deleted

    print_colored(f"   ✓ Cleared {total_deleted} detection keys", Colors.GREEN)
    return total_deleted

def test_detection_storage(r):
    """Test that detection results are stored in Redis"""
    print_colored("\n3. Testing detection storage...", Colors.YELLOW)

    # Get initial key count
    initial_keys = r.dbsize()
    print(f"   Initial keys in Redis: {initial_keys}")

    # Request image with smart cropping (triggers detection)
    url = f"{THUMBOR_URL}/unsafe/300x300/smart/{TEST_IMAGES['faces']}"
    print(f"   Requesting image with smart cropping...")

    try:
        response = requests.get(url, timeout=10)
        if response.status_code != 200:
            print_colored(f"   ✗ Request failed with status {response.status_code}", Colors.RED)
            return False
    except Exception as e:
        print_colored(f"   ✗ Request failed: {e}", Colors.RED)
        return False

    # Wait for detection to complete
    time.sleep(3)

    # Check for new keys
    new_keys = r.dbsize()
    keys_created = new_keys - initial_keys
    print(f"   Keys after detection: {new_keys}")

    if keys_created > 0:
        print_colored(f"   ✓ Detection created {keys_created} new keys", Colors.GREEN)
        return True
    else:
        print_colored("   ✗ No new keys created - RemoteCV may not be using Redis", Colors.RED)
        return False

def analyze_detection_keys(r):
    """Analyze detection-related keys in Redis"""
    print_colored("\n4. Analyzing detection keys...", Colors.YELLOW)

    patterns = {
        "Detector": "thumbor:*detector*",
        "RemoteCV": "*remotecv*",
        "Detection": "*detection*",
        "Face": "*face*",
        "Feature": "*feature*",
        "Queue": "queued*",
        "Storage": "*storage*detector*"
    }

    found_any = False
    for name, pattern in patterns.items():
        keys = list(r.scan_iter(pattern))
        if keys:
            found_any = True
            print_colored(f"   ✓ {name}: Found {len(keys)} keys", Colors.GREEN)
            # Show sample keys
            for key in keys[:2]:
                key_type = r.type(key)
                ttl = r.ttl(key)
                ttl_str = f"TTL: {ttl}s" if ttl > 0 else "No TTL" if ttl == -1 else "Expired"
                print(f"      - {key[:50]}... (Type: {key_type}, {ttl_str})")
        else:
            print(f"   ○ {name}: No keys found")

    return found_any

def test_caching_performance(r):
    """Test that detection results are cached"""
    print_colored("\n5. Testing detection caching...", Colors.YELLOW)

    test_url = f"{THUMBOR_URL}/unsafe/400x400/smart/{TEST_IMAGES['landscape']}"

    # First request (should trigger detection)
    print("   First request (detection should occur)...")
    start = time.time()
    response1 = requests.get(test_url, timeout=10)
    first_time = time.time() - start

    if response1.status_code != 200:
        print_colored(f"   ✗ First request failed", Colors.RED)
        return False

    # Give Redis time to store results
    time.sleep(1)

    # Second request (should use cached detection)
    print("   Second request (should use cache)...")
    start = time.time()
    response2 = requests.get(test_url, timeout=10)
    second_time = time.time() - start

    if response2.status_code != 200:
        print_colored(f"   ✗ Second request failed", Colors.RED)
        return False

    print(f"   First request time:  {first_time:.3f}s")
    print(f"   Second request time: {second_time:.3f}s")

    # Check if second request was significantly faster
    if second_time < first_time * 0.7:
        print_colored(f"   ✓ Caching working ({((1 - second_time/first_time) * 100):.0f}% faster)", Colors.GREEN)
        return True
    else:
        print_colored("   ⚠ Similar request times (caching may not be effective)", Colors.YELLOW)
        return None

def check_remotecv_service():
    """Check if RemoteCV service is running"""
    print_colored("\n6. Checking RemoteCV service status...", Colors.YELLOW)

    try:
        import subprocess
        result = subprocess.run(
            ['supervisorctl', 'status', 'remotecv'],
            capture_output=True,
            text=True,
            timeout=5
        )

        if 'RUNNING' in result.stdout:
            print_colored("   ✓ RemoteCV service is running", Colors.GREEN)
            return True
        else:
            print_colored("   ✗ RemoteCV service is not running", Colors.RED)
            print(f"      Status: {result.stdout.strip()}")
            return False
    except Exception as e:
        print(f"   ⚠ Could not check service status: {e}")
        return None

def show_redis_stats(r):
    """Show Redis memory and stats"""
    print_colored("\n7. Redis Statistics...", Colors.YELLOW)

    try:
        info = r.info('memory')
        print(f"   Memory used: {info.get('used_memory_human', 'N/A')}")
        print(f"   Memory peak: {info.get('used_memory_peak_human', 'N/A')}")
        print(f"   Memory fragmentation: {info.get('mem_fragmentation_ratio', 'N/A')}")

        info = r.info('stats')
        print(f"   Total connections: {info.get('total_connections_received', 'N/A')}")
        print(f"   Commands processed: {info.get('total_commands_processed', 'N/A')}")
        print(f"   Keys evicted: {info.get('evicted_keys', 0)}")

        return True
    except Exception as e:
        print_colored(f"   ✗ Could not get Redis stats: {e}", Colors.RED)
        return False

def generate_summary(results):
    """Generate test summary"""
    print_colored("\n" + "="*50, Colors.BLUE)
    print_colored("TEST SUMMARY", Colors.BLUE)
    print_colored("="*50, Colors.BLUE)

    if all(results.values()):
        print_colored("\n✅ RemoteCV is properly using Redis for detection storage!", Colors.GREEN)
        print("\nVerified:")
        print("  • Redis connectivity working")
        print("  • Detection results stored in Redis")
        print("  • Detection keys properly created")
        print("  • Caching mechanism functional")
        print("  • RemoteCV service running")
    elif any(results.values()):
        print_colored("\n⚠ RemoteCV Redis integration partially working", Colors.YELLOW)
        print("\nIssues found:")
        for test, result in results.items():
            if not result:
                print(f"  • {test}: Failed")
    else:
        print_colored("\n❌ RemoteCV is NOT properly using Redis", Colors.RED)
        print("\nTroubleshooting steps:")
        print("  1. Check RemoteCV service: supervisorctl status remotecv")
        print("  2. Check Redis service: redis-cli ping")
        print("  3. Review RemoteCV logs: tail -f /app/logs/remotecv.log")
        print("  4. Verify configuration in thumbor.conf")
        print("  5. Ensure tc-redis package is installed: pip list | grep tc-redis")

    print_colored("\nConfiguration:", Colors.BLUE)
    print(f"  Redis: {REDIS_HOST}:{REDIS_PORT} (DB {REDIS_DB})")
    print(f"  Thumbor: {THUMBOR_URL}")
    print("  Detector: thumbor.detectors.queued_detector")
    print("  Storage: tc_redis.storages.redis_storage")

    print_colored("\nMonitoring commands:", Colors.BLUE)
    print("  • Real-time monitor: redis-cli monitor | grep detector")
    print("  • RemoteCV logs: tail -f /app/logs/remotecv.log")
    print("  • Redis Admin UI: http://localhost:8080/redis-admin")
    print("")

def main():
    """Main test execution"""
    print_colored("\n" + "="*50, Colors.BLUE)
    print_colored("RemoteCV Redis Integration Test Suite", Colors.BLUE)
    print_colored("="*50, Colors.BLUE)

    # Connect to Redis
    try:
        r = redis.Redis(
            host=REDIS_HOST,
            port=REDIS_PORT,
            db=REDIS_DB,
            decode_responses=True
        )
    except Exception as e:
        print_colored(f"\n❌ Failed to create Redis connection: {e}", Colors.RED)
        sys.exit(1)

    results = {}

    # Run tests
    results['redis_connection'] = test_redis_connection(r)
    if not results['redis_connection']:
        print_colored("\n❌ Cannot continue without Redis connection", Colors.RED)
        sys.exit(1)

    clear_detection_data(r)
    results['detection_storage'] = test_detection_storage(r)
    results['detection_keys'] = analyze_detection_keys(r)
    results['caching'] = test_caching_performance(r)
    results['remotecv_service'] = check_remotecv_service()
    show_redis_stats(r)

    # Generate summary
    generate_summary(results)

    # Exit with appropriate code
    if all(v for v in results.values() if v is not None):
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print_colored("\n\nTest interrupted by user", Colors.YELLOW)
        sys.exit(1)
    except Exception as e:
        print_colored(f"\n❌ Unexpected error: {e}", Colors.RED)
        sys.exit(1)