# Deploy MARBEFES BBT v1.2.0 to laguna.ku.lt

**Target Server:** laguna.ku.lt
**Application Path:** `/var/www/marbefes-bbt`
**Version:** 1.2.0 (Production Enhancements)
**Date:** October 13, 2025

---

## Pre-Deployment Checklist

### 1. Verify SSH Access

```bash
# Test SSH connection
ssh razinka@laguna.ku.lt "echo 'Connection successful'"

# If connection fails, set up SSH key:
ssh-copy-id razinka@laguna.ku.lt
```

### 2. Create Backup

```bash
# Backup current deployment
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && \
  sudo tar -czf /backup/marbefes-bbt-backup-$(date +%Y%m%d-%H%M%S).tar.gz \
  --exclude='venv' --exclude='__pycache__' --exclude='*.pyc' --exclude='cache' --exclude='logs' ."

# Verify backup created
ssh razinka@laguna.ku.lt "ls -lh /backup/marbefes-bbt-backup-* | tail -1"
```

---

## Deployment Steps

### Step 1: Stop Current Service

```bash
ssh razinka@laguna.ku.lt "sudo systemctl stop marbefes-bbt"
ssh razinka@laguna.ku.lt "sudo systemctl status marbefes-bbt"
```

### Step 2: Deploy New Files

#### Option A: Using rsync (Recommended)

```bash
# From local project directory
cd /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck

# Deploy application files
rsync -avz --exclude='venv' --exclude='__pycache__' --exclude='*.pyc' \
  --exclude='.git' --exclude='cache' --exclude='logs' \
  --exclude='*.md' --exclude='test_*.html' --exclude='_archive' \
  --exclude='FactSheets' \
  ./ razinka@laguna.ku.lt:/var/www/marbefes-bbt/

# Deploy new production files specifically
scp gunicorn_config.py razinka@laguna.ku.lt:/var/www/marbefes-bbt/
scp start_production.sh razinka@laguna.ku.lt:/var/www/marbefes-bbt/
scp monitor_health.py razinka@laguna.ku.lt:/var/www/marbefes-bbt/
scp marbefes-bbt.service razinka@laguna.ku.lt:/tmp/

# Make scripts executable
ssh razinka@laguna.ku.lt "chmod +x /var/www/marbefes-bbt/start_production.sh"
ssh razinka@laguna.ku.lt "chmod +x /var/www/marbefes-bbt/monitor_health.py"
```

#### Option B: Using Git (If repository is set up)

```bash
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && \
  git pull origin main"
```

### Step 3: Install/Update Dependencies

```bash
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && \
  source venv/bin/activate && \
  pip install --upgrade pip && \
  pip install -r requirements.txt"

# Verify Gunicorn installed
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && \
  source venv/bin/activate && \
  gunicorn --version"
```

### Step 4: Update Environment Configuration

```bash
# Check current .env
ssh razinka@laguna.ku.lt "cat /var/www/marbefes-bbt/.env"

# Update .env with new cache settings (if needed)
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && cat >> .env << 'EOF'

# Cache Configuration (v1.2.0)
CACHE_TYPE=simple
CACHE_DEFAULT_TIMEOUT=3600
WMS_CACHE_TIMEOUT=300
EOF
"
```

### Step 5: Update Systemd Service (If needed)

```bash
# Copy new service file
ssh razinka@laguna.ku.lt "sudo cp /tmp/marbefes-bbt.service /etc/systemd/system/"

# Or update existing service file
ssh razinka@laguna.ku.lt "sudo nano /etc/systemd/system/marbefes-bbt.service"
```

Update the service file to use Gunicorn config:

```ini
[Service]
ExecStart=/var/www/marbefes-bbt/venv/bin/gunicorn -c gunicorn_config.py app:app
```

```bash
# Reload systemd
ssh razinka@laguna.ku.lt "sudo systemctl daemon-reload"
```

### Step 6: Start Application

```bash
# Start with systemd
ssh razinka@laguna.ku.lt "sudo systemctl start marbefes-bbt"

# Check status
ssh razinka@laguna.ku.lt "sudo systemctl status marbefes-bbt"

# View logs
ssh razinka@laguna.ku.lt "sudo journalctl -u marbefes-bbt -n 50 --no-pager"
```

---

## Verification

### Step 1: Check Application is Running

```bash
# Check processes
ssh razinka@laguna.ku.lt "pgrep -a gunicorn | grep marbefes"

# Check listening ports
ssh razinka@laguna.ku.lt "sudo netstat -tulpn | grep gunicorn"
```

### Step 2: Test Endpoints

```bash
# Test main page
curl -I http://laguna.ku.lt/BBTS

# Test health endpoint
curl http://laguna.ku.lt/BBTS/health | jq

# Test API
curl http://laguna.ku.lt/BBTS/api/layers | jq '.[:2]'

# Test vector layers
curl http://laguna.ku.lt/BBTS/api/vector/layers | jq
```

### Step 3: Run Health Monitor

```bash
# Run health check from local machine
python monitor_health.py --url http://laguna.ku.lt/BBTS

# Or run on server
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && \
  source venv/bin/activate && \
  python monitor_health.py --url http://laguna.ku.lt/BBTS"
```

### Step 4: Check Application Logs

```bash
# Application logs
ssh razinka@laguna.ku.lt "tail -50 /var/www/marbefes-bbt/logs/emodnet_viewer.log"

# Gunicorn logs
ssh razinka@laguna.ku.lt "tail -50 /var/www/marbefes-bbt/logs/gunicorn_access.log"
ssh razinka@laguna.ku.lt "tail -50 /var/www/marbefes-bbt/logs/gunicorn_error.log"

# Systemd logs
ssh razinka@laguna.ku.lt "sudo journalctl -u marbefes-bbt -n 100"
```

---

## Optional: Redis Cache Setup

If you want to enable Redis caching for better performance:

### Step 1: Install Redis

```bash
ssh razinka@laguna.ku.lt "sudo apt-get update && sudo apt-get install -y redis-server"
```

### Step 2: Configure Redis

```bash
ssh razinka@laguna.ku.lt "sudo nano /etc/redis/redis.conf"

# Add/modify:
# bind 127.0.0.1
# maxmemory 256mb
# maxmemory-policy allkeys-lru
```

### Step 3: Start Redis

```bash
ssh razinka@laguna.ku.lt "sudo systemctl enable redis-server"
ssh razinka@laguna.ku.lt "sudo systemctl start redis-server"
ssh razinka@laguna.ku.lt "redis-cli ping"  # Should return PONG
```

### Step 4: Update Application Configuration

```bash
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && \
  sed -i 's/CACHE_TYPE=simple/CACHE_TYPE=redis/' .env && \
  cat .env | grep CACHE"
```

### Step 5: Restart Application

```bash
ssh razinka@laguna.ku.lt "sudo systemctl restart marbefes-bbt"
```

---

## Monitoring Setup

### Setup Cron Job for Health Monitoring

```bash
# Edit crontab on server
ssh razinka@laguna.ku.lt "crontab -e"

# Add this line:
*/5 * * * * /var/www/marbefes-bbt/venv/bin/python /var/www/marbefes-bbt/monitor_health.py --url http://laguna.ku.lt/BBTS --quiet || echo "MARBEFES health check failed at $(date)" | logger -t marbefes-monitor
```

### View Monitoring Logs

```bash
ssh razinka@laguna.ku.lt "grep marbefes-monitor /var/log/syslog | tail -20"
```

---

## Troubleshooting

### Issue: Service Fails to Start

```bash
# Check detailed error
ssh razinka@laguna.ku.lt "sudo journalctl -u marbefes-bbt -n 100 --no-pager"

# Check if port is in use
ssh razinka@laguna.ku.lt "sudo lsof -i :8000"

# Test application manually
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && \
  source venv/bin/activate && \
  python app.py"
```

### Issue: Import Errors

```bash
# Check Python environment
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && \
  source venv/bin/activate && \
  python -c 'from app import app; print(\"OK\")'"

# Reinstall dependencies
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && \
  source venv/bin/activate && \
  pip install -r requirements.txt --force-reinstall"
```

### Issue: Gunicorn Not Found

```bash
# Install Gunicorn explicitly
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && \
  source venv/bin/activate && \
  pip install gunicorn>=21.2.0"
```

### Issue: Permission Errors

```bash
# Fix ownership
ssh razinka@laguna.ku.lt "sudo chown -R razinka:razinka /var/www/marbefes-bbt"

# Fix log directory
ssh razinka@laguna.ku.lt "mkdir -p /var/www/marbefes-bbt/logs && \
  chmod 755 /var/www/marbefes-bbt/logs"
```

---

## Rollback Procedure

If deployment fails:

```bash
# Stop current service
ssh razinka@laguna.ku.lt "sudo systemctl stop marbefes-bbt"

# Restore from backup
BACKUP_FILE=$(ssh razinka@laguna.ku.lt "ls -t /backup/marbefes-bbt-backup-*.tar.gz | head -1")
ssh razinka@laguna.ku.lt "sudo tar -xzf $BACKUP_FILE -C /var/www/marbefes-bbt/"

# Restart service
ssh razinka@laguna.ku.lt "sudo systemctl start marbefes-bbt"
```

---

## Post-Deployment Tasks

### 1. Update Documentation

```bash
# Document deployment in server notes
ssh razinka@laguna.ku.lt "echo '$(date): Deployed v1.2.0 with Gunicorn and monitoring' >> /var/www/marbefes-bbt/DEPLOYMENT_LOG.txt"
```

### 2. Run Tests

```bash
# Run API tests from server
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && \
  source venv/bin/activate && \
  pytest tests/test_api_endpoints.py -v --tb=short"
```

### 3. Browser Testing

Open in browser and verify:
- ✅ Homepage: http://laguna.ku.lt/BBTS
- ✅ Map loads correctly
- ✅ BBT navigation works
- ✅ Vector layers display
- ✅ WMS layers load
- ✅ No console errors (F12)

---

## Performance Monitoring

### Check Worker Processes

```bash
ssh razinka@laguna.ku.lt "ps aux | grep gunicorn | wc -l"
# Should show multiple workers (CPU count * 2 + 1)
```

### Monitor Request Times

```bash
ssh razinka@laguna.ku.lt "tail -f /var/www/marbefes-bbt/logs/gunicorn_access.log"
```

### Check Memory Usage

```bash
ssh razinka@laguna.ku.lt "ps aux | grep gunicorn | awk '{sum+=\$6} END {print \"Memory: \" sum/1024 \" MB\"}'"
```

---

## Quick Commands Reference

```bash
# Status
ssh razinka@laguna.ku.lt "sudo systemctl status marbefes-bbt"

# Start
ssh razinka@laguna.ku.lt "sudo systemctl start marbefes-bbt"

# Stop
ssh razinka@laguna.ku.lt "sudo systemctl stop marbefes-bbt"

# Restart
ssh razinka@laguna.ku.lt "sudo systemctl restart marbefes-bbt"

# Logs (follow)
ssh razinka@laguna.ku.lt "sudo journalctl -u marbefes-bbt -f"

# Health check
python monitor_health.py --url http://laguna.ku.lt/BBTS
```

---

## Success Criteria

Deployment is successful when:
- ✅ Service starts without errors
- ✅ Health endpoint returns 200 OK
- ✅ Main page loads in browser
- ✅ All API endpoints respond correctly
- ✅ Vector layers display on map
- ✅ No errors in application logs
- ✅ Gunicorn workers are running
- ✅ Health monitor returns "healthy" status

---

**Deployment Date:** October 13, 2025
**Version:** 1.2.0
**Deployed By:** Follow this guide step-by-step
