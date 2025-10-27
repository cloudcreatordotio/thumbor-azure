#!/bin/bash
# Verification script for the exact user examples

echo "================================================"
echo "Verifying User's Exact Examples"
echo "================================================"
echo ""

# Example 1: numBytes case
echo "Example 1: numBytes with quality"
echo "---------------------------------"
echo "Command:"
echo "./build.sh --test --url=\"https://media.mywebsitename.com/cdn/path/to/image/001-100x100.jpg\" --quality=90 --numBytes=45000"
echo ""
echo "Expected URL:"
echo "http://localhost:8080/unsafe/fit-in/100x100/filters:number-of-bytes(45000):strip_icc()/https%3A%2F%2F..."
echo ""
echo "Actual output (filtered):"
./build.sh --test --url="https://media.mywebsitename.com/cdn/path/to/image/001-100x100.jpg" \
    --quality=90 --numBytes=45000 2>&1 | \
    grep -A 1 "THUMBOR REQUEST URL:" | tail -1
echo ""

# Example 2: maxBytes with height=0 case
echo "Example 2: maxBytes with smart mode"
echo "------------------------------------"
echo "Command:"
echo "./build.sh --test --url=\"https://media.mywebsitename.com/cdn/path/to/image/001-100x100.jpg\" --quality=90 --format=jpeg --maxBytes=100000"
echo ""
echo "Expected URL:"
echo "http://localhost:8080/unsafe/100x0/smart/filters:quality(90):format(jpeg):max_bytes(100000):strip_icc()/https%3A%2F%2F..."
echo ""
echo "Actual output (filtered):"
./build.sh --test --url="https://media.mywebsitename.com/cdn/path/to/image/001-100x100.jpg" \
    --quality=90 --format=jpeg --maxBytes=100000 2>&1 | \
    grep -A 1 "THUMBOR REQUEST URL:" | tail -1
echo ""

echo "================================================"
echo "Verification complete!"
echo "================================================"
