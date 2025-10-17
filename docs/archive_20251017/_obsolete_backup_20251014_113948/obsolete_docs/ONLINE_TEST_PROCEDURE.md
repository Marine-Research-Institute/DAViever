# Production Server Testing Procedure

## Current Status: 502 Bad Gateway ❌

**URL:** http://laguna.ku.lt/BBTS/
**Server:** razinka@laguna.ku.lt
**Issue:** Flask application (marbefes-bbt service) is not running

---

## Step 1: Connect to Server

```bash
ssh razinka@laguna.ku.lt
```

If SSH fails, you may need to:
- Start SSH agent: `eval $(ssh-agent)`
- Add your key: `ssh-add ~/.ssh/id_ed25519`

---

## Step 2: Check Service Status

```bash
# Check if service is running
sudo systemctl status marbefes-bbt

# Check recent logs
sudo journalctl -u marbefes-bbt -n 50 --no-pager

# Or check application logs
tail -50 /var/www/marbefes-bbt/logs/emodnet_viewer.log
```

---

## Step 3: Check Application Files

```bash
cd /var/www/marbefes-bbt

# Check if files are present
ls -la app.py templates/index.html

# Check if virtual environment works
./venv/bin/python -c "import flask; print('Flask OK')"

# Check if dependencies are installed
./venv/bin/pip list | grep -E "Flask|geopandas"
```

---

## Step 4: Start/Restart Service

### Option A: Restart Service
```bash
sudo systemctl restart marbefes-bbt
sudo systemctl status marbefes-bbt
```

### Option B: Check Service Configuration
```bash
# View service configuration
sudo systemctl cat marbefes-bbt

# Check if service is enabled
sudo systemctl is-enabled marbefes-bbt
```

### Option C: Manual Test (if service won't start)
```bash
cd /var/www/marbefes-bbt

# Test if app runs manually
./venv/bin/python app.py

# If it starts, check what error prevents service from starting
```

---

## Step 5: Common Issues & Fixes

### Issue: Missing Dependencies
```bash
cd /var/www/marbefes-bbt
./venv/bin/pip install -r requirements.txt
sudo systemctl restart marbefes-bbt
```

### Issue: Permission Problems
```bash
# Check file ownership
ls -la /var/www/marbefes-bbt/

# Fix if needed (replace 'www-data' with correct user from service file)
sudo chown -R www-data:www-data /var/www/marbefes-bbt/
```

### Issue: Port Already in Use
```bash
# Check what's using port 5000
sudo lsof -i :5000

# Or check from systemd
sudo systemctl status marbefes-bbt
```

### Issue: Environment Variables Not Set
```bash
# Check if .env file exists
cat /var/www/marbefes-bbt/.env

# If missing, create from example
cp .env.example .env
# Edit .env and set SECRET_KEY
```

---

## Step 6: Verify Deployment

Once service is running, test from your local machine:

```bash
# Test main page
curl -I http://laguna.ku.lt/BBTS/

# Expected: HTTP/1.1 200 OK

# Test health endpoint
curl http://laguna.ku.lt/BBTS/health | python -m json.tool

# Expected: {"status": "healthy", ...}

# Test logo
curl -I http://laguna.ku.lt/BBTS/logo/marbefes_02.png

# Expected: HTTP/1.1 200 OK

# Test API
curl http://laguna.ku.lt/BBTS/api/layers | python -m json.tool

# Expected: JSON array of layers
```

---

## Step 7: Browser Testing Checklist

Open: http://laguna.ku.lt/BBTS/

✅ Check:
- [ ] Page loads (no 502 error)
- [ ] Logo appears in header
- [ ] Map displays
- [ ] BBT navigation buttons visible
- [ ] Layer selector populates
- [ ] No 404 errors in browser console (F12)
- [ ] BBT features load when clicking navigation
- [ ] Hover tooltips show area calculations
- [ ] Layer opacity controls work

---

## Expected Service Configuration

The service should be configured something like:

```ini
[Unit]
Description=MARBEFES BBT Database Application
After=network.target

[Service]
Type=notify
User=www-data
Group=www-data
WorkingDirectory=/var/www/marbefes-bbt
Environment="PATH=/var/www/marbefes-bbt/venv/bin"
Environment="FLASK_ENV=production"
EnvironmentFile=/var/www/marbefes-bbt/.env
ExecStart=/var/www/marbefes-bbt/venv/bin/gunicorn --workers 4 --bind unix:/var/www/marbefes-bbt/marbefes-bbt.sock app:app
Restart=always

[Install]
WantedBy=multi-user.target
```

---

## Quick Diagnostic Script

Run this on the server for a full diagnostic:

```bash
#!/bin/bash
echo "=== MARBEFES BBT Diagnostics ==="
echo ""
echo "1. Service Status:"
sudo systemctl status marbefes-bbt --no-pager
echo ""
echo "2. Recent Logs:"
sudo journalctl -u marbefes-bbt -n 20 --no-pager
echo ""
echo "3. Application Files:"
ls -la /var/www/marbefes-bbt/app.py
ls -la /var/www/marbefes-bbt/templates/index.html
echo ""
echo "4. Port Check:"
sudo lsof -i :5000 || echo "Port 5000 not in use"
echo ""
echo "5. Python Environment:"
cd /var/www/marbefes-bbt
./venv/bin/python --version
./venv/bin/pip list | grep -E "Flask|geopandas" | head -5
echo ""
echo "=== End Diagnostics ==="
```

Save as `diagnose.sh`, run with `bash diagnose.sh`

---

## Contact Info

If issues persist, check:
- Application logs: `/var/www/marbefes-bbt/logs/emodnet_viewer.log`
- System logs: `sudo journalctl -u marbefes-bbt --since "1 hour ago"`
- Nginx logs: `sudo tail -100 /var/log/nginx/error.log`

---

## Summary

**Current State:** 502 Bad Gateway indicates Flask app not responding
**Most Likely Cause:** Service stopped or failed to start
**Quick Fix:** `sudo systemctl restart marbefes-bbt`
**After Fix:** Run Step 6 verification tests
