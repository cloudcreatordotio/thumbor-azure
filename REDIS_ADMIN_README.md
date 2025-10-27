# Redis Admin Interface for Thumbor Container

## Overview

This container now includes a lightweight Redis Admin web interface for managing and monitoring the Redis instance used by Thumbor.

## Accessing Redis Admin

### Quick Reference URLs

| Environment | URL Format | Example |
|-------------|------------|---------|
| **Local Docker** | `http://localhost:8080/redis-admin` | `http://localhost:8080/redis-admin` |
| **Azure Web App** | `https://{app-name}.azurewebsites.net/redis-admin` | `https://myapp.azurewebsites.net/redis-admin` |
| **Azure with Custom Domain** | `https://{custom-domain}/redis-admin` | `https://images.example.com/redis-admin` |
| **Docker (Custom Port)** | `http://localhost:{port}/redis-admin` | `http://localhost:8888/redis-admin` |
| **Your Instance** | `http://20.119.144.5/redis-admin` | Direct IP access |

## Features

### 1. Dashboard
- Real-time Redis server statistics
- Memory usage monitoring
- Connected clients count
- Total keys in database

### 2. Key Browser
- Search keys using patterns (e.g., `*`, `user:*`, `*cache*`)
- View key types (string, list, set, hash, zset)
- Quick view and delete options
- Support for up to 100 keys per search

### 3. Command Executor
- Execute any Redis command directly
- View formatted results
- Support for all Redis commands

### 4. Key Editor
- Set new key-value pairs
- Support for JSON objects (automatically converts to hash)
- Support for arrays (automatically converts to list)
- TTL (Time To Live) support

### 5. Danger Zone
- Flush current database
- Flush all databases
- Use with extreme caution!

## Azure Deployment

### Accessing Redis Admin in Azure Web Apps

1. **Direct Access via Web App URL**:
   ```bash
   # Your Redis Admin will be available at:
   https://your-app-name.azurewebsites.net/redis-admin
   ```

2. **Using Azure CLI for Management**:
   ```bash
   # SSH into the container
   az webapp ssh --name YOUR-APP-NAME --resource-group YOUR-RG

   # Check Redis Admin service status
   supervisorctl status redis-admin

   # View Redis Admin logs
   tail -f /app/logs/redis-admin.log

   # Access Redis CLI directly
   redis-cli
   ```

3. **Setting Environment Variables in Azure**:
   ```bash
   # Configure Redis Admin settings
   az webapp config appsettings set \
     --name YOUR-APP-NAME \
     --resource-group YOUR-RG \
     --settings \
       REDIS_ADMIN_PORT=8888 \
       REDIS_ADMIN_DEBUG=false \
       REDIS_ADMIN_SAFE_MODE=true
   ```

### Azure-Specific Security Configuration

1. **App Service Access Restrictions**:
   ```bash
   # Restrict Redis Admin to specific IP addresses
   az webapp config access-restriction add \
     --name YOUR-APP-NAME \
     --resource-group YOUR-RG \
     --rule-name "Redis Admin Access" \
     --action Allow \
     --ip-address YOUR.IP.ADDRESS/32 \
     --priority 100 \
     --scm-site false \
     --path "/redis-admin/*"
   ```

2. **Azure AD Authentication** (for the entire Web App):
   ```bash
   # Enable Azure AD authentication
   az webapp auth update \
     --name YOUR-APP-NAME \
     --resource-group YOUR-RG \
     --enabled true \
     --action LoginWithAzureActiveDirectory
   ```

3. **Using Private Endpoints**:
   ```bash
   # Create a private endpoint for secure access
   az network private-endpoint create \
     --name YOUR-PRIVATE-ENDPOINT \
     --resource-group YOUR-RG \
     --vnet-name YOUR-VNET \
     --subnet YOUR-SUBNET \
     --connection-name YOUR-CONNECTION \
     --private-connection-resource-id /subscriptions/.../YOUR-WEBAPP \
     --group-id sites
   ```

## Security

### Basic Authentication Setup

For production environments, it's recommended to enable basic authentication:

1. **SSH into your container**:
   ```bash
   # For Azure App Service
   az webapp ssh --name YOUR-APP-NAME --resource-group YOUR-RG
   ```

2. **Run the authentication setup script**:
   ```bash
   /app/setup_redis_admin_auth.sh
   ```

3. **Follow the prompts** to set username and password

4. **Restart nginx** to apply changes:
   ```bash
   supervisorctl restart nginx
   ```

### Manual Authentication Setup

If you prefer to set up authentication manually:

1. Create htpasswd file:
   ```bash
   htpasswd -bc /etc/nginx/.htpasswd admin YOUR_PASSWORD
   ```

2. Uncomment auth lines in `/etc/nginx/nginx.conf`:
   ```nginx
   auth_basic "Redis Admin Access";
   auth_basic_user_file /etc/nginx/.htpasswd;
   ```

3. Reload nginx:
   ```bash
   supervisorctl restart nginx
   ```

## Environment Variables

The Redis Admin interface respects these environment variables:

- `REDIS_SERVER_HOST`: Redis server hostname (default: localhost)
- `REDIS_SERVER_PORT`: Redis server port (default: 6379)
- `REDIS_SERVER_DB`: Redis database number (default: 0)
- `REDIS_ADMIN_PORT`: Port for Redis Admin service (default: 8888)
- `REDIS_ADMIN_DEBUG`: Enable Flask debug mode (default: false)
- `REDIS_ADMIN_SAFE_MODE`: Block dangerous commands (default: false)

## Monitoring

### Health Check Endpoint
- URL: `/redis-admin/health`
- Returns JSON with Redis connection status

### Logs
- Application logs: `/app/logs/redis-admin.log`
- Error logs: `/app/logs/redis-admin-error.log`

View logs:
```bash
tail -f /app/logs/redis-admin.log
```

## Service Management

The Redis Admin service is managed by supervisord:

```bash
# Check status
supervisorctl status redis-admin

# Restart service
supervisorctl restart redis-admin

# Stop service
supervisorctl stop redis-admin

# Start service
supervisorctl start redis-admin
```

## Common Redis Commands

Here are some useful Redis commands you can execute through the interface:

- `INFO server` - Get server information
- `INFO memory` - Get memory statistics
- `DBSIZE` - Get total number of keys
- `KEYS *` - List all keys (use patterns for filtering)
- `GET key` - Get value of a key
- `SET key value` - Set a key-value pair
- `DEL key` - Delete a key
- `TTL key` - Get remaining TTL of a key
- `EXPIRE key seconds` - Set expiration on a key
- `FLUSHDB` - Clear current database
- `FLUSHALL` - Clear all databases

## Troubleshooting

### Redis Admin not accessible

#### Local Development
1. Check if service is running:
   ```bash
   docker-compose exec thumbor supervisorctl status redis-admin
   ```

2. Check logs for errors:
   ```bash
   docker-compose exec thumbor tail -n 50 /app/logs/redis-admin-error.log
   ```

3. Test Redis connectivity:
   ```bash
   docker-compose exec thumbor redis-cli ping
   ```

#### Azure Web App
1. SSH into container and check service:
   ```bash
   az webapp ssh --name YOUR-APP-NAME --resource-group YOUR-RG
   supervisorctl status redis-admin
   ```

2. Stream Azure Web App logs:
   ```bash
   az webapp log tail --name YOUR-APP-NAME --resource-group YOUR-RG
   ```

3. Download diagnostic logs:
   ```bash
   az webapp log download \
     --name YOUR-APP-NAME \
     --resource-group YOUR-RG \
     --log-file redis-logs.zip
   ```

4. Check App Service health:
   ```bash
   az webapp show --name YOUR-APP-NAME --resource-group YOUR-RG --query state
   ```

### Authentication issues

1. Verify htpasswd file exists:
   ```bash
   ls -la /etc/nginx/.htpasswd
   ```

2. Check nginx configuration:
   ```bash
   nginx -t
   ```

3. Reload nginx if needed:
   ```bash
   supervisorctl restart nginx
   ```

## Performance Considerations

- The interface uses Redis SCAN instead of KEYS for better performance
- Limited to 100 keys per search to prevent performance issues
- Caching is disabled for the admin interface to show real-time data
- Uses connection pooling for efficient Redis connections

## Support

For issues or questions about the Redis Admin interface, check:
- Application logs in `/app/logs/`
- Supervisord status with `supervisorctl status`
- Redis connectivity with `redis-cli ping`