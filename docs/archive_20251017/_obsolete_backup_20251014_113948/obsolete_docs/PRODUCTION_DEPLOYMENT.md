# MARBEFES BBT Database - Production Deployment Guide

## Quick Start

### Automated Deployment (Recommended)

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck
sudo ./deploy_production.sh
```

This single script will:
- ✓ Copy application to `/var/www/marbefes-bbt/`
- ✓ Create and configure Python virtual environment
- ✓ Install all dependencies including Gunicorn
- ✓ Generate production `.env` file with secure secret key
- ✓ Create Gunicorn configuration
- ✓ Setup systemd service
- ✓ Configure nginx reverse proxy
- ✓ Start all services

---

## Manual Deployment Steps

If you prefer manual deployment or need to troubleshoot:

### 1. Create Production Directory

```bash
sudo mkdir -p /var/www/marbefes-bbt
cd /var/www/marbefes-bbt
```

### 2. Copy Application Files

```bash
sudo rsync -av \
    --exclude='venv' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.git' \
    --exclude='logs/*' \
    /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/ \
    /var/www/marbefes-bbt/
```

### 3. Create Virtual Environment

```bash
cd /var/www/marbefes-bbt
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --upgrade pip wheel setuptools
pip install -r requirements-prod.txt
pip install gunicorn

deactivate
```

### 4. Create Production Environment File

Create `/var/www/marbefes-bbt/.env`:

```bash
FLASK_ENV=production
FLASK_DEBUG=False
SECRET_KEY=<generate-with-openssl-rand-hex-32>

FLASK_HOST=127.0.0.1
FLASK_RUN_PORT=5000

WMS_BASE_URL=https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms
WMS_VERSION=1.3.0
WMS_TIMEOUT=10

CACHE_TYPE=SimpleCache
CACHE_DEFAULT_TIMEOUT=300

LOG_LEVEL=INFO
LOG_FILE=logs/marbefes-bbt.log

ENABLE_HSTS=True
```

Generate secret key:
```bash
openssl rand -hex 32
```

### 5. Create Gunicorn Configuration

The automated script creates `/var/www/marbefes-bbt/gunicorn_config.py` with optimal settings:
- Workers: CPU cores × 2 + 1
- Timeout: 120s (for WMS requests)
- Logging to `logs/gunicorn-*.log`

### 6. Create Systemd Service

Create `/etc/systemd/system/marbefes-bbt.service`:

```ini
[Unit]
Description=MARBEFES BBT Database - Marine Biodiversity Flask Application
After=network.target

[Service]
Type=notify
User=www-data
Group=www-data
WorkingDirectory=/var/www/marbefes-bbt
Environment="PATH=/var/www/marbefes-bbt/venv/bin"
EnvironmentFile=/var/www/marbefes-bbt/.env

ExecStart=/var/www/marbefes-bbt/venv/bin/gunicorn \
    --config /var/www/marbefes-bbt/gunicorn_config.py \
    --bind 127.0.0.1:5000 \
    app:app

Restart=always
RestartSec=10

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/var/www/marbefes-bbt/logs

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable marbefes-bbt
sudo systemctl start marbefes-bbt
sudo systemctl status marbefes-bbt
```

### 7. Configure Nginx

Create `/etc/nginx/sites-available/marbefes-bbt`:

```nginx
upstream marbefes_bbt {
    server 127.0.0.1:5000 fail_timeout=0;
}

server {
    listen 80;
    server_name bbt.marbefes.eu www.bbt.marbefes.eu;

    client_max_body_size 10M;

    access_log /var/log/nginx/marbefes-bbt-access.log;
    error_log /var/log/nginx/marbefes-bbt-error.log;

    location / {
        proxy_pass http://marbefes_bbt;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 120s;
        proxy_read_timeout 120s;
    }

    location /logo/ {
        alias /var/www/marbefes-bbt/LOGO/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
}
```

Enable and test:
```bash
sudo ln -s /etc/nginx/sites-available/marbefes-bbt /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 8. Set Permissions

```bash
sudo chown -R www-data:www-data /var/www/marbefes-bbt
sudo chmod 755 /var/www/marbefes-bbt
sudo chmod 644 /var/www/marbefes-bbt/.env
```

---

## Post-Deployment

### Verification

```bash
# Check service status
sudo systemctl status marbefes-bbt

# View application logs
sudo journalctl -u marbefes-bbt -f

# View nginx logs
sudo tail -f /var/log/nginx/marbefes-bbt-access.log
sudo tail -f /var/log/nginx/marbefes-bbt-error.log

# View Gunicorn logs
sudo tail -f /var/www/marbefes-bbt/logs/gunicorn-error.log

# Test application
curl -I http://localhost
curl http://localhost/api/layers
```

### SSL Certificate Setup (Let's Encrypt)

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d bbt.marbefes.eu -d www.bbt.marbefes.eu

# Auto-renewal is configured automatically
sudo certbot renew --dry-run
```

### Monitoring Commands

```bash
# Service status
sudo systemctl status marbefes-bbt

# Restart service
sudo systemctl restart marbefes-bbt

# View real-time logs
sudo journalctl -u marbefes-bbt -f --lines=100

# Check nginx error logs
sudo tail -f /var/log/nginx/marbefes-bbt-error.log

# Check application performance
curl -w "@-" -o /dev/null -s http://localhost/api/layers <<'EOF'
    time_namelookup:  %{time_namelookup}\n
       time_connect:  %{time_connect}\n
    time_appconnect:  %{time_appconnect}\n
      time_redirect:  %{time_redirect}\n
 time_starttransfer:  %{time_starttransfer}\n
                    ----------\n
         time_total:  %{time_total}\n
EOF
```

---

## Architecture

```
┌─────────────┐
│   Internet  │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────┐
│  Nginx (Port 80/443)        │
│  - SSL Termination          │
│  - Reverse Proxy            │
│  - Static File Serving      │
│  - Gzip Compression         │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│  Gunicorn (Port 5000)       │
│  - WSGI Server              │
│  - Multiple Workers         │
│  - Process Management       │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│  Flask Application          │
│  - WMS Layer Integration    │
│  - Vector Data Processing   │
│  - API Endpoints            │
└─────────────────────────────┘
```

---

## Key Features

### Production Optimizations

1. **Gunicorn WSGI Server**
   - Multi-worker process model
   - Automatic worker recycling
   - Graceful restarts
   - Request timeout handling

2. **Nginx Reverse Proxy**
   - Static file serving (logos, assets)
   - Gzip compression
   - SSL/TLS termination
   - Security headers
   - Load balancing ready

3. **Systemd Service**
   - Automatic startup on boot
   - Automatic restart on failure
   - Process isolation
   - Resource limits
   - Security hardening

4. **Security Enhancements**
   - HTTPS support (after SSL setup)
   - Security headers (HSTS, CSP, etc.)
   - Process isolation
   - File system restrictions
   - No new privileges

### Performance Features

- **Caching**: Flask-Caching with configurable timeout
- **Gzip Compression**: Text and JSON compression
- **Static File Caching**: 1-year browser cache for static assets
- **Worker Scaling**: Automatic based on CPU cores
- **Connection Pooling**: Upstream connection management

---

## Troubleshooting

### Service Won't Start

```bash
# Check detailed logs
sudo journalctl -u marbefes-bbt -n 50 --no-pager

# Test Gunicorn directly
cd /var/www/marbefes-bbt
source venv/bin/activate
gunicorn --config gunicorn_config.py app:app
```

### Port Already in Use

```bash
# Find process using port 5000
sudo lsof -i :5000

# Kill if necessary
sudo kill -9 <PID>
```

### Permission Errors

```bash
# Reset permissions
sudo chown -R www-data:www-data /var/www/marbefes-bbt
sudo chmod -R 755 /var/www/marbefes-bbt
sudo chmod 644 /var/www/marbefes-bbt/.env
```

### Nginx Configuration Errors

```bash
# Test configuration
sudo nginx -t

# Check error log
sudo tail -f /var/log/nginx/error.log
```

### Vector Layers Not Loading

```bash
# Check GPKG files
ls -lh /var/www/marbefes-bbt/data/vector/*.gpkg

# Test vector loading
cd /var/www/marbefes-bbt
source venv/bin/activate
python -c "from src.emodnet_viewer.utils.vector_loader import vector_loader; print(vector_loader.load_all_vector_layers())"
```

---

## Maintenance

### Update Application

```bash
# Pull latest changes
cd /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck
git pull  # if using git

# Re-run deployment
sudo ./deploy_production.sh

# Or manually sync
sudo rsync -av --exclude='venv' --exclude='logs' \
    /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/ \
    /var/www/marbefes-bbt/

# Restart service
sudo systemctl restart marbefes-bbt
```

### Log Rotation

Systemd automatically handles journal rotation, but for application logs:

Create `/etc/logrotate.d/marbefes-bbt`:

```
/var/www/marbefes-bbt/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    missingok
    create 0644 www-data www-data
    postrotate
        systemctl reload marbefes-bbt > /dev/null 2>&1 || true
    endscript
}
```

### Backup Important Files

```bash
# Backup configuration
sudo tar -czf /backup/marbefes-bbt-config-$(date +%Y%m%d).tar.gz \
    /var/www/marbefes-bbt/.env \
    /etc/systemd/system/marbefes-bbt.service \
    /etc/nginx/sites-available/marbefes-bbt

# Backup data
sudo tar -czf /backup/marbefes-bbt-data-$(date +%Y%m%d).tar.gz \
    /var/www/marbefes-bbt/data/
```

---

## Files Created by Deployment Script

| File | Purpose |
|------|---------|
| `/var/www/marbefes-bbt/` | Application root directory |
| `/var/www/marbefes-bbt/.env` | Production environment variables |
| `/var/www/marbefes-bbt/gunicorn_config.py` | Gunicorn WSGI server config |
| `/var/www/marbefes-bbt/venv/` | Python virtual environment |
| `/var/www/marbefes-bbt/logs/` | Application and Gunicorn logs |
| `/etc/systemd/system/marbefes-bbt.service` | Systemd service definition |
| `/etc/nginx/sites-available/marbefes-bbt` | Nginx configuration |
| `/etc/nginx/sites-enabled/marbefes-bbt` | Symlink to enable nginx site |

---

## Quick Reference

### Essential Commands

```bash
# Start/Stop/Restart
sudo systemctl start marbefes-bbt
sudo systemctl stop marbefes-bbt
sudo systemctl restart marbefes-bbt

# Status
sudo systemctl status marbefes-bbt

# Logs
sudo journalctl -u marbefes-bbt -f

# Nginx
sudo systemctl reload nginx
sudo nginx -t

# Application URLs
http://localhost              # Main interface
http://localhost/api/layers   # WMS layers API
http://localhost/api/all-layers  # All layers (WMS + vector)
```

---

## Support

For issues or questions:
1. Check logs: `sudo journalctl -u marbefes-bbt -f`
2. Review nginx logs: `/var/log/nginx/marbefes-bbt-*.log`
3. Test WMS connectivity: `http://localhost/test`
4. Verify vector data: Check `data/vector/` directory
