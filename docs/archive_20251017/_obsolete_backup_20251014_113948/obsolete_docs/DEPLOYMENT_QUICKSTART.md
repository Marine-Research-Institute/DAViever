# 🚀 MARBEFES BBT Production Deployment - Quick Start

## One-Command Deployment

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck
sudo ./deploy_production.sh
```

That's it! The script handles everything automatically.

---

## What Gets Deployed

### 📦 Application Location
```
/var/www/marbefes-bbt/
```

### 🔧 Components Created

| Component | Location | Purpose |
|-----------|----------|---------|
| **Flask App** | `/var/www/marbefes-bbt/app.py` | Main application |
| **Virtual Env** | `/var/www/marbefes-bbt/venv/` | Python dependencies |
| **Environment** | `/var/www/marbefes-bbt/.env` | Production config |
| **Gunicorn Config** | `/var/www/marbefes-bbt/gunicorn_config.py` | WSGI server settings |
| **Systemd Service** | `/etc/systemd/system/marbefes-bbt.service` | Auto-start service |
| **Nginx Config** | `/etc/nginx/sites-available/marbefes-bbt` | Reverse proxy |
| **Logs** | `/var/www/marbefes-bbt/logs/` | Application logs |

---

## Post-Deployment Verification

### Run Automated Tests
```bash
sudo ./verify_deployment.sh
```

This comprehensive test suite checks:
- ✓ File system and permissions
- ✓ Systemd service status
- ✓ Nginx configuration
- ✓ HTTP endpoints
- ✓ API responses
- ✓ Performance metrics
- ✓ Security headers
- ✓ Python dependencies
- ✓ Network connectivity

### Quick Manual Check
```bash
# Check service status
sudo systemctl status marbefes-bbt

# Test the application
curl -I http://localhost
curl http://localhost/api/layers | jq .
```

---

## Access URLs

### Local Development
```
http://localhost
```

### Network Access
```bash
# Find your server IP
hostname -I

# Access from other devices
http://YOUR_SERVER_IP
```

### Production Domain (After DNS Setup)
```
http://bbt.marbefes.eu
```

---

## Essential Commands

### Service Management
```bash
# Start service
sudo systemctl start marbefes-bbt

# Stop service
sudo systemctl stop marbefes-bbt

# Restart service
sudo systemctl restart marbefes-bbt

# View status
sudo systemctl status marbefes-bbt

# Enable auto-start on boot
sudo systemctl enable marbefes-bbt
```

### View Logs
```bash
# Application logs (systemd journal)
sudo journalctl -u marbefes-bbt -f

# Last 100 lines
sudo journalctl -u marbefes-bbt -n 100

# Gunicorn logs
sudo tail -f /var/www/marbefes-bbt/logs/gunicorn-error.log
sudo tail -f /var/www/marbefes-bbt/logs/gunicorn-access.log

# Nginx logs
sudo tail -f /var/log/nginx/marbefes-bbt-access.log
sudo tail -f /var/log/nginx/marbefes-bbt-error.log
```

### Nginx Management
```bash
# Test configuration
sudo nginx -t

# Reload configuration (no downtime)
sudo systemctl reload nginx

# Restart nginx
sudo systemctl restart nginx
```

---

## Configuration Updates

### Update Domain Name
```bash
# Edit nginx config
sudo nano /etc/nginx/sites-available/marbefes-bbt

# Change server_name to your domain
server_name your-domain.com www.your-domain.com;

# Test and reload
sudo nginx -t && sudo systemctl reload nginx
```

### Update Environment Variables
```bash
# Edit production environment
sudo nano /var/www/marbefes-bbt/.env

# Restart service to apply changes
sudo systemctl restart marbefes-bbt
```

---

## SSL/HTTPS Setup (Optional but Recommended)

### Install Certbot
```bash
sudo apt update
sudo apt install certbot python3-certbot-nginx
```

### Obtain Certificate
```bash
sudo certbot --nginx -d bbt.marbefes.eu -d www.bbt.marbefes.eu
```

Certbot will:
- ✓ Obtain SSL certificate from Let's Encrypt
- ✓ Automatically configure nginx for HTTPS
- ✓ Set up auto-renewal

### Verify Auto-Renewal
```bash
sudo certbot renew --dry-run
```

---

## Troubleshooting

### Service Won't Start
```bash
# Check detailed error logs
sudo journalctl -u marbefes-bbt -n 50 --no-pager

# Check if port is in use
sudo lsof -i :5000

# Test Gunicorn directly
cd /var/www/marbefes-bbt
source venv/bin/activate
gunicorn --config gunicorn_config.py app:app
```

### 502 Bad Gateway
```bash
# Service might not be running
sudo systemctl status marbefes-bbt
sudo systemctl start marbefes-bbt

# Check Gunicorn is listening
sudo ss -tulpn | grep :5000
```

### Permission Errors
```bash
# Reset permissions
sudo chown -R www-data:www-data /var/www/marbefes-bbt
sudo chmod -R 755 /var/www/marbefes-bbt
sudo chmod 644 /var/www/marbefes-bbt/.env
```

### Vector Layers Not Loading
```bash
# Check GPKG files exist
ls -lh /var/www/marbefes-bbt/data/vector/*.gpkg

# Test vector loading manually
cd /var/www/marbefes-bbt
source venv/bin/activate
python -c "from src.emodnet_viewer.utils.vector_loader import vector_loader; layers = vector_loader.load_all_vector_layers(); print(f'Loaded {len(layers)} layers')"
```

---

## Update Deployment

### Pull Latest Changes
```bash
# Update source code
cd /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck
# ... make your changes or pull from git ...

# Re-deploy (preserves .env and logs)
sudo ./deploy_production.sh
```

### Manual Sync
```bash
# Sync specific files
sudo rsync -av --exclude='venv' --exclude='logs' --exclude='.env' \
    /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/ \
    /var/www/marbefes-bbt/

# Restart service
sudo systemctl restart marbefes-bbt
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                       Internet                          │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│              Nginx (Port 80/443)                        │
│  • SSL/TLS Termination                                  │
│  • Reverse Proxy                                        │
│  • Static File Serving                                  │
│  • Gzip Compression                                     │
│  • Security Headers                                     │
└────────────────────────┬────────────────────────────────┘
                         │ proxy_pass
                         ▼
┌─────────────────────────────────────────────────────────┐
│            Gunicorn WSGI Server (Port 5000)             │
│  • Multiple Worker Processes                            │
│  • Load Balancing                                       │
│  • Process Management                                   │
│  • Request Timeout Handling                             │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│              Flask Application (app.py)                 │
│  • WMS Layer Integration (EMODnet, HELCOM)              │
│  • Vector Data Processing (GPKG)                        │
│  • API Endpoints                                        │
│  • Real-time Tooltips & Area Calculations               │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│                  External Services                      │
│  • EMODnet WMS                                          │
│  • HELCOM WMS                                           │
│  • Local Vector Data (GPKG)                             │
└─────────────────────────────────────────────────────────┘
```

---

## Performance Optimization

### Gunicorn Workers
Workers are automatically calculated as: **CPU cores × 2 + 1**

To adjust manually:
```bash
# Edit gunicorn_config.py
sudo nano /var/www/marbefes-bbt/gunicorn_config.py

# Change workers value
workers = 4  # or your desired number

# Restart
sudo systemctl restart marbefes-bbt
```

### Cache Settings
```bash
# Edit .env file
sudo nano /var/www/marbefes-bbt/.env

# Adjust cache timeout (in seconds)
CACHE_DEFAULT_TIMEOUT=600  # 10 minutes

# Restart to apply
sudo systemctl restart marbefes-bbt
```

---

## Security Checklist

- [x] Debug mode disabled (`FLASK_DEBUG=False`)
- [x] Unique secret key generated
- [x] Process runs as `www-data` (unprivileged user)
- [x] Security headers enabled
- [ ] SSL/HTTPS configured (run certbot)
- [ ] Firewall configured (UFW/iptables)
- [ ] Regular system updates scheduled
- [ ] Log rotation configured
- [ ] Backup strategy implemented

---

## Monitoring & Maintenance

### System Resources
```bash
# Check CPU/Memory usage
htop

# Disk space
df -h

# Check process
ps aux | grep gunicorn
```

### Application Health
```bash
# Quick health check
curl -I http://localhost

# API test
curl http://localhost/api/layers | jq '.[:3]'

# Response time test
curl -w "Response time: %{time_total}s\n" -o /dev/null -s http://localhost/api/all-layers
```

### Log Monitoring
```bash
# Watch all logs in real-time
sudo journalctl -u marbefes-bbt -f & \
sudo tail -f /var/log/nginx/marbefes-bbt-error.log &

# Search for errors
sudo journalctl -u marbefes-bbt | grep -i error

# Count requests
sudo cat /var/log/nginx/marbefes-bbt-access.log | wc -l
```

---

## Files Created

### Deployment Scripts
- ✅ `deploy_production.sh` - Automated deployment script
- ✅ `verify_deployment.sh` - Post-deployment verification

### Documentation
- ✅ `PRODUCTION_DEPLOYMENT.md` - Detailed deployment guide
- ✅ `DEPLOYMENT_QUICKSTART.md` - This quick reference (you are here)

### Configuration Files (Created by Script)
- ✅ `/var/www/marbefes-bbt/.env` - Environment variables
- ✅ `/var/www/marbefes-bbt/gunicorn_config.py` - WSGI config
- ✅ `/etc/systemd/system/marbefes-bbt.service` - Service definition
- ✅ `/etc/nginx/sites-available/marbefes-bbt` - Nginx config

---

## Quick Reference Card

| Task | Command |
|------|---------|
| **Deploy** | `sudo ./deploy_production.sh` |
| **Verify** | `sudo ./verify_deployment.sh` |
| **Status** | `sudo systemctl status marbefes-bbt` |
| **Restart** | `sudo systemctl restart marbefes-bbt` |
| **Logs** | `sudo journalctl -u marbefes-bbt -f` |
| **Test** | `curl http://localhost` |
| **SSL Setup** | `sudo certbot --nginx` |

---

## Need Help?

### Check Documentation
- `PRODUCTION_DEPLOYMENT.md` - Full deployment guide with troubleshooting
- `CLAUDE.md` - Project architecture and development notes
- `README.md` - Project overview

### Useful Links
- EMODnet WMS: https://ows.emodnet-seabedhabitats.eu/
- Flask Documentation: https://flask.palletsprojects.com/
- Gunicorn Docs: https://docs.gunicorn.org/
- Nginx Docs: https://nginx.org/en/docs/

---

**🎉 Your MARBEFES BBT Database is now production-ready!**

Access it at: http://localhost (or your server's IP/domain)
