# 🚀 MARBEFES BBT - Subpath Deployment Guide

## Deploy at http://YOUR_SERVER/BBTS

This guide covers deploying the MARBEFES BBT Database application on a **subpath** (`/BBTS`) rather than the server root.

---

## Quick Deployment

### One-Command Deployment

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck
sudo ./deploy_subpath.sh
```

### Verify Deployment

```bash
sudo ./verify_subpath.sh
```

---

## What's Different from Root Deployment?

### Root Deployment
```
http://YOUR_SERVER/              → Application
http://YOUR_SERVER/api/layers    → API
```

### Subpath Deployment (This Guide)
```
http://YOUR_SERVER/BBTS          → Application
http://YOUR_SERVER/BBTS/api/layers → API
```

`★ Insight ─────────────────────────────────────`
**Subpath deployment architecture**: Using Werkzeug's `DispatcherMiddleware`, the Flask app is mounted at `/BBTS` while nginx handles the URL routing. This allows multiple applications to coexist on the same server at different paths (e.g., `/BBTS`, `/admin`, `/api`) without conflicts.
`─────────────────────────────────────────────────`

---

## How It Works

### 1. WSGI Wrapper (`wsgi_subpath.py`)
Instead of running Flask directly, we use a WSGI middleware wrapper:

```python
from werkzeug.middleware.dispatcher import DispatcherMiddleware
from app import app as flask_app

# Mount Flask application at /BBTS
application = DispatcherMiddleware(root_app, {
    '/BBTS': flask_app
})
```

This tells Gunicorn to serve the Flask app at the `/BBTS` path.

### 2. Nginx Configuration
Nginx proxies requests from `/BBTS` to the Gunicorn server:

```nginx
location /BBTS {
    proxy_pass http://marbefes_bbt/BBTS;
    proxy_set_header Host $host;
    # ... other headers
}
```

### 3. Systemd Service
The service runs Gunicorn with the WSGI wrapper:

```bash
gunicorn --config gunicorn_config.py wsgi_subpath:application
```

---

## Access URLs

### Main Application
- **Local**: http://localhost/BBTS
- **Network**: http://YOUR_SERVER_IP/BBTS
- **Domain**: http://your-domain.com/BBTS

### API Endpoints
- WMS Layers: http://localhost/BBTS/api/layers
- All Layers: http://localhost/BBTS/api/all-layers
- Vector Layers: http://localhost/BBTS/api/vector/layers
- Capabilities: http://localhost/BBTS/api/capabilities
- Legend: http://localhost/BBTS/api/legend/LAYER_NAME

### Static Files
- Logos: http://localhost/BBTS/logo/marbefes_02.png
- Static: http://localhost/BBTS/static/...

---

## Files Created

### New Subpath-Specific Files

| File | Purpose |
|------|---------|
| `wsgi_subpath.py` | WSGI wrapper to mount app at `/BBTS` |
| `nginx-subpath.conf` | Nginx configuration for subpath routing |
| `deploy_subpath.sh` | Automated subpath deployment script |
| `verify_subpath.sh` | Subpath-specific verification tests |

### Modified Configuration

**`.env` additions:**
```bash
APPLICATION_ROOT=/BBTS
PREFERRED_URL_SCHEME=http
```

**Systemd service:**
```ini
ExecStart=.../gunicorn ... wsgi_subpath:application
```

---

## Manual Deployment Steps

If you need to deploy manually:

### 1. Create WSGI Wrapper

Create `wsgi_subpath.py` (already included):
```python
from werkzeug.middleware.dispatcher import DispatcherMiddleware
from app import app as flask_app

application = DispatcherMiddleware(lambda e, s: Response("Root")(e, s), {
    '/BBTS': flask_app
})
```

### 2. Update Environment File

Add to `.env`:
```bash
APPLICATION_ROOT=/BBTS
PREFERRED_URL_SCHEME=http
```

### 3. Update Systemd Service

Change ExecStart in `/etc/systemd/system/marbefes-bbt.service`:
```ini
ExecStart=/var/www/marbefes-bbt/venv/bin/gunicorn \
    --config /var/www/marbefes-bbt/gunicorn_config.py \
    wsgi_subpath:application
```

### 4. Configure Nginx

Use the subpath nginx configuration:
```nginx
location /BBTS {
    proxy_pass http://marbefes_bbt/BBTS;
    # proxy headers...
}
```

### 5. Restart Services

```bash
sudo systemctl daemon-reload
sudo systemctl restart marbefes-bbt
sudo systemctl reload nginx
```

---

## Testing the Deployment

### Quick Tests

```bash
# Main page
curl -I http://localhost/BBTS

# API endpoint
curl http://localhost/BBTS/api/layers | jq '.[:3]'

# Vector layers
curl http://localhost/BBTS/api/vector/layers

# Check response headers
curl -I http://localhost/BBTS/api/all-layers
```

### Automated Testing

```bash
sudo ./verify_subpath.sh
```

This tests:
- ✓ File system and WSGI wrapper presence
- ✓ Systemd service configuration
- ✓ Nginx subpath routing
- ✓ All API endpoints at `/BBTS/*`
- ✓ URL pattern variations
- ✓ Performance metrics

---

## Troubleshooting

### 404 Not Found at /BBTS

**Problem**: Accessing `/BBTS` returns 404

**Solutions**:
```bash
# Check WSGI wrapper is used
grep "wsgi_subpath" /etc/systemd/system/marbefes-bbt.service

# Check nginx configuration
grep "location /BBTS" /etc/nginx/sites-available/marbefes-bbt

# Check application logs
sudo journalctl -u marbefes-bbt -n 50
```

### Static Files Not Loading

**Problem**: Images/CSS not loading

**Check nginx static file locations**:
```nginx
location /BBTS/logo/ {
    alias /var/www/marbefes-bbt/LOGO/;
}
```

Test:
```bash
curl -I http://localhost/BBTS/logo/marbefes_02.png
```

### API Redirects Incorrectly

**Problem**: API calls redirect to wrong paths

**Check nginx redirect settings**:
```nginx
proxy_redirect ~^/(.*)$ /BBTS/$1;
proxy_redirect / /BBTS/;
```

### Root Path Shows Error

**Problem**: Accessing `/` (root) fails

**Expected behavior**: Root should show a simple message with link to `/BBTS`

Check:
```bash
curl http://localhost/
# Should show: "BBT Database is available at: /BBTS"
```

---

## Advantages of Subpath Deployment

### ✅ Multiple Apps on Same Server
- `/BBTS` - This application
- `/admin` - Admin panel
- `/docs` - Documentation
- `/api` - Shared API gateway

### ✅ Better Organization
- Clear separation of applications
- Easier nginx configuration management
- Simpler SSL certificate setup (one cert for all apps)

### ✅ Resource Sharing
- Single nginx instance
- Shared SSL/TLS termination
- Unified logging and monitoring

`★ Insight ─────────────────────────────────────`
**Production best practice**: Subpath deployment is ideal for microservices architecture where multiple independent applications need to coexist. It provides clean URL namespacing, easier reverse proxy management, and better resource utilization compared to subdomain-based separation.
`─────────────────────────────────────────────────`

---

## Comparison: Subpath vs Root

| Feature | Root Deployment | Subpath Deployment |
|---------|----------------|-------------------|
| **URL** | `http://server/` | `http://server/BBTS` |
| **WSGI** | `app:app` | `wsgi_subpath:application` |
| **Nginx** | `location /` | `location /BBTS` |
| **Multiple Apps** | Requires subdomains | ✓ Coexist on same domain |
| **SSL Certs** | One per subdomain | ✓ Single cert |
| **Complexity** | Simpler | Slightly more complex |

---

## Switching Between Deployments

### From Root to Subpath

```bash
# Stop current service
sudo systemctl stop marbefes-bbt

# Deploy subpath version
sudo ./deploy_subpath.sh

# New URL: http://server/BBTS
```

### From Subpath to Root

```bash
# Stop current service
sudo systemctl stop marbefes-bbt

# Deploy root version
sudo ./deploy_production.sh

# New URL: http://server/
```

---

## Essential Commands

### Service Management
```bash
# Status
sudo systemctl status marbefes-bbt

# Restart
sudo systemctl restart marbefes-bbt

# Logs
sudo journalctl -u marbefes-bbt -f

# Stop
sudo systemctl stop marbefes-bbt
```

### Testing
```bash
# Test main page
curl -I http://localhost/BBTS

# Test API
curl http://localhost/BBTS/api/layers

# Full verification
sudo ./verify_subpath.sh
```

### Nginx
```bash
# Test configuration
sudo nginx -t

# Reload (no downtime)
sudo systemctl reload nginx

# View logs
sudo tail -f /var/log/nginx/marbefes-bbt-access.log
```

---

## Configuration Files

### `.env` (Subpath-Specific Settings)
```bash
FLASK_ENV=production
FLASK_DEBUG=False
APPLICATION_ROOT=/BBTS           # ← Subpath configuration
PREFERRED_URL_SCHEME=http
```

### Systemd Service
```ini
[Service]
ExecStart=/var/www/marbefes-bbt/venv/bin/gunicorn \
    --config gunicorn_config.py \
    wsgi_subpath:application      # ← Uses subpath wrapper
```

### Nginx Configuration
```nginx
location /BBTS {                  # ← Subpath routing
    proxy_pass http://marbefes_bbt/BBTS;
    proxy_set_header Host $host;
    # ... proxy headers
}
```

---

## URL Examples

### Working URLs ✓
```
http://localhost/BBTS
http://localhost/BBTS/
http://localhost/BBTS/api/layers
http://localhost/BBTS/api/all-layers
http://localhost/BBTS/logo/marbefes_02.png
```

### Won't Work ✗
```
http://localhost/              (shows redirect message)
http://localhost/api/layers    (404 - missing /BBTS prefix)
```

---

## Production Checklist

- [ ] Deployed with `sudo ./deploy_subpath.sh`
- [ ] Verified with `sudo ./verify_subpath.sh`
- [ ] Tested at `http://YOUR_SERVER/BBTS`
- [ ] API endpoints accessible at `/BBTS/api/*`
- [ ] Static files loading correctly
- [ ] Nginx configuration includes `location /BBTS`
- [ ] Service uses `wsgi_subpath:application`
- [ ] `.env` has `APPLICATION_ROOT=/BBTS`
- [ ] SSL configured (optional)
- [ ] Logs are clean (no errors)

---

## Next Steps

1. **Test the application**: http://YOUR_SERVER_IP/BBTS
2. **Configure DNS** (optional): Point domain to server
3. **Setup SSL**: `sudo certbot --nginx`
4. **Configure firewall**: Allow ports 80/443
5. **Setup monitoring**: Watch logs and performance

---

## Support

### Quick Reference Commands
```bash
# Deploy
sudo ./deploy_subpath.sh

# Verify
sudo ./verify_subpath.sh

# Test
curl http://localhost/BBTS/api/layers

# Logs
sudo journalctl -u marbefes-bbt -f
```

### Documentation Files
- `SUBPATH_DEPLOYMENT.md` - This guide
- `PRODUCTION_DEPLOYMENT.md` - Root deployment guide
- `DEPLOYMENT_QUICKSTART.md` - Quick reference
- `CLAUDE.md` - Project architecture

---

**🎉 Your application is now accessible at http://YOUR_SERVER/BBTS**
