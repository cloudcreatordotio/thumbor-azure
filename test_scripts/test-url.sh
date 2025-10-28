#!/bin/bash
# Quick test script for URL processing feature

URL="https://media.mywebsitename.com/cdn/path/to/image/001-100x100.jpg"

echo "Testing Thumbor with URL processing..."
echo "URL: $URL"
echo ""
echo "This will:"
echo "1. Build the Docker image"
echo "2. Start a test container"
echo "3. Download the original image"
echo "4. Crop it to 100x100 using Thumbor"
echo "5. Save both versions to test_output/"
echo ""
echo "Running: ./build.sh --test --url \"$URL\""
echo ""

./build.sh --test --url "$URL"
