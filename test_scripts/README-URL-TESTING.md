# URL Testing Feature for Thumbor Build Script

## Overview
The build script now supports testing with specific image URLs to verify Thumbor's image processing capabilities. When you provide a URL with dimensions in the filename, the script will:
1. Download the original image (without dimensions)
2. Use Thumbor to crop the image to the specified dimensions
3. Save both versions for comparison

## Usage

### Basic Command
Both argument formats are supported:

```bash
# Space-separated format
./build.sh --test --url "https://media.mywebsitename.com/cdn/path/to/image/001-100x100.jpg"

# Equals-separated format (also works)
./build.sh --test --url="https://media.mywebsitename.com/cdn/path/to/image/001-100x100.jpg"
```

### Quick Test Script
For convenience, use the provided test script:
```bash
./test-url.sh
```

## How It Works

### URL Format
The script expects URLs with dimensions in the filename:
- Pattern: `{filename}-{width}x{height}.{extension}`
- Example: `image-100x100.jpg`

### Processing Steps
1. **Parse URL**: Extract dimensions from the filename (100x100)
2. **Construct Original URL**: Remove dimension suffix to get original image URL
3. **Download Original**: Save to `test_output/original/`
4. **Crop with Thumbor**: Request cropped version at specified dimensions
5. **Save Cropped**: Save to `test_output/cropped/`

### Output Structure
```
build/
└── test_output/
    ├── original/
    │   └── 001.jpg
    └── cropped/
        └── 001-100x100.jpg
```

## Features

### Automatic Dimension Detection
- Automatically extracts width and height from URL
- Falls back to 300x200 if dimensions can't be extracted

### Error Handling
- Validates that `--url` is used with `--test`
- Handles download failures gracefully
- Provides detailed error messages for debugging
- Shows HTTP response codes for troubleshooting

### Debugging Support
- Displays Thumbor logs on failure
- Shows file sizes for downloaded images
- Provides clear progress indicators

## Examples

### Test with Different Dimensions
```bash
# 800x600 crop (space-separated)
./build.sh --test --url "https://example.com/image-800x600.jpg"

# 1920x1080 crop (equals-separated)
./build.sh --test --url="https://example.com/photo-1920x1080.png"

# Both formats work identically
```

### URL Without Dimensions
If your URL doesn't have dimensions in the filename, the script will use default dimensions (300x200):
```bash
./build.sh --test --url "https://example.com/image.jpg"
```

## Troubleshooting

### Common Issues

1. **504 Gateway Timeout**
   - The source server might be slow or blocking requests
   - This is normal for some external sources

2. **400 Bad Request**
   - The source domain might not be in ALLOWED_SOURCES
   - During testing, ALLOWED_SOURCES is set to '[]' (empty)

3. **Empty File Downloaded**
   - Check network connectivity
   - Verify the URL is accessible
   - Check if the source requires authentication

### Debug Commands
```bash
# Check container logs
docker logs thumbor-test

# Check if services are running
docker exec thumbor-test supervisorctl status

# Test Thumbor health
curl http://localhost:8080/healthcheck
```

## Notes

- The test container runs with `ALLOWED_SOURCES='[]'` for unrestricted testing
- Python 3 is required for URL encoding
- Images are processed using Thumbor's unsafe URL mode for testing
- The container must be running before URL testing begins
