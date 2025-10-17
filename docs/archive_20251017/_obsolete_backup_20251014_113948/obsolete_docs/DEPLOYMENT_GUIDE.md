# MARBEFES BBT Database - Official Deployment Guide

**⚠️ THIS IS THE CANONICAL DEPLOYMENT DOCUMENTATION ⚠️**

All other deployment documentation files (DEPLOY.md, QUICK_DEPLOY.txt, etc.) are **deprecated** and kept for historical reference only. Follow this guide for all deployments.

---

## Table of Contents

1. [Quick Deployment](#quick-deployment)
2. [Prerequisites](#prerequisites)
3. [Production Deployment](#production-deployment)
4. [Verification](#verification)
5. [Troubleshooting](#troubleshooting)
6. [Rollback Procedures](#rollback-procedures)

---

## Quick Deployment

For experienced operators who have already deployed before:

```bash
# 1. Run the deployment script
./deploy.sh

# 2. Verify deployment
curl -I http://laguna.ku.lt/BBTS
curl -I http://laguna.ku.lt/BBTS/logo/marbefes_02.png
curl -I http://laguna.ku.lt/BBTS/api/vector/layers

# 3. Check service status
ssh razinka@laguna.ku.lt "sudo systemctl status marbefes-bbt"
```

**Done!** If all curl commands return `200 OK`, deployment is successful.

---

## Prerequisites

### Server Requirements

- **OS**: Ubuntu 20.04+ or similar Linux distribution
- **Python**: 3.9+
- **Web Server**: Nginx (configured for reverse proxy)
- **Process Manager**: systemd
- **Memory**: Minimum 2GB RAM (4GB+ recommended for vector layers)

### Required Access

- SSH access to production server: `razinka@laguna.ku.lt`
- Sudo privileges for systemctl commands
- Git repository access (if applicable)

### Local Setup

Ensure you have the following on your local machine:

```bash
# SSH key configured
chmod 600 ~/.ssh/id_ed25519

# Project directory
cd /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck

# Deployment script executable
chmod +x deploy.sh
```

---

## Production Deployment

### Architecture Overview

The application runs at **http://laguna.ku.lt/BBTS** with the following components:

```
Internet → Nginx (Port 80) → Gunicorn (Port 8000) → Flask App
                  ↓
           Subpath: /BBTS
           Static: /BBTS/logo/*
           API: /BBTS/api/*
```

### Configuration Files

**Server-side** (`/var/www/marbefes-bbt/`):
- `app.py` - Main Flask application
- `templates/index.html` - Frontend template
- `config/config.py` - Application configuration
- `data/vector/*.gpkg` - Vector data layers
- `.env` - Environment variables (if used)

**System Services**:
- `/etc/systemd/system/marbefes-bbt.service` - Systemd service
- `/etc/nginx/sites-available/marbefes-bbt` - Nginx config

### Step-by-Step Deployment

#### Step 1: Prepare Local Changes

```bash
# Navigate to project directory
cd /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck

# Verify changes (optional but recommended)
git status
git diff

# Test locally (optional)
python3 app.py
# Visit http://localhost:5000 to verify
```

#### Step 2: Deploy Files

```bash
# Run the deployment script
./deploy.sh
```

The script performs:
1. ✅ Copies `app.py` to server
2. ✅ Copies `templates/index.html` to server
3. ✅ Restarts the systemd service
4. ✅ Verifies service is running
5. ✅ Tests key endpoints (logo, API)

#### Step 3: Manual Verification

After deployment completes, open browser and verify:

1. **Homepage**: http://laguna.ku.lt/BBTS
   - Logo displays in header (MARBEFES logo)
   - Map loads without errors
   - No console errors in DevTools (F12)

2. **Vector Layers**:
   - BBT navigation dropdown appears
   - Selecting BBT zooms to features
   - Hover tooltips show area calculations

3. **WMS Layers**:
   - EUNIS 2019 layers load
   - Click-to-query works on WMS layers
   - Legend displays correctly

#### Step 4: Service Management

```bash
# Check service status
ssh razinka@laguna.ku.lt "sudo systemctl status marbefes-bbt"

# View recent logs
ssh razinka@laguna.ku.lt "sudo journalctl -u marbefes-bbt -n 50 --no-pager"

# Restart if needed
ssh razinka@laguna.ku.lt "sudo systemctl restart marbefes-bbt"
```

---

## Verification

### Automated Verification

The deployment script includes automated tests. You can also run manual checks:

```bash
# Test homepage
curl -I http://laguna.ku.lt/BBTS
# Expected: HTTP/1.1 200 OK

# Test logo serving
curl -I http://laguna.ku.lt/BBTS/logo/marbefes_02.png
# Expected: HTTP/1.1 200 OK, Content-Type: image/png

# Test vector API
curl http://laguna.ku.lt/BBTS/api/vector/layers | jq '.count'
# Expected: Number of vector layers (e.g., 9)

# Test specific vector layer
curl -I "http://laguna.ku.lt/BBTS/api/vector/layer/BBts.gpkg/Broad%20Belt%20Transects"
# Expected: HTTP/1.1 200 OK
```

### Health Checks

```bash
# CPU/Memory usage
ssh razinka@laguna.ku.lt "top -bn1 | grep marbefes"

# Disk space
ssh razinka@laguna.ku.lt "df -h /var/www/marbefes-bbt"

# Process count
ssh razinka@laguna.ku.lt "pgrep -a gunicorn | grep marbefes"
# Expected: 17 workers (1 master + 16 workers)
```

---

## Troubleshooting

### Issue: Service fails to start

**Symptoms**: `systemctl status marbefes-bbt` shows `failed` state

**Solutions**:
```bash
# Check detailed logs
ssh razinka@laguna.ku.lt "sudo journalctl -u marbefes-bbt -n 100"

# Common causes:
# 1. Port already in use
sudo lsof -i :8000

# 2. Missing dependencies
cd /var/www/marbefes-bbt && source venv/bin/activate && pip install -r requirements.txt

# 3. Permission issues
sudo chown -R razinka:razinka /var/www/marbefes-bbt
```

### Issue: 502 Bad Gateway

**Symptoms**: Nginx returns 502 error

**Solutions**:
```bash
# Check Gunicorn is running
ssh razinka@laguna.ku.lt "systemctl is-active marbefes-bbt"

# Check nginx configuration
ssh razinka@laguna.ku.lt "sudo nginx -t"

# View nginx error log
ssh razinka@laguna.ku.lt "sudo tail -50 /var/log/nginx/error.log"
```

### Issue: Logo not displaying (404)

**Symptoms**: Browser console shows 404 for logo files

**Solutions**:
```bash
# Verify logo files exist
ssh razinka@laguna.ku.lt "ls -la /var/www/marbefes-bbt/LOGO/"

# Check logo route in app.py
grep -A5 "serve_logo" app.py

# Test direct access
curl -I http://laguna.ku.lt/BBTS/logo/marbefes_02.png
```

### Issue: Vector layers not loading

**Symptoms**: "No vector layers found" or API returns empty array

**Solutions**:
```bash
# Check vector data directory
ssh razinka@laguna.ku.lt "ls -la /var/www/marbefes-bbt/data/vector/"

# Verify GPKG files
ssh razinka@laguna.ku.lt "file /var/www/marbefes-bbt/data/vector/*.gpkg"

# Check geopandas installation
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && source venv/bin/activate && python -c 'import geopandas; print(geopandas.__version__)'"
```

### Issue: API returns wrong URLs in subpath deployment

**Symptoms**: API calls fail with 404, URLs missing `/BBTS` prefix

**Solutions**:
```bash
# Verify APPLICATION_ROOT is set
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && source venv/bin/activate && python -c 'from config import get_config; print(get_config().APPLICATION_ROOT)'"

# Should output: /BBTS

# Check API_BASE_URL is passed to template (app.py:339)
grep "API_BASE_URL" app.py
```

---

## Rollback Procedures

### Quick Rollback

If deployment fails, rollback to previous working version:

```bash
# Option 1: Using git (if previous version was committed)
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && git checkout HEAD~1 app.py templates/index.html && sudo systemctl restart marbefes-bbt"

# Option 2: Manual restoration (if you have backup)
scp backup/app.py razinka@laguna.ku.lt:/var/www/marbefes-bbt/
scp backup/templates/index.html razinka@laguna.ku.lt:/var/www/marbefes-bbt/templates/
ssh razinka@laguna.ku.lt "sudo systemctl restart marbefes-bbt"
```

### Creating Backup Before Deployment

```bash
# Always create backup before deploying
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && cp app.py app.py.backup.$(date +%Y%m%d-%H%M%S)"
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt/templates && cp index.html index.html.backup.$(date +%Y%m%d-%H%M%S)"
```

---

## Configuration Reference

### Environment Variables

Set in `/var/www/marbefes-bbt/.env` (if used):

```bash
FLASK_ENV=production
APPLICATION_ROOT=/BBTS
LOG_LEVEL=INFO
CACHE_DEFAULT_TIMEOUT=3600
```

### Systemd Service Configuration

Location: `/etc/systemd/system/marbefes-bbt.service`

Key settings:
- `WorkingDirectory=/var/www/marbefes-bbt`
- `ExecStart=/var/www/marbefes-bbt/venv/bin/gunicorn -c gunicorn.conf.py app:app`
- `User=razinka`
- `Restart=always`

### Gunicorn Configuration

Location: `/var/www/marbefes-bbt/gunicorn.conf.py`

Key settings:
- `bind = "127.0.0.1:8000"`
- `workers = 17` (2 * CPUs + 1)
- `worker_class = "sync"`
- `timeout = 120`

---

## Deprecated Documentation

The following files are **deprecated** and should not be used:

- ❌ DEPLOY.md
- ❌ DEPLOY_INSTRUCTIONS.txt
- ❌ DEPLOY_NOW.md
- ❌ DEPLOYMENT_READY.md
- ❌ QUICK_DEPLOY.txt
- ❌ README_DEPLOY.txt
- ❌ README_DEPLOYMENT.md

These files are kept for historical reference but may contain outdated information.

**For technical details about subpath configuration, see**: SUBPATH_DEPLOYMENT.md
**For complete fix history, see**: COMPLETE_SOLUTION.md

---

## Support & Contact

- **Repository**: Check git history for recent changes
- **Logs**: `/var/log/marbefes-bbt/` or `journalctl -u marbefes-bbt`
- **Issues**: Document in git commit messages or project issue tracker

---

---

## Advanced Production Features (v1.2.0+)

### Redis Caching Setup

For multi-worker deployments, Redis provides shared caching across all workers:

#### 1. Install Redis

```bash
sudo apt-get update
sudo apt-get install redis-server
```

#### 2. Configure Redis (Optional Security)

```bash
sudo nano /etc/redis/redis.conf
```

Add/modify:
```
# Bind to localhost only
bind 127.0.0.1

# Set password (optional but recommended)
requirepass your-strong-password-here

# Set max memory
maxmemory 256mb
maxmemory-policy allkeys-lru
```

#### 3. Update Application Configuration

Edit `.env` on server:
```bash
CACHE_TYPE=redis
CACHE_REDIS_HOST=localhost
CACHE_REDIS_PORT=6379
CACHE_REDIS_DB=0
CACHE_REDIS_PASSWORD=your-strong-password-here
```

#### 4. Restart Services

```bash
sudo systemctl restart redis-server
sudo systemctl restart marbefes-bbt
```

#### 5. Verify Redis Caching

```bash
# Check Redis is running
redis-cli ping  # Should return PONG

# Monitor cache activity
redis-cli monitor  # Watch real-time commands

# Check cache statistics
redis-cli INFO stats
```

### Automated Monitoring

#### Setting Up Health Monitoring

The application includes `monitor_health.py` for automated monitoring:

```bash
# Basic health check
python monitor_health.py --url http://laguna.ku.lt/BBTS

# JSON output for integration
python monitor_health.py --url http://laguna.ku.lt/BBTS --json

# Quiet mode (only exit codes)
python monitor_health.py --url http://laguna.ku.lt/BBTS --quiet
# Exit codes: 0=healthy, 1=degraded, 2=unhealthy, 3=connection error
```

#### Cron Job for Periodic Checks

```bash
# Edit crontab
crontab -e

# Add monitoring (every 5 minutes)
*/5 * * * * /var/www/marbefes-bbt/venv/bin/python /var/www/marbefes-bbt/monitor_health.py --url http://laguna.ku.lt/BBTS --quiet || echo "ALERT: MARBEFES BBT health check failed" | mail -s "MARBEFES Alert" admin@example.com
```

#### Slack Integration

```bash
# Get Slack webhook URL from: https://api.slack.com/messaging/webhooks
# Add to monitoring script:
python monitor_health.py \
  --url http://laguna.ku.lt/BBTS \
  --slack-webhook "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

### Automated Testing

#### Running API Tests

```bash
# Run all tests
pytest tests/test_api_endpoints.py -v

# Run specific test class
pytest tests/test_api_endpoints.py::TestAPIEndpoints -v

# Run with coverage
pytest tests/test_api_endpoints.py --cov=app --cov-report=html

# Generate coverage report
open htmlcov/index.html  # View in browser
```

#### Integration Tests in CI/CD

Example GitHub Actions workflow:

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.10'
      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install pytest pytest-cov
      - name: Run tests
        run: pytest tests/ -v --cov=app
```

### Performance Optimization

#### Monitoring Performance Metrics

```bash
# Check request times
tail -f logs/gunicorn_access.log | awk '{print $(NF-1)}'

# Monitor memory usage per worker
ps aux | grep gunicorn | awk '{print $2,$4,$11}' | column -t

# Check cache hit rates (Redis)
redis-cli INFO stats | grep -E "keyspace_hits|keyspace_misses"
```

#### Tuning Gunicorn Workers

```bash
# Calculate optimal workers
# Formula: (2 x CPU cores) + 1
python -c "import multiprocessing; print(f'Recommended workers: {multiprocessing.cpu_count() * 2 + 1}')"

# Edit gunicorn_config.py
nano /var/www/marbefes-bbt/gunicorn_config.py
# Update: workers = 17  # or calculated value

# Restart
sudo systemctl restart marbefes-bbt
```

### Security Enhancements

#### 1. SECRET_KEY Management

```bash
# Generate secure key
python -c 'import secrets; print(secrets.token_hex(32))'

# Add to .env (NEVER commit to git!)
echo "SECRET_KEY=<generated-key>" >> .env
chmod 600 .env
```

#### 2. Rate Limiting Configuration

Rate limiting is configured in `app.py`:

```python
# Default limits
limiter = Limiter(
    default_limits=["200 per day", "50 per hour"]
)

# Endpoint-specific limits
@app.route("/api/vector/layer/<name>")
@limiter.limit("10 per minute")  # Stricter for expensive operations
```

#### 3. Security Headers

Automatic security headers are set in `app.py:81-93`:
- X-Content-Type-Options: nosniff
- X-Frame-Options: SAMEORIGIN
- X-XSS-Protection: 1; mode=block
- HSTS (production only with HTTPS)

Verify with:
```bash
curl -I http://laguna.ku.lt/BBTS | grep -E "^X-"
```

### Backup and Disaster Recovery

#### Automated Backup Script

Create `/usr/local/bin/backup-marbefes.sh`:

```bash
#!/bin/bash
BACKUP_DIR=/backup/marbefes-bbt
DATE=$(date +%Y%m%d-%H%M%S)
APP_DIR=/var/www/marbefes-bbt

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup application files
tar -czf $BACKUP_DIR/app-$DATE.tar.gz \
    -C $APP_DIR \
    --exclude='venv' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='cache' \
    --exclude='logs' \
    .

# Backup environment file
cp $APP_DIR/.env $BACKUP_DIR/env-$DATE 2>/dev/null || true

# Backup Redis data (if using Redis)
if systemctl is-active redis-server >/dev/null; then
    redis-cli SAVE
    cp /var/lib/redis/dump.rdb $BACKUP_DIR/redis-$DATE.rdb
fi

# Keep only last 30 days
find $BACKUP_DIR -name "app-*.tar.gz" -mtime +30 -delete
find $BACKUP_DIR -name "env-*" -mtime +30 -delete
find $BACKUP_DIR -name "redis-*.rdb" -mtime +30 -delete

echo "Backup completed: $BACKUP_DIR/app-$DATE.tar.gz"
```

Make executable and add to cron:
```bash
sudo chmod +x /usr/local/bin/backup-marbefes.sh
sudo crontab -e

# Daily backup at 2 AM
0 2 * * * /usr/local/bin/backup-marbefes.sh
```

#### Restore Procedure

```bash
# List available backups
ls -lh /backup/marbefes-bbt/

# Stop service
sudo systemctl stop marbefes-bbt

# Restore from backup
tar -xzf /backup/marbefes-bbt/app-YYYYMMDD-HHMMSS.tar.gz -C /var/www/marbefes-bbt/

# Restore environment
cp /backup/marbefes-bbt/env-YYYYMMDD-HHMMSS /var/www/marbefes-bbt/.env

# Start service
sudo systemctl start marbefes-bbt
```

---

## Changelog

### Version 1.2.0 (October 2025)

**New Features:**
- ✨ Redis caching support for distributed deployments
- ✨ Automated health monitoring with Slack/email alerts
- ✨ Comprehensive API endpoint test suite (19 tests)
- ✨ Production deployment scripts (Gunicorn + systemd)
- ✨ Enhanced security headers and rate limiting

**Improvements:**
- ⚡ Updated Flask-Caching to 2.3.1
- ⚡ Updated pandas to 2.2.3
- ⚡ Enhanced error handling and logging
- ⚡ Improved cache configuration system

**Documentation:**
- 📚 Comprehensive deployment guide
- 📚 Monitoring and troubleshooting procedures
- 📚 Security best practices
- 📚 Backup and recovery procedures

### Version 1.1.0 (September 2025)

**Framework Updates:**
- Major framework upgrades (Flask 3.1.2, GeoPandas 1.1.1)
- Performance optimizations
- Code quality improvements

### Version 1.0.0 (August 2025)

- Initial production release

---

**Last Updated**: 2025-10-13
**Version**: 1.2.0 (Production enhancements with monitoring and testing)
