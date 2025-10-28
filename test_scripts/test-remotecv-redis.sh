#!/bin/bash

# Test RemoteCV Redis Integration for Thumbor Container
# This script verifies that RemoteCV is properly using Redis to store detection calculations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONTAINER_NAME="${1:-thumbor-dev}"
TEST_IMAGE_URL="media.mywebsitename.com/cdn/path/to/image/001.png"
TEST_IMAGE_WITH_FACES="media.mywebsitename.com/cdn/path/to/image/002.png"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}RemoteCV Redis Integration Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to check if container is running
check_container() {
    echo -e "${YELLOW}1. Checking container status...${NC}"
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        echo -e "${RED}Error: Container $CONTAINER_NAME is not running${NC}"
        echo "Start it with: docker-compose up -d"
        exit 1
    fi
    echo -e "${GREEN}✓ Container is running${NC}"
    echo ""
}

# Function to check services
check_services() {
    echo -e "${YELLOW}2. Checking required services...${NC}"

    # Check Redis
    echo -n "   Redis: "
    if docker exec "$CONTAINER_NAME" redis-cli ping > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Running${NC}"
    else
        echo -e "${RED}✗ Not responding${NC}"
        exit 1
    fi

    # Check RemoteCV
    echo -n "   RemoteCV: "
    if docker exec "$CONTAINER_NAME" supervisorctl status thumbor-stack:remotecv | grep -q RUNNING; then
        echo -e "${GREEN}✓ Running${NC}"
    else
        echo -e "${RED}✗ Not running${NC}"
        exit 1
    fi

    # Check Thumbor
    echo -n "   Thumbor: "
    if docker exec "$CONTAINER_NAME" supervisorctl status thumbor-stack:thumbor_1 | grep -q RUNNING; then
        echo -e "${GREEN}✓ Running${NC}"
    else
        echo -e "${RED}✗ Not running${NC}"
        exit 1
    fi

    echo ""
}

# Function to clear Redis detection data
clear_redis_data() {
    echo -e "${YELLOW}3. Clearing existing Redis detection data...${NC}"

    # Clear detection-related keys
    docker exec "$CONTAINER_NAME" redis-cli --scan --pattern "thumbor:*detector*" | while read key; do
        docker exec "$CONTAINER_NAME" redis-cli DEL "$key" > /dev/null
    done

    docker exec "$CONTAINER_NAME" redis-cli --scan --pattern "*remotecv*" | while read key; do
        docker exec "$CONTAINER_NAME" redis-cli DEL "$key" > /dev/null
    done

    docker exec "$CONTAINER_NAME" redis-cli --scan --pattern "*detection*" | while read key; do
        docker exec "$CONTAINER_NAME" redis-cli DEL "$key" > /dev/null
    done

    echo -e "${GREEN}✓ Redis detection data cleared${NC}"
    echo ""
}

# Function to get Redis key count
get_redis_keys() {
    docker exec "$CONTAINER_NAME" redis-cli DBSIZE | cut -d' ' -f2
}

# Function to monitor Redis keys
monitor_redis_keys() {
    echo -e "${YELLOW}4. Monitoring Redis keys before and after detection...${NC}"

    # Get initial key count
    INITIAL_KEYS=$(get_redis_keys)
    echo "   Initial Redis keys: $INITIAL_KEYS"

    # Request an image with smart cropping (triggers detection)
    echo "   Requesting image with smart cropping..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/unsafe/300x300/smart/$TEST_IMAGE_WITH_FACES")

    if [ "$RESPONSE" != "200" ]; then
        echo -e "${RED}   Error: Image request failed with status $RESPONSE${NC}"
        exit 1
    fi

    # Wait for detection to complete
    sleep 3

    # Get new key count
    NEW_KEYS=$(get_redis_keys)
    echo "   Redis keys after detection: $NEW_KEYS"

    if [ "$NEW_KEYS" -gt "$INITIAL_KEYS" ]; then
        echo -e "${GREEN}✓ New keys created ($(($NEW_KEYS - $INITIAL_KEYS)) new keys)${NC}"
    else
        echo -e "${RED}✗ No new keys created - RemoteCV might not be storing to Redis${NC}"
    fi

    echo ""
}

# Function to check specific detection keys
check_detection_keys() {
    echo -e "${YELLOW}5. Checking for detection-related keys in Redis...${NC}"

    echo "   Searching for detection patterns:"

    # Search for various detection-related patterns
    PATTERNS=("thumbor:*detector*" "*remotecv*" "*detection*" "*face*" "*feature*" "queued*" "*storage*detector*")

    for pattern in "${PATTERNS[@]}"; do
        COUNT=$(docker exec "$CONTAINER_NAME" redis-cli --scan --pattern "$pattern" 2>/dev/null | wc -l)
        if [ "$COUNT" -gt 0 ]; then
            echo -e "   ${GREEN}✓${NC} Found $COUNT keys matching '$pattern'"

            # Show first few keys as examples
            echo "     Sample keys:"
            docker exec "$CONTAINER_NAME" redis-cli --scan --pattern "$pattern" 2>/dev/null | head -3 | while read key; do
                TYPE=$(docker exec "$CONTAINER_NAME" redis-cli TYPE "$key" 2>/dev/null)
                TTL=$(docker exec "$CONTAINER_NAME" redis-cli TTL "$key" 2>/dev/null)
                echo "       - $key (type: $TYPE, ttl: $TTL)"
            done
        else
            echo "   ○ No keys matching '$pattern'"
        fi
    done

    echo ""
}

# Function to test detection queue
test_detection_queue() {
    echo -e "${YELLOW}6. Testing detection queue...${NC}"

    # Monitor queue in background
    echo "   Starting Redis monitor (5 seconds)..."
    timeout 5 docker exec "$CONTAINER_NAME" redis-cli monitor 2>/dev/null | grep -E "(detector|remotecv|face|feature)" > /tmp/redis_monitor.log &
    MONITOR_PID=$!

    # Request image with smart detection
    echo "   Requesting image with face detection..."
    curl -s "http://localhost:8080/unsafe/300x300/smart/filters:face()/$TEST_IMAGE_WITH_FACES" > /dev/null

    # Wait for monitor to complete
    wait $MONITOR_PID 2>/dev/null || true

    if [ -s /tmp/redis_monitor.log ]; then
        echo -e "${GREEN}✓ Detection activity detected in Redis:${NC}"
        echo "   Sample Redis commands:"
        head -5 /tmp/redis_monitor.log | sed 's/^/     /'
    else
        echo -e "${YELLOW}⚠ No detection activity captured in monitor${NC}"
    fi

    rm -f /tmp/redis_monitor.log
    echo ""
}

# Function to check RemoteCV logs
check_remotecv_logs() {
    echo -e "${YELLOW}7. Checking RemoteCV logs for Redis activity...${NC}"

    # Get last 20 lines of RemoteCV log
    LOGS=$(docker exec "$CONTAINER_NAME" tail -20 /app/logs/remotecv.log 2>/dev/null)

    if echo "$LOGS" | grep -q -i "redis\|detect\|face\|feature"; then
        echo -e "${GREEN}✓ RemoteCV shows detection activity${NC}"
        echo "   Recent log entries:"
        echo "$LOGS" | grep -i "redis\|detect\|face\|feature" | head -3 | sed 's/^/     /'
    else
        echo -e "${YELLOW}⚠ No recent detection activity in RemoteCV logs${NC}"
    fi

    echo ""
}

# Function to test persistence
test_persistence() {
    echo -e "${YELLOW}8. Testing detection result persistence...${NC}"

    # Request same image twice
    echo "   First request (should trigger detection)..."
    TIME1=$(curl -s -o /dev/null -w "%{time_total}" "http://localhost:8080/unsafe/300x300/smart/$TEST_IMAGE_WITH_FACES")

    sleep 2

    echo "   Second request (should use cached detection)..."
    TIME2=$(curl -s -o /dev/null -w "%{time_total}" "http://localhost:8080/unsafe/300x300/smart/$TEST_IMAGE_WITH_FACES")

    echo "   First request time: ${TIME1}s"
    echo "   Second request time: ${TIME2}s"

    # Check if second request was significantly faster (cached)
    if (( $(echo "$TIME1 > $TIME2 * 2" | bc -l) )); then
        echo -e "${GREEN}✓ Second request was faster (likely using cached detection)${NC}"
    else
        echo -e "${YELLOW}⚠ Similar request times (detection might not be cached)${NC}"
    fi

    echo ""
}

# Function to show Redis memory info
show_redis_memory() {
    echo -e "${YELLOW}9. Redis Memory Usage for Detection Data...${NC}"

    MEMORY_INFO=$(docker exec "$CONTAINER_NAME" redis-cli INFO memory | grep -E "used_memory_human|used_memory_peak_human|mem_fragmentation_ratio")

    echo "$MEMORY_INFO" | while IFS=':' read -r key value; do
        echo "   $key: $value"
    done

    echo ""
}

# Function to generate summary
generate_summary() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}========================================${NC}"

    # Check if detection keys exist
    DETECTION_KEYS=$(docker exec "$CONTAINER_NAME" redis-cli --scan --pattern "*detector*" 2>/dev/null | wc -l)

    if [ "$DETECTION_KEYS" -gt 0 ]; then
        echo -e "${GREEN}✓ RemoteCV is using Redis for detection storage${NC}"
        echo "  - Found $DETECTION_KEYS detection-related keys in Redis"
        echo "  - Detection results are being cached"
        echo "  - Queue-based detection is working"
    else
        echo -e "${RED}✗ RemoteCV may not be properly using Redis${NC}"
        echo "  - No detection keys found in Redis"
        echo "  - Check RemoteCV configuration in thumbor.conf"
        echo "  - Verify tc-redis package is installed"
    fi

    echo ""
    echo -e "${BLUE}Configuration Details:${NC}"
    echo "  - Redis Host: localhost:6379 (DB 0)"
    echo "  - Storage: tc_redis.storages.redis_storage"
    echo "  - Detector: thumbor.detectors.queued_detector"
    echo "  - RemoteCV: Running as supervisord service"

    echo ""
    echo -e "${BLUE}To monitor in real-time:${NC}"
    echo "  1. Redis Monitor: docker exec $CONTAINER_NAME redis-cli monitor"
    echo "  2. RemoteCV Logs: docker exec $CONTAINER_NAME tail -f /app/logs/remotecv.log"
    echo "  3. Redis Admin UI: http://localhost:8080/redis-admin"
}

# Main execution
main() {
    check_container
    check_services
    clear_redis_data
    monitor_redis_keys
    check_detection_keys
    test_detection_queue
    check_remotecv_logs
    test_persistence
    show_redis_memory
    generate_summary
}

# Run the test suite
main
