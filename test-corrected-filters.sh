#!/bin/bash
# Test script to verify the corrected filter logic

echo "==============================================="
echo "Testing Corrected Filter Logic"
echo "==============================================="
echo ""

# Test 1: numBytes with quality (quality should be ignored)
echo "Test 1: numBytes with quality parameter"
echo "----------------------------------------"
echo "Command: ./build.sh --test --url=\"https://media.mywebsitename.com/cdn/path/to/image/001-100x100.jpg\" --quality=90 --numBytes=45000"
echo ""
echo "Expected behavior:"
echo "  - Quality filter should be IGNORED"
echo "  - ONLY number-of-bytes(45000) and strip_icc() filters"
echo "  - Uses fit-in mode"
echo ""
echo "Expected THUMBOR_URL:"
echo "http://localhost:8080/unsafe/fit-in/100x100/filters:number-of-bytes(45000):strip_icc()/[encoded_url]"
echo ""

# Test 2: maxBytes with quality, format, and height=0
echo "Test 2: maxBytes with height=0"
echo "-------------------------------"
echo "Command: ./build.sh --test --url=\"https://media.mywebsitename.com/cdn/path/to/image/001-100x0.jpg\" --quality=90 --format=jpeg --maxBytes=100000"
echo ""
echo "Expected behavior:"
echo "  - ALL filters should be included"
echo "  - Uses smart mode because height=0"
echo "  - Dimensions remain 100x0"
echo ""
echo "Expected THUMBOR_URL:"
echo "http://localhost:8080/unsafe/100x0/smart/filters:quality(90):format(jpeg):max_bytes(100000):strip_icc()/[encoded_url]"
echo ""

# Test 3: maxBytes with non-zero height
echo "Test 3: maxBytes with non-zero height"
echo "--------------------------------------"
echo "Command: ./build.sh --test --url=\"https://media.mywebsitename.com/cdn/path/to/image/001-100x100.jpg\" --quality=90 --format=jpeg --maxBytes=100000"
echo ""
echo "Expected behavior:"
echo "  - ALL filters should be included"
echo "  - NO smart mode (height is not 0)"
echo "  - Standard resize mode"
echo ""
echo "Expected THUMBOR_URL:"
echo "http://localhost:8080/unsafe/100x100/filters:quality(90):format(jpeg):max_bytes(100000):strip_icc()/[encoded_url]"
echo ""

# Test 4: Validate filter ignoring with numBytes
echo "Test 4: Validate filter messages with numBytes"
echo "-----------------------------------------------"
echo "Testing with both quality and format (should show ignore messages):"
echo ""
./build.sh --test --url="https://media.mywebsitename.com/cdn/path/to/image/001-100x100.jpg" \
    --quality=90 --format=jpeg --numBytes=45000 2>&1 | \
    grep -E "(Note:|number-of-bytes|quality|format)" | head -10
echo ""

echo "==============================================="
echo "Run the commands above to verify the corrected"
echo "filter logic is working as expected."
echo "==============================================="
