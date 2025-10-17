# MarineSABRES Demonstration Area Tool - Production Deployment Guide

**Production URL**: http://laguna.ku.lt/DA/
**Status**: Production Ready
**Version**: 1.3.0-dev
**Last Updated**: October 17, 2025

---

## Table of Contents

1. [Quick Deployment](#quick-deployment)
2. [Architecture Overview](#architecture-overview)
3. [Prerequisites](#prerequisites)
4. [Initial Setup](#initial-setup)
5. [Deployment Process](#deployment-process)
6. [Post-Deployment Verification](#post-deployment-verification)
7. [Monitoring and Maintenance](#monitoring-and-maintenance)
8. [Troubleshooting](#troubleshooting)
9. [Rollback Procedures](#rollback-procedures)
10. [Security Considerations](#security-considerations)

---

## Quick Deployment

### One-Command Deployment

For deploying to production (http://laguna.ku.lt/DA/):

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer
./deploy_to_da.sh
```

This automated script will:
- ✅ Check prerequisites (Python, nginx, systemd)
- ✅ Verify dependencies are installed
- ✅ Generate secure SECRET_KEY
- ✅ Install nginx configuration
- ✅ Install systemd service
- ✅ Start the application
- ✅ Verify deployment

**What You'll Need:**
- Sudo password (will be prompted when needed)
- Internet connection (for EMODnet WMS service checks)
- ~30 seconds of time

---

## Architecture Overview

### Production Stack

```
Internet → nginx (laguna.ku.lt/DA) → Gunicorn (127.0.0.1:5002) → Flask App
               ↓
          URL Rewriting: /DA/* → /*
          Static Files: /DA/static/, /DA/logo/
          Security Headers
```

### Components

| Component | Purpose | Configuration |
|-----------|---------|---------------|
| **Nginx** | Reverse proxy, static files, SSL termination | `/etc/nginx/sites-available/default.d-da.conf` |
| **Gunicorn** | WSGI server with worker management | `gunicorn.conf.py` |
| **Systemd** | Process management, auto-restart | `/etc/systemd/system/marinesabres-da.service` |
| **Flask** | Web application framework | `app.py` |

### Directory Structure

```
/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer/
├── app.py                      # Main Flask application
├── gunicorn.conf.py           # Gunicorn configuration
├── requirements.txt           # Python dependencies
├── config/                    # Configuration modules
│   └── config.py
├── src/                       # Application modules
│   └── emodnet_viewer/
│       └── utils/
│           └── logging_config.py
├── static/                    # Static assets (CSS, JS)
├── templates/                 # HTML templates
│   └── index.html
├── LOGO/                      # Logo files
├── logs/                      # Application logs (created on first run)
├── venv/                      # Python virtual environment
└── deploy_to_da.sh           # Deployment script
```

---

## Prerequisites

### System Requirements

**Operating System:**
- Ubuntu 20.04+ / Debian 11+
- Linux kernel 5.4+

**Software:**
- Python 3.9+
- nginx 1.18+
- systemd 245+
- Git (for version control)

**Resources:**
- CPU: 2+ cores (recommended 4+)
- RAM: 2GB minimum (4GB recommended)
- Disk: 500MB for application + logs
- Network: Outbound HTTPS access to EMODnet services

### Python Dependencies

**Core (Production):**
```
Flask==3.1.2
Flask-Caching==2.3.1
Flask-Limiter==3.8.0
requests==2.32.3
Werkzeug==3.1.0
gunicorn==21.2.0
redis==5.0.0  # Optional: for distributed caching
```

**Development:**
```
pytest==8.4.2
pytest-cov==6.0.0
black==25.1.0
flake8==7.3.0
```

### Installation

```bash
# Install system packages
sudo apt update
sudo apt install python3 python3-pip python3-venv nginx

# Create virtual environment
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install -r requirements.txt

# Verify installation
python -c "import flask, gunicorn, requests; print('Dependencies OK')"
```

---

## Initial Setup

### 1. Clone or Update Repository

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/
git clone <repository-url> DAViewer
# OR update existing:
cd DAViewer
git pull origin main
```

### 2. Configure Environment

The `.env` file is optional. The application uses sensible defaults but can be customized:

```bash
# Copy example configuration (optional)
cp .env.example .env

# Generate secure SECRET_KEY
python3 -c 'import secrets; print(secrets.token_hex(32))'

# Edit .env if needed
nano .env
```

**Important Environment Variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `APPLICATION_ROOT` | `/DA` | Subpath for deployment |
| `PORT` | `5002` | Gunicorn bind port |
| `FLASK_ENV` | `production` | Environment mode |
| `LOG_LEVEL` | `INFO` | Logging verbosity |
| `SECRET_KEY` | (generated) | Flask session security |

### 3. Create Logs Directory

```bash
mkdir -p logs
chmod 755 logs
```

### 4. Test Application Locally

```bash
# Activate virtual environment
source venv/bin/activate

# Run in development mode
python app.py

# Should see:
# INFO: Starting MarineSABRES Demonstration Area Tool
# INFO: Server running on http://127.0.0.1:5002
```

Open http://localhost:5002 in your browser to verify.

---

## Deployment Process

### Automated Deployment (Recommended)

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer
./deploy_to_da.sh
```

**Deployment Steps Performed:**

1. **Permission Check** - Ensures running as correct user
2. **Prerequisite Verification** - Checks Python, nginx, dependencies
3. **Log Directory Setup** - Creates logs/ with correct permissions
4. **SECRET_KEY Generation** - Creates secure production key
5. **Service Stop** - Gracefully stops existing service
6. **Nginx Configuration** - Installs reverse proxy config
7. **Systemd Service** - Installs and enables service
8. **Service Start** - Starts application with health check
9. **Nginx Reload** - Applies nginx configuration
10. **Status Display** - Shows service status and URLs

### Manual Deployment (Alternative)

If the automated script fails, deploy manually:

#### Step 1: Stop Existing Service

```bash
sudo systemctl stop marinesabres-da
```

#### Step 2: Install Nginx Configuration

```bash
sudo cp nginx-da.conf /etc/nginx/sites-available/default.d-da.conf

# Add include directive to main nginx config (if not already present)
sudo nano /etc/nginx/sites-available/default
# Add inside server {} block:
#   include /etc/nginx/sites-available/default.d-da.conf;

# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

#### Step 3: Install Systemd Service

```bash
# Generate SECRET_KEY first
SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(32))')

# Update service file with SECRET_KEY
sed "s/change-this-in-production-to-secure-key/$SECRET_KEY/" \
    marinesabres-da.service > /tmp/marinesabres-da.service

# Install service
sudo cp /tmp/marinesabres-da.service /etc/systemd/system/marinesabres-da.service

# Reload systemd
sudo systemctl daemon-reload

# Enable service
sudo systemctl enable marinesabres-da
```

#### Step 4: Start Service

```bash
sudo systemctl start marinesabres-da

# Check status
sudo systemctl status marinesabres-da

# View logs
sudo journalctl -u marinesabres-da -n 50 --no-pager
```

---

## Post-Deployment Verification

### Automated Verification

```bash
# Run verification tests
./scripts/verify_deployment.sh
```

### Manual Verification

#### 1. Check Service Status

```bash
sudo systemctl status marinesabres-da
```

Expected output:
```
● marinesabres-da.service - MarineSABRES Demonstration Area Tool (Gunicorn)
   Loaded: loaded (/etc/systemd/system/marinesabres-da.service; enabled)
   Active: active (running) since ...
```

#### 2. Test HTTP Endpoints

```bash
# Main page
curl -I http://laguna.ku.lt/DA/
# Expected: HTTP/1.1 200 OK

# Health check
curl http://laguna.ku.lt/DA/health
# Expected: {"status": "healthy", ...}

# API layers
curl http://laguna.ku.lt/DA/api/layers | head -20
# Expected: JSON array of layer objects

# Static files
curl -I http://laguna.ku.lt/DA/static/js/map-init.js
# Expected: HTTP/1.1 200 OK

# Logo files
curl -I http://laguna.ku.lt/DA/logo/marinesabres_logo.png
# Expected: HTTP/1.1 200 OK
```

#### 3. Browser Testing

Open in browser: http://laguna.ku.lt/DA/

**Checklist:**
- [ ] Page loads without errors (F12 → Console → No red errors)
- [ ] EMODnet logo displays in header
- [ ] Map renders with basemap
- [ ] Research sites dropdown works (Tuscan, Arctic, Macaronesia)
- [ ] Layer selection sidebar populates
- [ ] EMODnet Seabed Habitats layers load
- [ ] Human Activities layers load
- [ ] Legend displays when layer selected
- [ ] Opacity slider works
- [ ] No 404 errors for static assets

#### 4. Performance Testing

```bash
# Test response times
time curl -s http://laguna.ku.lt/DA/ > /dev/null
# Should complete in < 2 seconds

# Test concurrent requests
ab -n 100 -c 10 http://laguna.ku.lt/DA/health
# Should handle 100 requests without errors
```

#### 5. Log Verification

```bash
# Application logs
tail -50 logs/app.log

# Gunicorn logs
tail -50 logs/gunicorn-access.log
tail -50 logs/gunicorn-error.log

# System logs
sudo journalctl -u marinesabres-da -n 50

# Nginx logs
sudo tail -50 /var/log/nginx/access.log
sudo tail -50 /var/log/nginx/error.log
```

---

## Monitoring and Maintenance

### Health Monitoring

#### Manual Health Check

```bash
curl http://laguna.ku.lt/DA/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2025-10-17T12:34:56Z",
  "version": "1.3.0-dev",
  "wms_connectivity": "ok"
}
```

#### Automated Monitoring Script

```bash
# Run health check script
./scripts/health_check.sh

# Schedule with cron (every 5 minutes)
crontab -e
# Add:
# */5 * * * * /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer/scripts/health_check.sh
```

### Log Management

**Log Files:**
- `logs/app.log` - Application logs (INFO, WARNING, ERROR)
- `logs/gunicorn-access.log` - HTTP access logs
- `logs/gunicorn-error.log` - Gunicorn errors

**Log Rotation:**

Logs are automatically rotated using Python's RotatingFileHandler:
- Max size: 10MB per file
- Backup count: 5 files
- Total: ~50MB max

**View Real-Time Logs:**

```bash
# Application logs
tail -f logs/app.log

# Gunicorn logs
tail -f logs/gunicorn-access.log

# System journal
sudo journalctl -u marinesabres-da -f

# All logs combined
tail -f logs/*.log
```

### Service Management

```bash
# Check status
sudo systemctl status marinesabres-da

# Restart service
sudo systemctl restart marinesabres-da

# Stop service
sudo systemctl stop marinesabres-da

# Start service
sudo systemctl start marinesabres-da

# Reload Gunicorn workers (graceful)
sudo systemctl reload marinesabres-da

# View service configuration
systemctl cat marinesabres-da

# Check if enabled at boot
systemctl is-enabled marinesabres-da
```

### Performance Monitoring

```bash
# Monitor resource usage
top -p $(pgrep -f "gunicorn.*marinesabres-da" | tr '\n' ',' | sed 's/,$//')

# Check memory usage
ps aux | grep gunicorn | grep marinesabres

# Check open connections
sudo netstat -tuln | grep 5002

# Check file descriptors
ls -l /proc/$(pgrep -f "gunicorn.*marinesabres-da" | head -1)/fd | wc -l
```

---

## Troubleshooting

### Service Won't Start

**Check logs:**
```bash
sudo journalctl -u marinesabres-da -n 100 --no-pager
```

**Common issues:**

1. **Port already in use:**
   ```bash
   sudo lsof -i :5002
   # Kill conflicting process or change PORT in service file
   ```

2. **Python dependencies missing:**
   ```bash
   /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer/venv/bin/python -c "import flask, gunicorn, requests"
   # If error, reinstall: pip install -r requirements.txt
   ```

3. **Permission issues:**
   ```bash
   # Check file ownership
   ls -la /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer/
   # Should be owned by razinka:razinka

   # Fix permissions
   chmod 755 logs/
   chmod +x deploy_to_da.sh
   ```

### Nginx Configuration Issues

**Test configuration:**
```bash
sudo nginx -t
```

**Common issues:**

1. **Include directive missing:**
   ```bash
   grep -n "default.d-da.conf" /etc/nginx/sites-available/default
   # Should show include line
   ```

2. **Syntax errors:**
   ```bash
   sudo nginx -t 2>&1 | less
   # Review error messages
   ```

3. **Permission denied:**
   ```bash
   # Check nginx can access static files
   sudo -u www-data test -r /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer/static/js/map-init.js && echo "OK" || echo "FAIL"
   ```

### Application Errors

**502 Bad Gateway:**
- Service not running: `sudo systemctl start marinesabres-da`
- Wrong port: Check `gunicorn.conf.py` bind address
- Gunicorn crashed: Check `logs/gunicorn-error.log`

**404 Not Found:**
- Wrong subpath: Check `APPLICATION_ROOT=/DA` in service file
- Missing static files: Verify files exist in `static/` and `LOGO/`
- Nginx rewrite issues: Check `nginx-da.conf` location blocks

**500 Internal Server Error:**
- Check `logs/app.log` for Python exceptions
- Check `logs/gunicorn-error.log` for worker crashes
- Verify EMODnet WMS service is accessible: `curl -I https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms`

**Slow Performance:**
- Check worker count: `ps aux | grep gunicorn | wc -l`
- Increase timeout in `gunicorn.conf.py`
- Check EMODnet service response time
- Review `logs/gunicorn-access.log` for slow requests

### EMODnet WMS Issues

**Test connectivity:**
```bash
curl -v "https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms?service=WMS&version=1.3.0&request=GetCapabilities"
```

**Fallback behavior:**
- Application uses predefined layer list if WMS is unavailable
- Check `app.py` lines 17-48 for default layers

---

## Rollback Procedures

### Quick Rollback

```bash
# Stop current service
sudo systemctl stop marinesabres-da

# Revert to previous version (if using git)
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer
git log --oneline -5  # Find commit to revert to
git checkout <commit-hash>

# Restart service
sudo systemctl start marinesabres-da
```

### Automated Rollback Script

```bash
# Create backup before deployment
./scripts/backup_deployment.sh

# Rollback to previous backup
./scripts/rollback.sh
```

### Manual Rollback

1. **Identify backup:**
   ```bash
   ls -lt backups/
   ```

2. **Stop service:**
   ```bash
   sudo systemctl stop marinesabres-da
   ```

3. **Restore files:**
   ```bash
   tar -xzf backups/marinesabres-da-backup-YYYYMMDD_HHMMSS.tar.gz -C /
   ```

4. **Restart service:**
   ```bash
   sudo systemctl start marinesabres-da
   ```

---

## Security Considerations

### Production Security Checklist

- [x] Debug mode disabled (`FLASK_ENV=production`)
- [x] Secure SECRET_KEY generated
- [x] Running as non-root user (`razinka`)
- [x] Systemd security hardening enabled
- [x] Input validation on layer names
- [x] HTTPS recommended (via nginx SSL)
- [x] No secrets in version control
- [x] Log files have restricted permissions
- [x] Rate limiting on API endpoints

### Systemd Security Features

The service file includes:
```ini
NoNewPrivileges=true           # Prevents privilege escalation
PrivateTmp=true               # Isolated /tmp directory
ProtectSystem=strict          # Read-only system directories
ProtectHome=false             # Allows access to /home/razinka
ProtectKernelTunables=true    # Protected /proc and /sys
```

### SSL/TLS Configuration

For HTTPS deployment, configure nginx SSL:

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d laguna.ku.lt

# Auto-renewal test
sudo certbot renew --dry-run
```

Update `nginx-da.conf`:
```nginx
listen 443 ssl http2;
listen [::]:443 ssl http2;
ssl_certificate /etc/letsencrypt/live/laguna.ku.lt/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/laguna.ku.lt/privkey.pem;
```

### Firewall Configuration

```bash
# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Block direct access to Gunicorn port
sudo ufw deny 5002/tcp

# Enable firewall
sudo ufw enable
```

---

## Useful Commands Reference

### Service Management
```bash
sudo systemctl status marinesabres-da    # Check status
sudo systemctl restart marinesabres-da   # Restart
sudo systemctl reload marinesabres-da    # Graceful reload
sudo systemctl stop marinesabres-da      # Stop
sudo systemctl start marinesabres-da     # Start
```

### Logs
```bash
sudo journalctl -u marinesabres-da -f    # Real-time system logs
tail -f logs/app.log                     # Application logs
tail -f logs/gunicorn-access.log         # Access logs
```

### Testing
```bash
curl http://laguna.ku.lt/DA/             # Test main page
curl http://laguna.ku.lt/DA/health       # Health check
curl http://laguna.ku.lt/DA/api/layers   # API test
```

### Debugging
```bash
# Check if service is listening
sudo netstat -tlnp | grep 5002

# Check worker processes
ps aux | grep gunicorn

# Check nginx configuration
sudo nginx -t

# View service environment
systemctl show marinesabres-da -p Environment
```

---

## Additional Resources

### Documentation Files

| File | Purpose |
|------|---------|
| `README.md` | Project overview and quick start |
| `CLAUDE.md` | Detailed development documentation |
| `CHANGELOG.md` | Version history |
| `DEPLOYMENT.md` | This file - deployment guide |
| `requirements.txt` | Python dependencies |

### Scripts

| Script | Purpose |
|--------|---------|
| `deploy_to_da.sh` | Automated deployment script |
| `scripts/health_check.sh` | Health monitoring |
| `scripts/backup_deployment.sh` | Create backups |
| `scripts/rollback.sh` | Rollback to previous version |
| `scripts/verify_deployment.sh` | Post-deployment tests |

### Support

For issues or questions:
1. Check logs: `sudo journalctl -u marinesabres-da -n 100`
2. Review this guide
3. Check CLAUDE.md for development details
4. Contact: razinka@ku.lt

---

**Last Updated:** October 17, 2025
**Version:** 1.3.0-dev
**Production URL:** http://laguna.ku.lt/DA/
**Status:** ✅ Production Ready
