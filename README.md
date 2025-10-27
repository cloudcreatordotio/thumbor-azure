# Thumbor Azure Web App Container

This is a single-container implementation of Thumbor image processing service optimized for Azure Web App deployment. It combines Thumbor 7.7.7, Nginx caching proxy, Redis, and RemoteCV into a single container managed by Supervisord.

## Features

- **Thumbor 7.7.7**: Latest stable version with improved performance and features
- **Nginx Caching Proxy**: High-performance caching layer with configurable cache sizes
- **Redis**: Internal Redis server for storage and queueing
- **RemoteCV**: Computer vision service for smart cropping and face detection
- **Supervisord**: Process management ensuring all services run reliably
- **Azure Web App Ready**: Configured for Azure's PORT environment variable
- **Auto-WebP**: Automatic WebP conversion for supported browsers
- **CORS Support**: Configurable CORS headers for cross-domain requests
- **Multiplatform Support**: Build for linux/amd64 and linux/arm64 architectures

## Architecture

```
┌─────────────────────────────────────────────┐
│           Azure Web App Container           │
├─────────────────────────────────────────────┤
│                 Supervisord                 │
├──────┬──────────┬─────────┬────────────────┤
│ Nginx│ Thumbor  │  Redis  │   RemoteCV     │
│ :80  │ :8001-4  │  :6379  │                │
└──────┴──────────┴─────────┴────────────────┘
```

## Quick Start

### Building the Container

```bash
# Make the build script executable
chmod +x build.sh

# Build the Docker image (current platform only)
./build.sh

# Build and test locally
./build.sh --test

# Build with custom tag
./build.sh --tag v1.0.0

# Build for specific platform (e.g., linux/amd64 for Azure)
./build.sh --platform linux/amd64

# Build multiplatform and push to Azure Container Registry
./build.sh --multiplatform-push --registry myregistry --tag v1.0.0

# Push to Docker Hub (cloudcreatordotio/thumbor-azure)
./build.sh --push --registry thumbor-azure --tag latest
```

### Testing Locally

```bash
# Run the container locally
docker run -d \
  --name thumbor-local \
  -p 8080:80 \
  -e THUMBOR_NUM_PROCESSES=4 \
  -e SECURITY_KEY=your-secure-key \
  -e ALLOW_UNSAFE_URL=False \
  thumbor-azure:latest

# Test the health endpoint
curl http://localhost:8080/healthcheck

# Process an image (unsafe URL for testing only)
curl http://localhost:8080/unsafe/300x200/smart/https://via.placeholder.com/600x400
```

## Docker Hub Deployment

The build script includes special support for pushing to Docker Hub. When you use `--registry thumbor-azure`, it automatically pushes to the official Docker Hub repository at `cloudcreatordotio/thumbor-azure`.

### Prerequisites

- Docker Hub account with access to push to `cloudcreatordotio/thumbor-azure`
- Docker CLI logged in: `docker login`

### Pushing to Docker Hub

```bash
# Push single platform image to Docker Hub
./build.sh --push --registry thumbor-azure --tag latest

# Push with a specific version tag
./build.sh --push --registry thumbor-azure --tag v1.0.0

# Push multiplatform image (linux/amd64 and linux/arm64)
./build.sh --multiplatform-push --registry thumbor-azure --tag latest

# Build and test locally first, then push
./build.sh --test  # Test locally
./build.sh --push --registry thumbor-azure --tag latest  # Push to Docker Hub
```

### Pulling from Docker Hub

Once pushed, the image is publicly available:

```bash
# Pull the latest version
docker pull cloudcreatordotio/thumbor-azure:latest

# Pull a specific version
docker pull cloudcreatordotio/thumbor-azure:v1.0.0

# Run directly from Docker Hub
docker run -d \
  --name thumbor-azure \
  -p 8080:80 \
  -e THUMBOR_NUM_PROCESSES=4 \
  -e SECURITY_KEY=your-secure-key \
  cloudcreatordotio/thumbor-azure:latest
```

## Multiplatform Build Support

The build script now supports creating multiplatform Docker images using Docker buildx, enabling seamless development on ARM-based Macs while deploying to linux/amd64 Azure environments.

### Prerequisites

- Docker Desktop with buildx support (included in Docker Desktop 19.03+)
- Azure CLI (for pushing to ACR)

### Build Script Options

#### Standard Options

| Option | Description | Example |
|--------|-------------|---------|
| `--push` | Push to registry (ACR or Docker Hub) | `./build.sh --push --registry myregistry` |
| `--tag <tag>` | Custom tag (default: latest) | `./build.sh --tag v1.0.0` |
| `--registry <name>` | Registry name (use 'thumbor-azure' for Docker Hub) | `./build.sh --registry thumbor-azure` |
| `--test` | Run container locally for testing | `./build.sh --test` |
| `--url <url>` | Test with specific image URL | `./build.sh --test --url https://example.com/image.jpg` |
| `--help` | Show help message | `./build.sh --help` |

#### Image Processing Options (for testing)

| Option | Description | Example |
|--------|-------------|---------|
| `--quality <num>` | JPEG quality (1-100) | `./build.sh --test --quality 85` |
| `--format <fmt>` | Output format (jpeg, png, webp) | `./build.sh --test --format webp` |
| `--maxBytes <num>` | Maximum file size in bytes | `./build.sh --test --maxBytes 500000` |
| `--numBytes <num>` | Target file size in bytes | `./build.sh --test --numBytes 100000` |

#### Multiplatform Options

| Option | Description | Example |
|--------|-------------|---------|
| `--platform <list>` | Target platforms | `./build.sh --platform linux/amd64,linux/arm64` |
| `--multiplatform-push` | Build and push multiplatform | `./build.sh --multiplatform-push --registry myregistry` |
| `--builder <name>` | Use specific buildx builder | `./build.sh --builder custom-builder` |
| `--no-cache` | Build without using cache | `./build.sh --no-cache` |

### Common Use Cases

#### Development on ARM Mac for Azure Deployment

When developing on an ARM-based Mac (Apple Silicon) but deploying to Azure (linux/amd64):

```bash
# For local development (builds for ARM, fast)
./build.sh --test

# For testing Azure compatibility locally
./build.sh --platform linux/amd64 --test

# For deployment to Azure
./build.sh --multiplatform-push --registry myregistry --tag production
```

#### Building for Multiple Platforms

```bash
# Build for both ARM and x86_64
./build.sh --platform linux/amd64,linux/arm64

# Note: Multiple platforms can only be loaded to registry, not local Docker
./build.sh --platform linux/amd64,linux/arm64 --push --registry myregistry
```

#### CI/CD Pipeline Example

```bash
# In your Azure DevOps or GitHub Actions pipeline
./build.sh \
  --multiplatform-push \
  --registry $ACR_NAME \
  --tag $BUILD_NUMBER \
  --no-cache
```

### Docker Buildx Builder Management

The build script automatically manages a dedicated buildx builder named `thumbor-multiplatform`:

```bash
# View the builder status
docker buildx ls | grep thumbor-multiplatform

# Manually remove the builder if needed
docker buildx rm thumbor-multiplatform

# The script will recreate it automatically when needed
./build.sh --platform linux/amd64
```

### Platform-Specific Considerations

#### ARM Development (Apple Silicon Macs)
- Local builds are fast and native
- Use `--platform linux/amd64` to test Azure compatibility
- Container may run slower when emulating x86_64

#### Azure Deployment (linux/amd64)
- Azure Web Apps typically run on linux/amd64
- Use `--multiplatform-push` for production deployments
- Images built on ARM will work seamlessly on Azure

#### Docker Compose Support

For docker-compose deployments, specify the platform in your `docker-compose.yml`:

```yaml
services:
  thumbor:
    build:
      context: .
      dockerfile: Dockerfile
      platform: linux/amd64  # For Azure compatibility
```

## Azure Deployment

### Prerequisites

1. Azure CLI installed and logged in
2. Azure Container Registry (ACR) created
3. Azure Web App for Containers created

### Step 1: Choose Your Registry

You can either push to Azure Container Registry (ACR) or use the public Docker Hub image.

#### Option A: Use Docker Hub Image (Simplest)

```bash
# Pull the pre-built image from Docker Hub
docker pull cloudcreatordotio/thumbor-azure:latest

# Or reference it directly in your Azure deployment
```

#### Option B: Build and Push to ACR (Private Registry)

```bash
# Set your ACR name
ACR_NAME=mycontainerregistry

# Option 1: Build multiplatform image and push directly (RECOMMENDED)
# This ensures compatibility with Azure's linux/amd64 architecture
./build.sh --multiplatform-push --registry $ACR_NAME --tag latest

# Option 2: Build and push single platform
./build.sh --push --registry $ACR_NAME --tag latest

# Option 3: Build specific platform and push
./build.sh --platform linux/amd64 --push --registry $ACR_NAME --tag latest

# Or manually (without multiplatform support):
# Login to ACR
az acr login --name $ACR_NAME

# Build the image
docker build -t thumbor-azure:latest .

# Tag for ACR
docker tag thumbor-azure:latest $ACR_NAME.azurecr.io/thumbor-azure:latest

# Push to ACR
docker push $ACR_NAME.azurecr.io/thumbor-azure:latest
```

#### Cross-Platform Development Note

If you're developing on an ARM-based Mac (Apple Silicon) and deploying to Azure:
- Use `--multiplatform-push` to ensure the image works on Azure's linux/amd64 architecture
- Or explicitly specify `--platform linux/amd64` when building for Azure
- The multiplatform approach ensures compatibility across different architectures

### Step 2: Deploy to Azure Web App

#### Deploy from Docker Hub

```bash
# Set variables
RESOURCE_GROUP=myresourcegroup
WEBAPP_NAME=my-thumbor-app

# Create Web App with Docker Hub image
az webapp create \
  --resource-group $RESOURCE_GROUP \
  --plan myappserviceplan \
  --name $WEBAPP_NAME \
  --deployment-container-image-name cloudcreatordotio/thumbor-azure:latest

# Configure the Web App
az webapp config container set \
  --name $WEBAPP_NAME \
  --resource-group $RESOURCE_GROUP \
  --docker-custom-image-name cloudcreatordotio/thumbor-azure:latest
```

#### Deploy from Azure Container Registry

```bash
# Set variables
RESOURCE_GROUP=myresourcegroup
WEBAPP_NAME=my-thumbor-app
ACR_NAME=mycontainerregistry

# Create Web App (if not exists)
az webapp create \
  --resource-group $RESOURCE_GROUP \
  --plan myappserviceplan \
  --name $WEBAPP_NAME \
  --deployment-container-image-name $ACR_NAME.azurecr.io/thumbor-azure:latest

# Configure ACR credentials
az webapp config container set \
  --name $WEBAPP_NAME \
  --resource-group $RESOURCE_GROUP \
  --docker-custom-image-name $ACR_NAME.azurecr.io/thumbor-azure:latest \
  --docker-registry-server-url https://$ACR_NAME.azurecr.io \
  --docker-registry-server-user $(az acr credential show --name $ACR_NAME --query username -o tsv) \
  --docker-registry-server-password $(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)
```

#### Configure Environment Variables (Both Docker Hub and ACR)

```bash
# Set environment variables
az webapp config appsettings set \
  --resource-group $RESOURCE_GROUP \
  --name $WEBAPP_NAME \
  --settings \
    SECURITY_KEY="your-very-secure-random-key" \
    ALLOW_UNSAFE_URL="False" \
    THUMBOR_NUM_PROCESSES="4" \
    AUTO_WEBP="True" \
    CORS_ALLOW_ORIGIN="*" \
    THUMBOR_PROXY_CACHE_SIZE="100g" \
    THUMBOR_PROXY_CACHE_MEMORY_SIZE="1024m"
```

### Step 3: Configure Persistent Storage (Optional)

For persistent cache storage, mount Azure Storage:

```bash
# Create storage account
az storage account create \
  --name mythumborstorage \
  --resource-group $RESOURCE_GROUP \
  --sku Standard_LRS

# Create file share
az storage share create \
  --name thumbor-cache \
  --account-name mythumborstorage

# Mount to Web App
az webapp config storage-account add \
  --resource-group $RESOURCE_GROUP \
  --name $WEBAPP_NAME \
  --custom-id ThumboreCache \
  --storage-type AzureFiles \
  --share-name thumbor-cache \
  --account-name mythumborstorage \
  --mount-path /var/cache/nginx \
  --access-key $(az storage account keys list --account-name mythumborstorage --query [0].value -o tsv)
```

## Configuration

### Environment Variables

All configuration is done through environment variables. See `.env.azure` for the complete list.

Key variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `SECURITY_KEY` | Secret key for URL signing | CHANGE_THIS |
| `ALLOW_UNSAFE_URL` | Allow unsigned URLs | False |
| `THUMBOR_NUM_PROCESSES` | Number of Thumbor workers | 4 |
| `AUTO_WEBP` | Auto-convert to WebP | True |
| `CORS_ALLOW_ORIGIN` | CORS allowed origins | * |
| `THUMBOR_PROXY_CACHE_SIZE` | Nginx cache size | 100g |

### URL Signing

For production, always use signed URLs:

```python
import hashlib
import base64

def generate_thumbor_url(security_key, image_url, width, height):
    # Example URL generator
    path = f"{width}x{height}/smart/{image_url}"
    hash = hashlib.md5((security_key + path).encode()).digest()
    signature = base64.urlsafe_b64encode(hash).decode().strip("=")
    return f"/{signature}/{path}"
```

## Performance Tuning

### For High Traffic

```bash
# Increase workers and cache
az webapp config appsettings set \
  --resource-group $RESOURCE_GROUP \
  --name $WEBAPP_NAME \
  --settings \
    THUMBOR_NUM_PROCESSES="8" \
    ENGINE_THREADPOOL_SIZE="20" \
    HTTP_LOADER_MAX_CONN_PER_HOST="50" \
    THUMBOR_PROXY_CACHE_MEMORY_SIZE="2048m"
```

### Scaling

```bash
# Enable autoscaling
az monitor autoscale create \
  --resource-group $RESOURCE_GROUP \
  --resource $WEBAPP_NAME \
  --resource-type Microsoft.Web/serverFarms \
  --min-count 1 \
  --max-count 10 \
  --count 2

# Add CPU-based rule
az monitor autoscale rule create \
  --resource-group $RESOURCE_GROUP \
  --autoscale-name my-autoscale \
  --condition "Percentage CPU > 70 avg 5m" \
  --scale out 1
```

## Monitoring

### Application Insights

```bash
# Enable Application Insights
az webapp config appsettings set \
  --resource-group $RESOURCE_GROUP \
  --name $WEBAPP_NAME \
  --settings APPINSIGHTS_INSTRUMENTATIONKEY="your-key"
```

### View Logs

```bash
# Stream logs
az webapp log tail \
  --resource-group $RESOURCE_GROUP \
  --name $WEBAPP_NAME

# Download logs
az webapp log download \
  --resource-group $RESOURCE_GROUP \
  --name $WEBAPP_NAME \
  --log-file logs.zip
```

### Health Checks

- Health endpoint: `https://your-app.azurewebsites.net/healthcheck`
- Nginx status: `https://your-app.azurewebsites.net/nginx-status`

## Redis Admin Interface

The container includes a built-in web-based Redis administration interface for managing and monitoring the Redis instance.

** ***commented out in the NGINX conf by default. Enable by uncommenting in the NGINX conf and rebuilding the image.*** **


### Accessing Redis Admin

| Environment | URL |
|-------------|-----|
| **Local Development** | `http://localhost:8080/redis-admin` |
| **Azure Web App** | `https://your-app.azurewebsites.net/redis-admin` |
| **Docker (Custom Port)** | `http://localhost:[PORT]/redis-admin` |

### Features

- **Dashboard**: Real-time Redis statistics, memory usage, and connected clients
- **Key Browser**: Search and manage keys with pattern matching
- **Command Executor**: Execute Redis commands directly from the web interface
- **Key Editor**: Create and modify keys with JSON support
- **TTL Management**: Set and modify key expiration times
- **Danger Zone**: Database flush operations (use with caution!)

### Security

For production environments, enable basic authentication:

```bash
# SSH into Azure Web App
az webapp ssh --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP

# Run authentication setup
/app/setup_redis_admin_auth.sh

# Follow prompts to set username and password
# Restart nginx to apply changes
supervisorctl restart nginx
```

For Azure deployments, also consider:
- Using App Service access restrictions to limit Redis Admin access
- Implementing Azure Private Endpoints for network isolation
- Setting up Azure AD authentication for the Web App

### Documentation

For detailed documentation on Redis Admin features and configuration, see [REDIS_ADMIN_README.md](./REDIS_ADMIN_README.md).

## Redis Storage Configuration

### Understanding Redis Usage in Thumbor

This Thumbor implementation uses a **mixed storage** approach where Redis is used selectively for specific operations:

#### Storage Types by Operation

| Operation Type | Storage Location | Redis Activity |
|---------------|-----------------|----------------|
| **Regular Image Operations** | File Storage | ❌ No |
| **Detection Results** | Redis | ✅ Yes |
| **Processed Images Cache** | None (generated on-demand) | ❌ No |

#### Operations That DO NOT Use Redis

Regular image transformations are processed on-the-fly and don't interact with Redis:
- `/unsafe/fit-in/...` - Basic resize operations
- `/unsafe/300x200/...` - Fixed dimension resizing
- `/unsafe/crop/...` - Manual cropping
- Standard filters (blur, brightness, contrast, etc.)

#### Operations That USE Redis

Detection-based operations store their results in Redis for caching:
- `/unsafe/.../smart/...` - Smart cropping (face/feature detection)
- `/unsafe/.../filters:face()/...` - Face detection
- `/unsafe/.../filters:focal()/...` - Focal point detection

#### Example Redis Detection Storage

When requesting a smart crop:
```
http://localhost:8080/unsafe/300x300/smart/media.mywebsitename.com/cdn/path/to/image/image.png
```

Redis stores the detection results with key:
```
thumbor-detector-media.mywebsitename.com/cdn/path/to/image/image.png
```

Containing focal points and regions data:
```json
[
  {"x": 284.5, "y": 142.5, "height": 285, "width": 285, "z": 81225},
  {"x": 246.0, "y": 111.0, "height": 46, "width": 46, "z": 2116}
]
```

#### Monitoring Redis Activity

To see Redis activity in real-time:

```bash
# Terminal 1 - Monitor Redis
docker exec thumbor-dev redis-cli monitor

# Terminal 2 - Make a SMART request (will show Redis activity)
curl "http://localhost:8080/unsafe/300x300/smart/your-image-url"

# Terminal 2 - Make a FIT-IN request (won't show Redis activity)
curl "http://localhost:8080/unsafe/fit-in/300x300/your-image-url"
```

#### Configuration Details

The storage configuration in `thumbor.conf`:
```python
# Mixed storage configuration
Config.STORAGE = 'thumbor.storages.mixed_storage'
Config.MIXED_STORAGE_FILE_STORAGE = 'thumbor.storages.file_storage'
Config.MIXED_STORAGE_DETECTOR_STORAGE = 'tc_redis.storages.redis_storage'

# No result caching (images generated on-demand)
Config.RESULT_STORAGE = 'thumbor.result_storages.no_storage'
```

This configuration optimizes performance by:
- Caching expensive detection operations in Redis
- Serving regular transformations directly without Redis overhead
- Reducing Redis memory usage by not storing processed images

### Documentation

For detailed documentation on Redis Admin features and configuration, see [REDIS_ADMIN_README.md](./REDIS_ADMIN_README.md).

## CDN Integration

For better performance, use Azure CDN:

```bash
# Create CDN profile
az cdn profile create \
  --resource-group $RESOURCE_GROUP \
  --name mycdnprofile \
  --sku Standard_Microsoft

# Create CDN endpoint
az cdn endpoint create \
  --resource-group $RESOURCE_GROUP \
  --profile-name mycdnprofile \
  --name mycdnendpoint \
  --origin $WEBAPP_NAME.azurewebsites.net \
  --origin-host-header $WEBAPP_NAME.azurewebsites.net
```

## Troubleshooting

### Container won't start

1. Check logs: `az webapp log tail --resource-group $RESOURCE_GROUP --name $WEBAPP_NAME`
2. Verify environment variables are set correctly
3. Ensure the container image is accessible from ACR

### Images not loading

1. Check ALLOWED_SOURCES configuration
2. Verify CORS settings if loading from different domain
3. Check Nginx cache permissions

### Performance issues

1. Increase THUMBOR_NUM_PROCESSES
2. Scale up the App Service Plan
3. Enable Application Insights for detailed metrics

### Multiplatform build issues

#### "Cannot load multiple platforms locally" error
- This occurs when trying to load multiple platforms to local Docker
- Solution: Use `--push` to push to a registry instead, or build for a single platform

#### Build fails on different architecture
- Ensure all base images support your target platforms
- The Ubuntu 22.04 base image supports both linux/amd64 and linux/arm64

#### Slow performance when emulating different architecture
- Running linux/amd64 containers on ARM Macs uses emulation
- This is normal and only affects local testing, not production performance

#### Buildx builder not found
- The script automatically creates the builder if it doesn't exist
- To manually create: `docker buildx create --name thumbor-multiplatform --use`
- To remove and recreate: `docker buildx rm thumbor-multiplatform`

## Migration from Multi-Container Setup

This single container replaces the previous multi-container setup with these mappings:

| Old Service | New Implementation | Notes |
|-------------|-------------------|-------|
| thumbor:6.7.5 | thumbor:7.7.7 | Upgraded version |
| nginx-proxy | Internal Nginx | Integrated caching |
| remotecv | Internal RemoteCV | Same functionality |
| External Redis | Internal Redis | No external dependency |

### Host Mappings

The previous `extra_hosts` entries should be handled via:
1. Azure Private Endpoints for internal resources
2. Azure DNS for custom domain resolution
3. Application Gateway for advanced routing

## Security Best Practices

1. **Always use signed URLs in production** - Set `ALLOW_UNSAFE_URL=False`
2. **Use strong security keys** - Generate with `openssl rand -hex 32`
3. **Restrict ALLOWED_SOURCES** - Only allow your domains
4. **Enable HTTPS only** - Configure in Azure Portal
5. **Use managed identity** - For ACR authentication
6. **Regular updates** - Rebuild container with latest security patches

## Support

For issues or questions:
1. Check container logs: `docker logs <container-id>`
2. Review Azure Web App diagnostics
3. Check Thumbor documentation: https://thumbor.readthedocs.io
4. Review Azure documentation: https://docs.microsoft.com/azure/app-service/

## License

This implementation uses open-source components:
- Thumbor: MIT License
- Nginx: 2-clause BSD License
- Redis: BSD License
- RemoteCV: MIT License
