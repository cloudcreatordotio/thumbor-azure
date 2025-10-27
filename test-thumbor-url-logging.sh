#!/bin/bash
# Test script to verify THUMBOR_URL is properly logged

echo "Testing Enhanced THUMBOR_URL Logging"
echo "====================================="
echo ""
echo "This test verifies that the THUMBOR_URL is prominently displayed"
echo "when using --test with --url flags."
echo ""

# Test URL
URL="https://media.mywebsitename.com/cdn/path/to/image/001-100x100.jpg"

echo "Test URL: $URL"
echo ""
echo "Expected to see:"
echo "1. A highlighted section with THUMBOR REQUEST URL"
echo "2. The full Thumbor URL displayed prominently"
echo "3. A copy-paste friendly curl command"
echo "4. The URL shown again during the request"
echo "5. The URL in the final summary or error messages"
echo ""
echo "Look for sections like:"
echo "========================================="
echo "THUMBOR REQUEST URL:"
echo "http://localhost:8080/unsafe/100x100/..."
echo "========================================="
echo ""
echo "To run the test, execute:"
echo "./build.sh --test --url=\"$URL\""
echo ""
echo "The THUMBOR_URL should appear at least 3-4 times in the output."
