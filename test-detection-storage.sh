#!/bin/bash

# Test script for verifying RemoteCV Redis detection storage
# This tests that face/feature detection results are cached in Redis

echo "======================================="
echo "RemoteCV Redis Detection Storage Test"
echo "======================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Container name
CONTAINER="thumbor-dev"

# Function to check if container is running
check_container() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        echo -e "${RED}✗ Container ${CONTAINER} is not running${NC}"
        echo "Please run: docker compose up -d"
        exit 1
    fi
    echo -e "${GREEN}✓ Container ${CONTAINER} is running${NC}"
}

# Function to check service status
check_service() {
    local service=$1
    local status=$(docker exec $CONTAINER supervisorctl status | grep "$service" | awk '{print $2}')

    if [ "$status" = "RUNNING" ]; then
        echo -e "${GREEN}✓ $service is running${NC}"
        return 0
    else
        echo -e "${RED}✗ $service is not running (status: $status)${NC}"
        return 1
    fi
}

# Function to check Redis keys
check_redis_keys() {
    local key_count=$(docker exec $CONTAINER redis-cli DBSIZE | awk '{print $2}')
    local keys=$(docker exec $CONTAINER redis-cli KEYS "*" | sort)

    echo -e "${YELLOW}Redis has $key_count keys:${NC}"
    echo "$keys" | while IFS= read -r key; do
        echo "  - $key"
    done

    # Check for specific key patterns
    if echo "$keys" | grep -q "resque:worker"; then
        echo -e "${GREEN}✓ RemoteCV worker registered in Redis${NC}"
    else
        echo -e "${RED}✗ RemoteCV worker not registered${NC}"
    fi

    if echo "$keys" | grep -q "thumbor:detectors\|thumbor:remotecv"; then
        echo -e "${GREEN}✓ Detection results found in Redis${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ No detection results in Redis yet${NC}"
        return 1
    fi
}

# Function to test detection with a real image
test_detection() {
    echo -e "\n${YELLOW}Testing detection with images...${NC}"

    # Test URLs with faces for detection
    local test_urls=(
        "https://upload.wikimedia.org/wikipedia/commons/thumb/3/31/Neelix_Portrait_2017.jpg/440px-Neelix_Portrait_2017.jpg"
        "https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Lenna_%28test_image%29.png/512px-Lenna_%28test_image%29.png"
    )

    for url in "${test_urls[@]}"; do
        echo -e "\nTesting with image: ${url##*/}"

        # Make request with smart cropping (triggers detection)
        local response=$(docker exec $CONTAINER curl -s -o /tmp/test_detection.jpg -w "%{http_code}" \
            "http://localhost:80/unsafe/smart/300x300/${url}")

        if [ "$response" = "200" ]; then
            echo -e "${GREEN}✓ Successfully processed image (HTTP $response)${NC}"

            # Give RemoteCV time to process and store results
            sleep 2

            # Check if detection was queued
            local queue_len=$(docker exec $CONTAINER redis-cli LLEN resque:queue:Detect)
            echo "  Queue length: $queue_len"

            # Check for new keys
            local new_keys=$(docker exec $CONTAINER redis-cli KEYS "*" | grep -E "thumbor:detectors|thumbor:remotecv|detect" | head -5)
            if [ ! -z "$new_keys" ]; then
                echo -e "${GREEN}✓ Detection keys found:${NC}"
                echo "$new_keys" | while IFS= read -r key; do
                    echo "    - $key"
                done
            fi
        else
            echo -e "${RED}✗ Failed to process image (HTTP $response)${NC}"
        fi
    done
}

# Function to monitor Redis in real-time
monitor_redis() {
    echo -e "\n${YELLOW}Monitoring Redis for 10 seconds...${NC}"
    docker exec $CONTAINER timeout 10 redis-cli MONITOR 2>/dev/null | grep -E "SADD|SET|HSET|LPUSH|RPUSH" | head -20
}

# Main test execution
echo "1. Checking container status..."
check_container

echo -e "\n2. Checking service status..."
check_service "thumbor-stack:redis"
check_service "thumbor-stack:thumbor_1"
check_service "thumbor-stack:remotecv"

echo -e "\n3. Initial Redis state..."
check_redis_keys

echo -e "\n4. Testing detection pipeline..."
test_detection

echo -e "\n5. Final Redis state..."
check_redis_keys

echo -e "\n6. Redis activity monitor..."
monitor_redis

echo -e "\n======================================="
echo "Test Summary:"
echo "======================================="

# Final check
final_keys=$(docker exec $CONTAINER redis-cli KEYS "*" | wc -l)
detection_keys=$(docker exec $CONTAINER redis-cli KEYS "*" | grep -E "thumbor:detectors|thumbor:remotecv|detect" | wc -l)

if [ $detection_keys -gt 0 ]; then
    echo -e "${GREEN}✓ SUCCESS: Detection results are being stored in Redis${NC}"
    echo -e "  Total keys: $final_keys"
    echo -e "  Detection keys: $detection_keys"
else
    echo -e "${RED}✗ FAILURE: No detection results found in Redis${NC}"
    echo -e "  Total keys: $final_keys"
    echo -e "\nPossible issues:"
    echo -e "  - RemoteCV may not be receiving detection requests"
    echo -e "  - Redis storage configuration may be incorrect"
    echo -e "  - Detection queue may not be properly configured"
    echo -e "\nCheck logs:"
    echo -e "  docker exec $CONTAINER tail -50 /app/logs/remotecv.log"
    echo -e "  docker exec $CONTAINER tail -50 /app/logs/thumbor-1.log"
fi