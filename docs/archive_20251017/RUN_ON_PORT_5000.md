# Running MARBEFES BBT on Port 5000 (laguna.ku.lt)

Quick guide to deploy and run the application on port 5000.

**Server:** laguna.ku.lt
**Port:** 5000
**URL:** http://laguna.ku.lt:5000

---

## Quick Start (Automated)

### Option 1: One-Command Deployment

```bash
./run_port_5000.sh
```

This script will:
1. ✅ Test SSH connection
2. ✅ Stop any existing processes on port 5000
3. ✅ Deploy all files
4. ✅ Install dependencies
5. ✅ Start Gunicorn on port 5000
6. ✅ Verify deployment

**Expected Output:**
```
========================================
MARBEFES BBT - Deploy to Port 5000
========================================
[1/6] Testing SSH connection...
✓ Connected
[2/6] Stopping any existing processes on port 5000...
✓ Stopped
[3/6] Deploying files...
✓ Files deployed
[4/6] Installing dependencies...
✓ Dependencies installed
[5/6] Starting application on port 5000...
✓ Application started
[6/6] Verifying deployment...
✓ Gunicorn running with 9 workers
✓ Health endpoint responding on port 5000

========================================
Deployment Complete!
========================================

Application URL: http://laguna.ku.lt:5000
Health Check: http://laguna.ku.lt:5000/health
```

---

## Manual Deployment

### Step 1: Connect to Server

```bash
ssh razinka@laguna.ku.lt
cd /var/www/marbefes-bbt
```

### Step 2: Stop Existing Processes

```bash
# Stop any existing Gunicorn/Flask processes
pkill -f 'gunicorn.*app:app'
pkill -f 'python.*app.py'
```

### Step 3: Pull Latest Code (if using git)

```bash
git pull origin main
```

Or deploy files from local:
```bash
# From local machine
rsync -avz --exclude='venv' --exclude='__pycache__' \
  ./ razinka@laguna.ku.lt:/var/www/marbefes-bbt/
```

### Step 4: Install/Update Dependencies

```bash
source venv/bin/activate
pip install -r requirements.txt
```

### Step 5: Start Application

#### Option A: Using Gunicorn (Recommended for Production)

```bash
# Start in background
nohup gunicorn -c gunicorn_config.py app:app > logs/gunicorn.log 2>&1 &

# Or start in foreground (for testing)
gunicorn -c gunicorn_config.py app:app
```

#### Option B: Using Flask Development Server (Testing Only)

```bash
# Set port explicitly
export FLASK_RUN_PORT=5000
python app.py
```

#### Option C: Using start_production.sh

```bash
./start_production.sh
```

### Step 6: Verify Running

```bash
# Check processes
pgrep -a gunicorn

# Check port
netstat -tulpn | grep 5000

# Test endpoint
curl http://localhost:5000/health
```

---

## Configuration

### Port Configuration

The port is configured in multiple places (all default to 5000):

**1. gunicorn_config.py:**
```python
bind = os.getenv('GUNICORN_BIND', '0.0.0.0:5000')
```

**2. app.py (for Flask dev server):**
```python
port = int(os.environ.get('FLASK_RUN_PORT', 5000))
```

**3. Environment Variable (optional):**
```bash
export GUNICORN_BIND="0.0.0.0:5000"
export FLASK_RUN_PORT=5000
```

### To Change Port

If you need a different port:

```bash
# Method 1: Environment variable
export GUNICORN_BIND="0.0.0.0:8080"
gunicorn -c gunicorn_config.py app:app

# Method 2: Command line
gunicorn --bind 0.0.0.0:8080 -c gunicorn_config.py app:app

# Method 3: Flask dev server
export FLASK_RUN_PORT=8080
python app.py
```

---

## Verification

### 1. Check Application is Running

```bash
# From server
curl -I http://localhost:5000

# From local machine
curl -I http://laguna.ku.lt:5000
```

### 2. Test Health Endpoint

```bash
curl http://laguna.ku.lt:5000/health | jq
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2025-10-13T...",
  "version": "1.2.0",
  "components": {
    "vector_support": {
      "available": true,
      "status": "operational"
    },
    "wms_service": {
      "url": "https://ows.emodnet-seabedhabitats.eu/...",
      "status": "operational"
    },
    "cache": {
      "type": "simple",
      "status": "operational"
    }
  }
}
```

### 3. Test API Endpoints

```bash
# WMS Layers
curl http://laguna.ku.lt:5000/api/layers | jq '.[:2]'

# Vector Layers
curl http://laguna.ku.lt:5000/api/vector/layers | jq

# All Layers
curl http://laguna.ku.lt:5000/api/all-layers | jq '.vector_support'
```

### 4. Test in Browser

Open: **http://laguna.ku.lt:5000**

Verify:
- ✅ Map loads
- ✅ BBT navigation works
- ✅ Vector layers display
- ✅ WMS layers load
- ✅ No console errors (F12)

### 5. Run Health Monitor

From local machine:
```bash
python monitor_health.py --url http://laguna.ku.lt:5000
```

---

## Monitoring

### View Logs

```bash
# Gunicorn logs
tail -f /var/www/marbefes-bbt/logs/gunicorn.log

# Application logs
tail -f /var/www/marbefes-bbt/logs/emodnet_viewer.log

# Access logs
tail -f /var/www/marbefes-bbt/logs/gunicorn_access.log

# Error logs
tail -f /var/www/marbefes-bbt/logs/gunicorn_error.log
```

### Check Processes

```bash
# All Gunicorn processes
pgrep -a gunicorn

# Count workers
pgrep -f 'gunicorn.*app:app' | wc -l

# Process tree
ps auxf | grep gunicorn

# Memory usage
ps aux | grep gunicorn | awk '{sum+=$6} END {print "Memory: " sum/1024 " MB"}'
```

### Monitor Performance

```bash
# Real-time request monitoring
tail -f logs/gunicorn_access.log | awk '{print $NF}'

# Request count
grep -c "GET /" logs/gunicorn_access.log

# Error count
grep -c "500" logs/gunicorn_access.log
```

---

## Troubleshooting

### Issue: Port Already in Use

```bash
# Find process using port 5000
sudo lsof -i :5000

# Kill specific process
sudo kill <PID>

# Or kill all gunicorn processes
pkill -f gunicorn
```

### Issue: Application Won't Start

```bash
# Check for Python errors
cd /var/www/marbefes-bbt
source venv/bin/activate
python -c "from app import app; print('OK')"

# Check Gunicorn is installed
gunicorn --version

# Test manual start
gunicorn --bind 0.0.0.0:5000 app:app
```

### Issue: Connection Refused

```bash
# Check if application is listening
netstat -tulpn | grep 5000

# Check firewall
sudo ufw status
sudo ufw allow 5000/tcp  # If needed

# Test local connection
curl http://localhost:5000/health

# Test remote connection
curl http://laguna.ku.lt:5000/health
```

### Issue: 502 Bad Gateway (if behind proxy)

```bash
# Check Gunicorn is running
pgrep -a gunicorn

# Check Gunicorn can be reached
curl http://127.0.0.1:5000/health

# Check Nginx configuration (if applicable)
sudo nginx -t
sudo systemctl reload nginx
```

### Issue: Import Errors

```bash
# Reinstall dependencies
cd /var/www/marbefes-bbt
source venv/bin/activate
pip install -r requirements.txt --force-reinstall

# Check specific package
python -c "import flask; print(flask.__version__)"
python -c "import geopandas; print(geopandas.__version__)"
```

---

## Starting/Stopping

### Start

```bash
# Using Gunicorn
cd /var/www/marbefes-bbt
nohup venv/bin/gunicorn -c gunicorn_config.py app:app \
  > logs/gunicorn.log 2>&1 &

# Or using production script
./start_production.sh
```

### Stop

```bash
# Graceful stop (SIGTERM)
pkill -f 'gunicorn.*app:app'

# Force kill (SIGKILL)
pkill -9 -f 'gunicorn.*app:app'

# Stop specific PID
kill <PID>
```

### Restart

```bash
# Stop and start
pkill -f 'gunicorn.*app:app'
sleep 2
nohup venv/bin/gunicorn -c gunicorn_config.py app:app \
  > logs/gunicorn.log 2>&1 &
```

### Reload (Zero-Downtime)

```bash
# Send HUP signal to master process
kill -HUP <master_pid>

# Or use Gunicorn's reload
pkill -HUP -f 'gunicorn.*app:app'
```

---

## Performance Tuning

### Worker Count

Default: `(2 × CPU cores) + 1`

To adjust:
```bash
# Set explicitly
export GUNICORN_WORKERS=8
gunicorn -c gunicorn_config.py app:app

# Or modify gunicorn_config.py
nano gunicorn_config.py
# Change: workers = 8
```

### Timeout

For slow WMS requests:
```bash
# Set longer timeout
export GUNICORN_TIMEOUT=60
gunicorn -c gunicorn_config.py app:app
```

---

## URLs Reference

**Main Application:**
- Homepage: http://laguna.ku.lt:5000
- Health Check: http://laguna.ku.lt:5000/health
- Test Page: http://laguna.ku.lt:5000/test

**API Endpoints:**
- WMS Layers: http://laguna.ku.lt:5000/api/layers
- All Layers: http://laguna.ku.lt:5000/api/all-layers
- Vector Layers: http://laguna.ku.lt:5000/api/vector/layers
- Factsheets: http://laguna.ku.lt:5000/api/factsheets

**Static Files:**
- Logo: http://laguna.ku.lt:5000/logo/marbefes_02.png

---

## Quick Commands

```bash
# Deploy
./run_port_5000.sh

# Start
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && \
  nohup venv/bin/gunicorn -c gunicorn_config.py app:app \
  > logs/gunicorn.log 2>&1 &"

# Stop
ssh razinka@laguna.ku.lt "pkill -f 'gunicorn.*app:app'"

# Restart
ssh razinka@laguna.ku.lt "pkill -f 'gunicorn.*app:app' && \
  cd /var/www/marbefes-bbt && \
  nohup venv/bin/gunicorn -c gunicorn_config.py app:app \
  > logs/gunicorn.log 2>&1 &"

# Check Status
ssh razinka@laguna.ku.lt "pgrep -a gunicorn"

# View Logs
ssh razinka@laguna.ku.lt "tail -50 /var/www/marbefes-bbt/logs/gunicorn.log"

# Health Check
curl http://laguna.ku.lt:5000/health | jq
```

---

**Last Updated:** October 13, 2025
**Version:** 1.2.0
**Port:** 5000
