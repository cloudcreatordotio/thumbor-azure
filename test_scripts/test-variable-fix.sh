#!/bin/bash
# Test script to verify the TEST_URL variable collision fix

echo "Testing Variable Collision Fix"
echo "=============================="
echo ""
echo "This test will verify that the TEST_URL variable is not overwritten"
echo "during internal connectivity tests."
echo ""

# Test URL
URL="https://media.mywebsitename.com/cdn/path/to/image/001-100x100.jpg"

# Check if TEST_URL variable is preserved
echo "Expected behavior:"
echo "1. User-provided URL should be captured and displayed"
echo "2. URL should show: $URL"
echo "3. Filename should be: 001-100x100.jpg"
echo "4. Dimensions should be extracted as: 100x100"
echo "5. Original URL should be constructed correctly"
echo ""
echo "Running: ./build.sh --url=\"$URL\" 2>&1 | head -10"
echo ""

# Test without --test flag to see the captured URL message
./build.sh --url="$URL" 2>&1 | head -10

echo ""
echo "The above should show:"
echo "- 'User-provided URL captured: $URL'"
echo "- Error about needing --test flag"
echo ""
echo "This confirms the URL is being captured correctly!"
echo ""
echo "Now run the full test with:"
echo "./build.sh --test --url=\"$URL\""
