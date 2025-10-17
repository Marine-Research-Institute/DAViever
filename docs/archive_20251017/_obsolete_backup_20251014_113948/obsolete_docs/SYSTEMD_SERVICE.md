# MARBEFES BBT Database - Systemd Service Configuration

## Quick Setup

To set up the MARBEFES Flask application as a systemd service:

```bash
# Run the automated setup script
./setup_systemd_service.sh
```

This script will:
- ✅ Check system requirements
- ✅ Test Flask application
- ✅ Generate customized service files
- ✅ Install and configure the systemd service
- ✅ Set up proper permissions and security

## Manual Installation

If you prefer manual setup, here are the service files ready for your system:

### Development Service (Flask Development Server)

**File:** `flaskapp.service` - Uses Flask's built-in development server

### Production Service (Gunicorn)

**File:** `flaskapp-gunicorn.service` - Uses Gunicorn with 4 workers for production

### Installation Steps

1. **Copy service file to systemd directory:**
```bash
sudo cp flaskapp-gunicorn.service /etc/systemd/system/flaskapp.service
```

2. **Update paths in the service file:**
Edit `/etc/systemd/system/flaskapp.service` and update:
- `User=razinka` → `User=YOUR_USERNAME`
- `WorkingDirectory=...` → Your actual project path
- `Environment=PATH=...` → Your actual venv path
- `ExecStart=...` → Your actual venv path

3. **Reload systemd and enable service:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable flaskapp.service
sudo systemctl start flaskapp.service
```

## Service Management Commands

### Basic Operations
```bash
# Start the service
sudo systemctl start flaskapp

# Stop the service
sudo systemctl stop flaskapp

# Restart the service
sudo systemctl restart flaskapp

# Reload configuration (graceful restart)
sudo systemctl reload flaskapp

# Check service status
sudo systemctl status flaskapp
```

### Enable/Disable Auto-start
```bash
# Enable service to start on boot
sudo systemctl enable flaskapp

# Disable service from starting on boot
sudo systemctl disable flaskapp

# Check if service is enabled
sudo systemctl is-enabled flaskapp
```

### Monitoring and Logs
```bash
# View live logs
sudo journalctl -u flaskapp -f

# View recent logs
sudo journalctl -u flaskapp --since "1 hour ago"

# View logs with timestamps
sudo journalctl -u flaskapp -o short-iso

# View application logs (if file logging is enabled)
tail -f /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/logs/app.log
```

## Service Configuration Details

### Key Features

**Security:**
- Runs as non-root user (`razinka`)
- Restricted file system access
- Private temporary directory
- No new privileges allowed

**Performance:**
- Production service uses 4 Gunicorn workers
- File descriptor limits: 65536
- Process limits: 4096
- Automatic restart on failure

**Monitoring:**
- Logs to systemd journal
- Application logs to file
- Health checks before startup

### Environment Variables

The service sets these environment variables:

```bash
FLASK_APP=app.py
FLASK_ENV=production          # or development
FLASK_DEBUG=0                # or 1 for development
HOST=0.0.0.0
PORT=5000
WMS_BASE_URL=https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms
HELCOM_WMS_BASE_URL=https://maps.helcom.fi/arcgis/services/MADS/Pressures/MapServer/WMSServer
WMS_TIMEOUT=30
VECTOR_DATA_DIR=data/vector
LOG_LEVEL=INFO
LOG_FILE=logs/app.log
SECRET_KEY=your-production-secret-key-change-this
```

### Customization

To modify the service configuration:

1. **Edit the service file:**
```bash
sudo systemctl edit flaskapp
```

2. **Or edit directly (not recommended):**
```bash
sudo vim /etc/systemd/system/flaskapp.service
```

3. **Reload after changes:**
```bash
sudo systemctl daemon-reload
sudo systemctl restart flaskapp
```

## Troubleshooting

### Service Won't Start

1. **Check service status:**
```bash
sudo systemctl status flaskapp
```

2. **Check detailed logs:**
```bash
sudo journalctl -u flaskapp --no-pager -l
```

3. **Test manual startup:**
```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck
source venv/bin/activate
python run_flask.py
```

### Common Issues

#### Permission Errors
```bash
# Fix ownership
sudo chown -R razinka:razinka /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck

# Fix permissions
chmod -R 755 venv/ logs/ data/
```

#### Port Already in Use
```bash
# Find what's using port 5000
sudo lsof -i :5000

# Change port in service file
sudo systemctl edit flaskapp
# Add:
# [Service]
# Environment=PORT=5001
```

#### Python Module Import Errors
```bash
# Check virtual environment
source venv/bin/activate
python -c "import flask, requests, geopandas"

# Reinstall dependencies if needed
pip install -r requirements-venv.txt
```

### Performance Monitoring

```bash
# Check service resource usage
systemd-cgtop

# Check specific service resources
systemctl show flaskapp --property=MemoryCurrent,CPUUsageNSec

# Monitor in real-time
watch -n 1 'systemctl status flaskapp'
```

## Security Considerations

### Service Security Features

The systemd service includes several security hardening measures:

- **NoNewPrivileges=true** - Prevents privilege escalation
- **PrivateTmp=true** - Isolated temporary directory
- **ProtectSystem=strict** - Read-only access to system directories
- **ProtectHome=false** - Access only to application directory
- **ReadWritePaths** - Explicit write permissions only where needed

### Additional Security

For production deployments, consider:

1. **Firewall configuration:**
```bash
sudo ufw allow 5000/tcp
sudo ufw enable
```

2. **Reverse proxy (nginx/apache)** for HTTPS termination

3. **Log rotation:**
```bash
sudo vim /etc/logrotate.d/marbefes
```

4. **Monitoring and alerting** for service health

## Integration with Web Servers

### Nginx Configuration

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Apache Configuration

```apache
<VirtualHost *:80>
    ServerName your-domain.com

    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:5000/
    ProxyPassReverse / http://127.0.0.1:5000/
</VirtualHost>
```

## Service File Templates

### Development Template
- Single worker Flask development server
- Debug mode enabled
- Detailed logging
- Quick restart for development

### Production Template
- Multi-worker Gunicorn server
- Production optimizations
- Security hardening
- Performance monitoring

Both templates are automatically customized by the setup script for your specific system paths and user configuration.

---

**Quick Command Reference:**

```bash
# Setup service
./setup_systemd_service.sh

# Common operations
sudo systemctl start flaskapp
sudo systemctl status flaskapp
sudo journalctl -u flaskapp -f

# Service management
sudo systemctl enable flaskapp    # Auto-start
sudo systemctl disable flaskapp   # No auto-start
sudo systemctl restart flaskapp   # Restart service
```