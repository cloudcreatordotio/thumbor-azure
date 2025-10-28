#!/bin/bash

echo "Testing URL Generation (no Docker needed)"
echo "=========================================="
echo ""

# Create a minimal test that just shows URL construction
TEST_URL1="https://media.mywebsitename.com/cdn/path/to/image/001-100x100.jpg"
TEST_URL2="https://media.mywebsitename.com/cdn/path/to/image/001-100x0.jpg"

echo "Example 1: numBytes=45000 with quality=90"
echo "URL: $TEST_URL1"
echo "Parameters: --quality=90 --numBytes=45000"
echo ""
echo "Expected filters: number-of-bytes(45000):strip_icc()"
echo "Expected mode: fit-in/100x100"
echo ""

echo "Example 2: maxBytes=100000 with quality=90 format=jpeg"
echo "URL: $TEST_URL2"
echo "Parameters: --quality=90 --format=jpeg --maxBytes=100000"
echo ""
echo "Expected filters: quality(90):format(jpeg):max_bytes(100000):strip_icc()"
echo "Expected mode: 100x0/smart"
echo ""

echo "To see actual URLs generated, run:"
echo "./build.sh --test --url=\"$TEST_URL1\" --quality=90 --numBytes=45000"
echo "./build.sh --test --url=\"$TEST_URL2\" --quality=90 --format=jpeg --maxBytes=100000"
