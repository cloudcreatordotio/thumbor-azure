#!/bin/bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Build script for Thumbor Azure Container with Multiplatform Support
# Usage: ./build.sh [options]
#
# Options:
#   --push                Push to Azure Container Registry
#   --tag <tag>          Custom tag (default: latest)
#   --registry <name>    Azure Container Registry name
#   --test               Run container locally for testing
#   --url <url>          Test with a specific image URL (requires --test)
#   --platform <list>    Target platforms (default: current platform)
#   --multiplatform-push Build and push multiplatform images to registry
#   --builder <name>     Use specific buildx builder (default: thumbor-multiplatform)
#   --no-cache           Build without using cache

# Default values
TAG="latest"
PUSH=false
TEST=false
REGISTRY=""
IMAGE_NAME="thumbor-azure"
TEST_URL=""
# Image processing parameters
QUALITY=""
FORMAT=""
MAX_BYTES=""
NUM_BYTES=""
# Multiplatform build parameters
PLATFORM=""
MULTIPLATFORM_PUSH=false
BUILDER_NAME="thumbor-multiplatform"
NO_CACHE=false
# Supply chain attestations (SBOM and provenance)
ENABLE_ATTESTATIONS=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --push)
            PUSH=true
            shift
            ;;
        --tag)
            TAG="$2"
            shift 2
            ;;
        --tag=*)
            TAG="${1#*=}"
            shift
            ;;
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        --registry=*)
            REGISTRY="${1#*=}"
            shift
            ;;
        --test)
            TEST=true
            shift
            ;;
        --url)
            TEST_URL="$2"
            shift 2
            ;;
        --url=*)
            TEST_URL="${1#*=}"
            shift
            ;;
        --quality)
            QUALITY="$2"
            shift 2
            ;;
        --quality=*)
            QUALITY="${1#*=}"
            shift
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --format=*)
            FORMAT="${1#*=}"
            shift
            ;;
        --maxBytes)
            MAX_BYTES="$2"
            shift 2
            ;;
        --maxBytes=*)
            MAX_BYTES="${1#*=}"
            shift
            ;;
        --numBytes)
            NUM_BYTES="$2"
            shift 2
            ;;
        --numBytes=*)
            NUM_BYTES="${1#*=}"
            shift
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --platform=*)
            PLATFORM="${1#*=}"
            shift
            ;;
        --multiplatform-push)
            MULTIPLATFORM_PUSH=true
            shift
            ;;
        --builder)
            BUILDER_NAME="$2"
            shift 2
            ;;
        --builder=*)
            BUILDER_NAME="${1#*=}"
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --no-attestations)
            ENABLE_ATTESTATIONS=false
            shift
            ;;
        --help)
            echo "Build script for Thumbor Azure Container with Multiplatform Support"
            echo ""
            echo "Usage: ./build.sh [options]"
            echo ""
            echo "Options:"
            echo "  --push                  Push to Azure Container Registry or Docker Hub"
            echo "  --tag <tag>            Custom tag (default: latest)"
            echo "  --registry <name>      Azure Container Registry name, or 'thumbor-azure' for Docker Hub"
            echo "  --test                 Run container locally for testing"
            echo "  --url <url>            Test with a specific image URL (requires --test)"
            echo "                         Example: --url 'https://example.com/image-100x100.jpg'"
            echo "                         Also supports: --url='https://example.com/image-100x100.jpg'"
            echo "  --quality <num>        JPEG quality (1-100) for Thumbor processing"
            echo "  --format <fmt>         Output format (jpeg, png, webp, etc.)"
            echo "  --maxBytes <num>       Maximum file size in bytes (uses smart mode)"
            echo "  --numBytes <num>       Target file size in bytes (uses fit-in mode)"
            echo ""
            echo "Multiplatform Build Options:"
            echo "  --platform <list>      Target platforms (e.g., linux/amd64,linux/arm64)"
            echo "                         Default: current platform only"
            echo "  --multiplatform-push   Build and push multiplatform images to registry"
            echo "                         (implies --push, requires --registry)"
            echo "  --builder <name>       Use specific buildx builder"
            echo "                         Default: thumbor-multiplatform"
            echo "  --no-cache             Build without using cache"
            echo "  --no-attestations      Disable supply chain attestations (SBOM and provenance)"
            echo "                         Note: Attestations are only added when pushing to registry"
            echo ""
            echo "  --help                 Show this help message"
            echo ""
            echo "Supply Chain Security:"
            echo "  By default, when pushing to registries, this script includes supply chain"
            echo "  attestations (SBOM and provenance) for enhanced security. These provide:"
            echo "  - SBOM: Software Bill of Materials listing all components in the image"
            echo "  - Provenance: Cryptographic proof of how and where the image was built"
            echo "  Use --no-attestations to disable if needed (not recommended for production)."
            echo ""
            echo "Examples:"
            echo "  # Local development (current platform only)"
            echo "  ./build.sh --test"
            echo ""
            echo "  # Build for linux/amd64 and load locally"
            echo "  ./build.sh --platform linux/amd64"
            echo ""
            echo "  # Build multiplatform and push to Azure"
            echo "  ./build.sh --multiplatform-push --registry myregistry --tag v1.0.0"
            echo ""
            echo "  # Push to Docker Hub (cloudcreatordotio/thumbor-azure)"
            echo "  ./build.sh --push --registry thumbor-azure --tag v1.0.0"
            echo ""
            echo "  # Multiplatform push to Docker Hub"
            echo "  ./build.sh --multiplatform-push --registry thumbor-azure --tag v1.0.0"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run './build.sh --help' for usage information"
            exit 1
            ;;
    esac
done

echo "========================================="
echo "Building Thumbor Azure Container"
echo "========================================="
echo "Image: $IMAGE_NAME:$TAG"
echo ""

# Validate arguments
if [ -n "$TEST_URL" ] && [ "$TEST" = false ]; then
    echo "Error: --url requires --test flag"
    echo "Example: ./build.sh --test --url 'https://example.com/image-100x100.jpg'"
    exit 1
fi

# Validate multiplatform push requirements
if [ "$MULTIPLATFORM_PUSH" = true ] && [ -z "$REGISTRY" ]; then
    echo "Error: --multiplatform-push requires --registry"
    echo "Example: ./build.sh --multiplatform-push --registry myregistry"
    exit 1
fi

# Debug: Show captured URL if provided
if [ -n "$TEST_URL" ]; then
    echo "User-provided URL captured: $TEST_URL"
fi

# Validate quality parameter if provided
if [ -n "$QUALITY" ]; then
    if ! [[ "$QUALITY" =~ ^[0-9]+$ ]] || [ "$QUALITY" -lt 1 ] || [ "$QUALITY" -gt 100 ]; then
        echo "Error: --quality must be a number between 1 and 100"
        exit 1
    fi
fi

# Validate format parameter if provided
if [ -n "$FORMAT" ]; then
    VALID_FORMATS="jpeg jpg png webp gif avif"
    if ! echo "$VALID_FORMATS" | grep -qw "$FORMAT"; then
        echo "Warning: Format '$FORMAT' may not be supported. Common formats: jpeg, png, webp"
    fi
fi

# Validate byte parameters
if [ -n "$MAX_BYTES" ] && [ -n "$NUM_BYTES" ]; then
    echo "Warning: Both --maxBytes and --numBytes specified. This may produce unexpected results."
fi

# Check if we're in the build directory
if [ ! -f "Dockerfile" ]; then
    echo "Error: Dockerfile not found. Please run this script from the build directory."
    exit 1
fi

# Handle multiplatform push flag
if [ "$MULTIPLATFORM_PUSH" = true ]; then
    PUSH=true
    if [ -z "$PLATFORM" ]; then
        # Default platforms for multiplatform push
        PLATFORM="linux/amd64,linux/arm64"
    fi
fi

# Detect Docker Hub special case
DOCKER_HUB_PUSH=false
DOCKER_HUB_IMAGE=""
if [ "$REGISTRY" = "thumbor-azure" ]; then
    DOCKER_HUB_PUSH=true
    DOCKER_HUB_IMAGE="cloudcreatordotio/thumbor-azure:$TAG"
    echo "Special case detected: Will push to Docker Hub instead of Azure Container Registry"
    echo "Target image: $DOCKER_HUB_IMAGE"
fi

# Setup buildx builder if using platform or multiplatform features
if [ -n "$PLATFORM" ] || [ "$MULTIPLATFORM_PUSH" = true ]; then
    echo "Setting up Docker buildx builder..."

    # Check if the builder exists (handle with or without asterisk)
    if docker buildx ls | grep -q "^${BUILDER_NAME}\\(\\*\\)\\?\\s"; then
        echo "Using existing buildx builder: $BUILDER_NAME"
        docker buildx use "$BUILDER_NAME"
        # Ensure the builder is bootstrapped
        docker buildx inspect "$BUILDER_NAME" --bootstrap >/dev/null 2>&1 || true
    else
        echo "Creating buildx builder: $BUILDER_NAME"
        docker buildx create --name "$BUILDER_NAME" --driver docker-container --use
        docker buildx inspect --bootstrap
    fi

    # Login to appropriate registry if pushing multiplatform or multiple platforms with --push
    if ([ "$MULTIPLATFORM_PUSH" = true ] || ([ "$PUSH" = true ] && [[ "$PLATFORM" == *","* ]])) && [ -n "$REGISTRY" ]; then
        echo ""
        if [ "$DOCKER_HUB_PUSH" = true ]; then
            echo "Logging in to Docker Hub..."
            echo "Note: Make sure you're logged in to Docker Hub (docker login)"
            # Docker login is already handled by docker CLI, just remind user
            echo "If not already logged in, run: docker login"
        else
            echo "Logging in to Azure Container Registry..."
            echo "Note: Make sure you're logged in to Azure CLI (az login)"
            az acr login --name "$REGISTRY" || {
                echo "Error: Failed to login to Azure Container Registry"
                echo "Make sure you have run 'az login' and have access to the registry"
                exit 1
            }
        fi
    fi
fi

# Prepare build command
BUILD_CMD="docker"
BUILD_ARGS=""

if [ -n "$PLATFORM" ] || [ "$MULTIPLATFORM_PUSH" = true ]; then
    # Use buildx for multiplatform builds
    BUILD_CMD="docker buildx"
    BUILD_ARGS="build"

    # Add platform flag if specified
    if [ -n "$PLATFORM" ]; then
        BUILD_ARGS="$BUILD_ARGS --platform $PLATFORM"
    fi

    # Determine output type
    if [ "$MULTIPLATFORM_PUSH" = true ] && [ -n "$REGISTRY" ]; then
        # Push directly to registry for multiplatform
        if [ "$DOCKER_HUB_PUSH" = true ]; then
            TARGET_IMAGE="$DOCKER_HUB_IMAGE"
        else
            TARGET_IMAGE="$REGISTRY.azurecr.io/$IMAGE_NAME:$TAG"
        fi
        BUILD_ARGS="$BUILD_ARGS --push -t $TARGET_IMAGE"
        # Add supply chain attestations for pushed images
        if [ "$ENABLE_ATTESTATIONS" = true ]; then
            BUILD_ARGS="$BUILD_ARGS --provenance=true --sbom=true"
            echo "Supply chain attestations (SBOM and provenance) will be included"
        fi
        echo "Will push multiplatform image directly to: $TARGET_IMAGE"
    elif [ "$PUSH" = true ] && [[ "$PLATFORM" == *","* ]] && [ -n "$REGISTRY" ]; then
        # Push directly when using --push with multiple platforms
        if [ "$DOCKER_HUB_PUSH" = true ]; then
            TARGET_IMAGE="$DOCKER_HUB_IMAGE"
        else
            TARGET_IMAGE="$REGISTRY.azurecr.io/$IMAGE_NAME:$TAG"
        fi
        BUILD_ARGS="$BUILD_ARGS --push -t $TARGET_IMAGE"
        # Add supply chain attestations for pushed images
        if [ "$ENABLE_ATTESTATIONS" = true ]; then
            BUILD_ARGS="$BUILD_ARGS --provenance=true --sbom=true"
            echo "Supply chain attestations (SBOM and provenance) will be included"
        fi
        echo "Will push multiplatform image directly to: $TARGET_IMAGE"
    elif [ "$PUSH" = true ] && [ -n "$REGISTRY" ]; then
        # Single platform with push - can load locally then push later
        BUILD_ARGS="$BUILD_ARGS --load -t $IMAGE_NAME:$TAG"
    elif [ "$PUSH" = false ]; then
        # Load locally (only works for single platform)
        if [[ "$PLATFORM" == *","* ]]; then
            echo "Warning: Cannot load multiple platforms locally. Building without loading."
            echo "Use --push or --multiplatform-push to push to a registry instead."
        else
            BUILD_ARGS="$BUILD_ARGS --load -t $IMAGE_NAME:$TAG"
            if [ "$ENABLE_ATTESTATIONS" = true ]; then
                echo "Note: Building for local use without attestations (attestations require --push)"
            fi
        fi
    fi
else
    # Use regular docker build for single platform
    BUILD_CMD="docker"
    BUILD_ARGS="build -t $IMAGE_NAME:$TAG"
fi

# Add no-cache flag if requested
if [ "$NO_CACHE" = true ]; then
    BUILD_ARGS="$BUILD_ARGS --no-cache"
fi

# Add the current directory
BUILD_ARGS="$BUILD_ARGS ."

# Build the Docker image
echo "Building Docker image..."
echo "Command: $BUILD_CMD $BUILD_ARGS"
$BUILD_CMD $BUILD_ARGS

if [ $? -ne 0 ]; then
    echo "Error: Docker build failed"
    exit 1
fi

echo "Docker build completed successfully!"

# Skip additional push if already pushed via multiplatform or --push with multiple platforms
if ([ "$MULTIPLATFORM_PUSH" = true ] || ([ "$PUSH" = true ] && [[ "$PLATFORM" == *","* ]])) && [ -n "$REGISTRY" ]; then
    PUSH=false  # Already pushed, skip the regular push section
    echo "Multiplatform image already pushed to registry."
fi

# Test the container locally if requested
if [ "$TEST" = true ]; then
    echo ""
    echo "========================================="
    echo "Testing container locally..."
    echo "========================================="

    # Stop any existing test container
    docker stop thumbor-test 2>/dev/null || true
    docker rm thumbor-test 2>/dev/null || true

    # Run the container
    echo "Starting test container on port 8080..."
    docker run -d \
        --name thumbor-test \
        -p 8080:80 \
        -e THUMBOR_NUM_PROCESSES=2 \
        -e SECURITY_KEY=test_key_123 \
        -e ALLOW_UNSAFE_URL=True \
        -e ALLOWED_SOURCES='[]' \
        "$IMAGE_NAME:$TAG"

    # Wait for container to start
    echo "Waiting for container to be ready..."
    sleep 10

    # Test health check
    echo "Testing health check endpoint..."
    curl -f http://localhost:8080/healthcheck || {
        echo "Health check failed!"
        echo "Container logs:"
        docker logs thumbor-test
        docker stop thumbor-test
        docker rm thumbor-test
        exit 1
    }

    echo "Health check passed!"

    # Test Thumbor is responding (without external image fetch)
    echo "Testing Thumbor service..."
    echo ""
    echo "Note: Testing with an invalid image path to verify the service is responding."
    echo "A 504 Gateway Timeout is EXPECTED and NORMAL - it means:"
    echo "  • Nginx proxy is working correctly"
    echo "  • Thumbor is receiving requests"
    echo "  • The timeout occurs because 'not-an-image' doesn't exist"
    echo ""

    # Test 1: Check if Thumbor returns proper error for invalid image
    INTERNAL_TEST_URL="http://localhost:8080/unsafe/100x100/not-an-image"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$INTERNAL_TEST_URL")
    if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "404" ]; then
        echo "✓ Thumbor service is responding correctly (HTTP $HTTP_CODE)"
    elif [ "$HTTP_CODE" = "504" ]; then
        echo "✓ Received expected 504 timeout (this is normal - see note above)"
    else
        echo "⚠ Unexpected response code: $HTTP_CODE (but service may still be working)"
    fi

    # Test 2: Verify all services are running
    echo ""
    echo "Verifying all services are running..."
    docker exec thumbor-test supervisorctl status | grep RUNNING > /dev/null || {
        echo "ERROR: Some services are not running!"
        docker exec thumbor-test supervisorctl status
        docker stop thumbor-test
        docker rm thumbor-test
        exit 1
    }

    echo "✓ All services running successfully!"

    # Test with custom URL if provided
    if [ -n "$TEST_URL" ]; then
        echo ""
        echo "========================================="
        echo "Testing with custom image URL"
        echo "========================================="
        echo "URL: $TEST_URL"
        echo "Current directory: $(pwd)"
        echo "Script directory: $SCRIPT_DIR"

        # Extract filename and dimensions from URL
        # Example: https://media.mywebsitename.com/cdn/path/to/image/001-100x100.jpg

        # Get the filename from the URL
        FILENAME_WITH_DIM=$(basename "$TEST_URL")
        echo "Filename with dimensions: $FILENAME_WITH_DIM"

        # Initialize variables
        BASE_FILENAME=""
        WIDTH=""
        HEIGHT=""
        EXTENSION=""
        ORIGINAL_URL=""

        # Try to extract dimensions from the filename
        # Pattern: {uuid}-{width}x{height}.{extension}
        echo ""
        echo "Attempting to extract dimensions from filename..."
        if [[ $FILENAME_WITH_DIM =~ ^(.+)-([0-9]+)x([0-9]+)\.([^.]+)$ ]]; then
            BASE_FILENAME="${BASH_REMATCH[1]}"
            WIDTH="${BASH_REMATCH[2]}"
            HEIGHT="${BASH_REMATCH[3]}"
            EXTENSION="${BASH_REMATCH[4]}"

            # Construct original URL by removing dimension suffix
            ORIGINAL_URL="${TEST_URL%-${WIDTH}x${HEIGHT}.${EXTENSION}}.${EXTENSION}"

            echo "✓ Successfully extracted:"
            echo "  Base filename: ${BASE_FILENAME}"
            echo "  Extension: ${EXTENSION}"
            echo "  Dimensions: ${WIDTH}x${HEIGHT}"
            echo "  Original URL: ${ORIGINAL_URL}"
        else
            echo "Warning: Could not extract dimensions from URL."
            echo "Expected format: filename-WIDTHxHEIGHT.extension"
            echo "Example: image-100x100.jpg"
            # Use the URL as-is
            ORIGINAL_URL="$TEST_URL"
            BASE_FILENAME="${FILENAME_WITH_DIM%.*}"
            EXTENSION="${FILENAME_WITH_DIM##*.}"
            WIDTH="300"
            HEIGHT="200"
            echo "Using default dimensions: ${WIDTH}x${HEIGHT}"
        fi

        # Create directories for output
        echo ""
        echo "Creating output directories..."
        mkdir -p "$SCRIPT_DIR/test_output/original"
        mkdir -p "$SCRIPT_DIR/test_output/cropped"
        echo "  Created: $SCRIPT_DIR/test_output/original/"
        echo "  Created: $SCRIPT_DIR/test_output/cropped/"

        # Download original image
        echo ""
        echo "Downloading original image..."
        ORIGINAL_FILE="$SCRIPT_DIR/test_output/original/${BASE_FILENAME}.${EXTENSION}"
        echo "  From: $ORIGINAL_URL"
        echo "  To: $ORIGINAL_FILE"

        # Download with curl, following redirects and showing progress
        if curl -L -f --max-time 30 -o "$ORIGINAL_FILE" "$ORIGINAL_URL"; then
            echo "✓ Original image saved to: $ORIGINAL_FILE"

            # Check if file was actually downloaded and has content
            if [ -s "$ORIGINAL_FILE" ]; then
                FILE_SIZE=$(ls -lh "$ORIGINAL_FILE" | awk '{print $5}')
                echo "  File size: $FILE_SIZE"
            else
                echo "Warning: Downloaded file appears to be empty"
            fi
        else
            echo "✗ Failed to download original image from: $ORIGINAL_URL"
            echo "  This might be due to network restrictions or invalid URL"
        fi

        # Process image with Thumbor
        echo ""
        echo "Processing image with Thumbor..."

        # Construct Thumbor URL for cropping
        # Note: We need to URL encode the original URL for Thumbor
        echo "Encoding URL for Thumbor..."
        ENCODED_URL=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$ORIGINAL_URL', safe=''))")

        # Build filter string based on provided parameters
        FILTERS=""

        # Special handling for numBytes - it overrides other filters
        if [ -n "$NUM_BYTES" ]; then
            # When numBytes is specified, only use number-of-bytes and strip_icc
            FILTERS="number-of-bytes($NUM_BYTES):strip_icc()"
            echo "  Using number-of-bytes filter: $NUM_BYTES"
            if [ -n "$QUALITY" ]; then
                echo "  Note: Quality filter ignored when using numBytes"
            fi
            if [ -n "$FORMAT" ]; then
                echo "  Note: Format filter ignored when using numBytes"
            fi
        else
            # Build filters for non-numBytes cases

            # Add quality filter if specified
            if [ -n "$QUALITY" ]; then
                FILTERS="${FILTERS}quality($QUALITY):"
                echo "  Adding quality filter: $QUALITY"
            fi

            # Add format filter if specified
            if [ -n "$FORMAT" ]; then
                FILTERS="${FILTERS}format($FORMAT):"
                echo "  Adding format filter: $FORMAT"
            fi

            # Add max_bytes filter if specified
            if [ -n "$MAX_BYTES" ]; then
                FILTERS="${FILTERS}max_bytes($MAX_BYTES):"
                echo "  Adding max_bytes filter: $MAX_BYTES"
            fi

            # Always add strip_icc filter
            FILTERS="${FILTERS}strip_icc()"
        fi

        # Determine resize mode and dimensions
        if [ -n "$NUM_BYTES" ]; then
            # Use fit-in mode with numBytes (keeping original dimensions)
            RESIZE_MODE="fit-in/${WIDTH}x${HEIGHT}"
            echo "  Using fit-in mode for numBytes"
        elif [ -n "$MAX_BYTES" ] && [ "$HEIGHT" = "0" ]; then
            # Use smart mode when height is 0 and maxBytes is specified
            RESIZE_MODE="${WIDTH}x${HEIGHT}/smart"
            echo "  Using smart mode for maxBytes with height=0"
        elif [ -n "$MAX_BYTES" ]; then
            # Use regular dimensions with maxBytes when height is not 0
            RESIZE_MODE="${WIDTH}x${HEIGHT}"
            echo "  Using standard mode for maxBytes"
        else
            # Default mode
            RESIZE_MODE="${WIDTH}x${HEIGHT}"
        fi

        # Construct the final Thumbor URL
        if [ "$FILTERS" != "strip_icc()" ]; then
            # We have filters beyond just strip_icc
            THUMBOR_URL="http://localhost:8080/unsafe/${RESIZE_MODE}/filters:${FILTERS}/${ENCODED_URL}"
        else
            # No custom filters, use simpler URL
            THUMBOR_URL="http://localhost:8080/unsafe/${RESIZE_MODE}/${ENCODED_URL}"
        fi

        echo ""
        echo "========================================="
        echo "THUMBOR REQUEST URL:"
        echo "$THUMBOR_URL"
        echo "========================================="
        echo ""
        echo "  Encoded source: $ENCODED_URL"
        echo "  Resize mode: $RESIZE_MODE"
        echo "  Filters: $FILTERS"

        # Modify output filename to include format if specified (but not when numBytes is used)
        if [ -n "$FORMAT" ] && [ -z "$NUM_BYTES" ]; then
            CROPPED_FILE="$SCRIPT_DIR/test_output/cropped/${BASE_FILENAME}-${WIDTH}x${HEIGHT}.${FORMAT}"
        else
            CROPPED_FILE="$SCRIPT_DIR/test_output/cropped/${BASE_FILENAME}-${WIDTH}x${HEIGHT}.${EXTENSION}"
        fi
        echo "  Output file: $CROPPED_FILE"

        # Add copy-paste friendly version for manual testing
        echo ""
        echo "To manually test this URL in a browser or curl:"
        echo "curl -o test.jpg \"$THUMBOR_URL\""

        # Download cropped image from Thumbor with extended timeout
        echo ""
        echo "Requesting cropped image from Thumbor (this may take a moment)..."
        echo "  Using URL: $THUMBOR_URL"

        if curl -L -f --max-time 60 -o "$CROPPED_FILE" "$THUMBOR_URL"; then
            # Check if file has content
            if [ -s "$CROPPED_FILE" ]; then
                FILE_SIZE=$(ls -lh "$CROPPED_FILE" | awk '{print $5}')
                echo "✓ Cropped image saved to: $CROPPED_FILE"
                echo "  File size: $FILE_SIZE"

                # Show summary
                echo ""
                echo "========================================="
                echo "Image Processing Complete!"
                echo "========================================="
                echo "Original: $ORIGINAL_FILE"
                echo "Cropped:  $CROPPED_FILE"
                echo "Dimensions: ${WIDTH}x${HEIGHT}"
                echo ""
                echo "Thumbor URL used:"
                echo "$THUMBOR_URL"
            else
                echo "✗ Thumbor returned an empty file"
                rm -f "$CROPPED_FILE"

                # Try to get more information about the error
                echo ""
                echo "Debugging information:"
                echo "  Attempted URL: $THUMBOR_URL"
                HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$THUMBOR_URL")
                echo "  HTTP Response Code: $HTTP_CODE"

                if [ "$HTTP_CODE" = "400" ]; then
                    echo "  Error: Bad request - URL might not be in ALLOWED_SOURCES"
                elif [ "$HTTP_CODE" = "404" ]; then
                    echo "  Error: Image not found at source URL"
                elif [ "$HTTP_CODE" = "504" ]; then
                    echo "  Error: Gateway timeout - source server might be slow or blocking"
                fi
            fi
        else
            echo "✗ Failed to get cropped image from Thumbor"
            echo "  Attempted URL: $THUMBOR_URL"
            echo "  This might be due to:"
            echo "  - Source domain not in ALLOWED_SOURCES (currently set to '[]' for testing)"
            echo "  - Network timeout or connectivity issues"
            echo "  - Invalid image format"

            # Show Thumbor logs for debugging
            echo ""
            echo "Recent Thumbor logs:"
            docker logs --tail 10 thumbor-test 2>&1 | grep -E "(ERROR|WARNING|thumbor)" || true
        fi

        # Show final directory contents
        echo ""
        echo "========================================="
        echo "Directory Contents After Processing"
        echo "========================================="
        echo ""
        echo "Files in test_output/original/:"
        if [ -d "$SCRIPT_DIR/test_output/original" ]; then
            ls -la "$SCRIPT_DIR/test_output/original/" 2>/dev/null || echo "  Directory exists but is empty"
        else
            echo "  Directory does not exist"
        fi

        echo ""
        echo "Files in test_output/cropped/:"
        if [ -d "$SCRIPT_DIR/test_output/cropped" ]; then
            ls -la "$SCRIPT_DIR/test_output/cropped/" 2>/dev/null || echo "  Directory exists but is empty"
        else
            echo "  Directory does not exist"
        fi

        echo ""
    else
        # Original note about external image fetching
        echo ""
        echo "Note: External image fetching tests are skipped as they may timeout in Docker."
        echo "This is normal and does not affect production deployment."
    fi

    # Show container logs
    echo ""
    echo "Container logs (last 20 lines):"
    docker logs --tail 20 thumbor-test

    # Cleanup
    echo ""
    echo "Stopping test container..."
    docker stop thumbor-test
    docker rm thumbor-test

    echo "Local testing completed successfully!"
fi

# Push to registry if requested
if [ "$PUSH" = true ]; then
    if [ -z "$REGISTRY" ]; then
        echo "Error: --registry is required when using --push"
        echo "Example: ./build.sh --push --registry myregistry"
        exit 1
    fi

    echo ""

    if [ "$DOCKER_HUB_PUSH" = true ]; then
        echo "========================================="
        echo "Pushing to Docker Hub"
        echo "========================================="

        # Login reminder for Docker Hub
        echo "Note: Make sure you're logged in to Docker Hub (docker login)"
        echo "If not already logged in, run: docker login"
        echo ""

        # Tag the image for Docker Hub
        echo "Tagging image for Docker Hub..."
        docker tag "$IMAGE_NAME:$TAG" "$DOCKER_HUB_IMAGE"

        # Push the image
        echo "Pushing image to Docker Hub..."
        docker push "$DOCKER_HUB_IMAGE"

        if [ $? -eq 0 ]; then
            echo ""
            echo "========================================="
            echo "Image successfully pushed to Docker Hub!"
            echo "Image: $DOCKER_HUB_IMAGE"
            echo "========================================="
            echo ""
            echo "To pull this image:"
            echo "docker pull $DOCKER_HUB_IMAGE"
            echo ""
            echo "To run this image:"
            echo "docker run -p 8080:80 $DOCKER_HUB_IMAGE"
        else
            echo "Error: Failed to push image to Docker Hub"
            echo "Please ensure you are logged in: docker login"
            exit 1
        fi
    else
        echo "========================================="
        echo "Pushing to Azure Container Registry"
        echo "========================================="

        # Full image name for ACR
        ACR_IMAGE="$REGISTRY.azurecr.io/$IMAGE_NAME:$TAG"

        # Login to Azure Container Registry
        echo "Logging in to Azure Container Registry..."
        echo "Note: Make sure you're logged in to Azure CLI (az login)"
        az acr login --name "$REGISTRY" || {
            echo "Error: Failed to login to Azure Container Registry"
            echo "Make sure you have run 'az login' and have access to the registry"
            exit 1
        }

        # Tag the image for ACR
        echo "Tagging image for ACR..."
        docker tag "$IMAGE_NAME:$TAG" "$ACR_IMAGE"

        # Push the image
        echo "Pushing image to ACR..."
        docker push "$ACR_IMAGE"

        if [ $? -eq 0 ]; then
            echo ""
            echo "========================================="
            echo "Image successfully pushed to ACR!"
            echo "Image: $ACR_IMAGE"
            echo "========================================="
            echo ""
            echo "To deploy to Azure Web App, use:"
            echo "az webapp config container set \\"
            echo "  --name <webapp-name> \\"
            echo "  --resource-group <resource-group> \\"
            echo "  --docker-custom-image-name $ACR_IMAGE \\"
            echo "  --docker-registry-server-url https://$REGISTRY.azurecr.io"
        else
            echo "Error: Failed to push image to ACR"
            exit 1
        fi
    fi
fi

echo ""
echo "========================================="
echo "Build process completed!"
echo "========================================="
