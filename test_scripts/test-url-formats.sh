#!/bin/bash
# Test script to verify both --url formats work

TEST_URL="https://media.mywebsitename.com/cdn/path/to/image/001-100x100.jpg"

echo "Testing URL argument formats..."
echo ""

# Test format 1: --url "value" (space-separated)
echo "Test 1: Space-separated format (--url \"value\")"
echo "----------------------------------------"
./build.sh --url "$TEST_URL" 2>&1 | head -10
echo ""

# Test format 2: --url="value" (equals-separated)
echo "Test 2: Equals-separated format (--url=\"value\")"
echo "----------------------------------------"
./build.sh --url="$TEST_URL" 2>&1 | head -10
echo ""

# Test format 3: With --test flag (space-separated)
echo "Test 3: With --test flag (space-separated)"
echo "----------------------------------------"
echo "Command: ./build.sh --test --url \"$TEST_URL\""
echo "This should work correctly and start processing..."
echo ""

# Test format 4: With --test flag (equals-separated)
echo "Test 4: With --test flag (equals-separated)"
echo "----------------------------------------"
echo "Command: ./build.sh --test --url=\"$TEST_URL\""
echo "This should also work correctly and start processing..."
echo ""

echo "Both formats are now supported!"
echo "You can use either:"
echo "  ./build.sh --test --url \"$TEST_URL\""
echo "  ./build.sh --test --url=\"$TEST_URL\""
