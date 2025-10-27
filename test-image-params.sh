#!/bin/bash
# Test script to verify the new image processing parameters

echo "Testing Image Processing Parameters"
echo "===================================="
echo ""

URL="https://media.mywebsitename.com/cdn/path/to/image/001-100x100.jpg"

# Test 1: Show help for new options
echo "Test 1: Checking help output for new options"
echo "---------------------------------------------"
./build.sh --help | grep -A 4 "quality"
echo ""

# Test 2: Test with numBytes
echo "Test 2: Testing with --numBytes=45000"
echo "--------------------------------------"
echo "Command: ./build.sh --test --url=\"$URL\" --numBytes=45000"
echo ""
echo "Expected THUMBOR_URL format:"
echo "http://localhost:8080/unsafe/fit-in/100x100/filters:number-of-bytes(45000):strip_icc()/{encoded_url}"
echo ""
echo "To run: ./build.sh --test --url=\"$URL\" --numBytes=45000"
echo ""

# Test 3: Test with quality, format, and maxBytes
echo "Test 3: Testing with --quality=90 --format=jpeg --maxBytes=100000"
echo "-----------------------------------------------------------------"
echo "Command: ./build.sh --test --url=\"$URL\" --quality=90 --format=jpeg --maxBytes=100000"
echo ""
echo "Expected THUMBOR_URL format:"
echo "http://localhost:8080/unsafe/100x0/smart/filters:quality(90):format(jpeg):max_bytes(100000):strip_icc()/{encoded_url}"
echo ""
echo "To run: ./build.sh --test --url=\"$URL\" --quality=90 --format=jpeg --maxBytes=100000"
echo ""

# Test 4: Test validation
echo "Test 4: Testing parameter validation"
echo "------------------------------------"
echo "Testing invalid quality (should error):"
./build.sh --test --url="$URL" --quality=150 2>&1 | grep -E "Error|quality"
echo ""

echo "Testing warning for unknown format:"
./build.sh --test --url="$URL" --format=xyz 2>&1 | grep -E "Warning|format"
echo ""

echo "All tests configured!"
echo ""
echo "Run the full tests with the commands shown above to see the actual Thumbor URLs generated."
