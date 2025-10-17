# Deployment Isolation - Multiple Flask Apps on laguna.ku.lt

This document explains how the MarineSABRES DA Tool and MARBEFES BBT applications coexist on the same server without conflicts.

## Current Applications on laguna.ku.lt

### 1. MARBEFES BBT Database (Existing)
- **URL:** http://laguna.ku.lt/BBTS/
- **Service:** `marbefes-bbt.service`
- **Port:** 5000 (127.0.0.1:5000)
- **App Directory:** `/var/www/marbefes-bbt/`
- **Nginx Config:** `/etc/nginx/sites-available/default.d-bbts.conf`
- **Status:** Running

### 2. MarineSABRES Demonstration Area Tool (New)
- **URL:** http://laguna.ku.lt/DA/
- **Service:** `marinesabres-da.service`
- **Port:** 5002 (127.0.0.1:5002)
- **App Directory:** `/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer/`
- **Nginx Config:** `/etc/nginx/sites-available/default.d-da.conf`
- **Status:** Not yet deployed

## Isolation Strategy

### Port Separation
```
BBTS App:     127.0.0.1:5000  (Gunicorn)
DA Tool:      127.0.0.1:5002  (Gunicorn)
```
No port conflicts - each app binds to a different port.

### URL Path Separation
```
http://laguna.ku.lt/BBTS/  → MARBEFES BBT Database
http://laguna.ku.lt/DA/    → MarineSABRES DA Tool
```
Nginx routes requests based on URL path prefix.

### Service Separation
```
systemd services:
  - marbefes-bbt.service     (existing)
  - marinesabres-da.service  (new)
```
Independent systemd units - can be managed separately.

### Nginx Configuration Structure

**Main nginx config** (`/etc/nginx/sites-available/default`):
```nginx
server {
    listen 80 default_server;
    server_name _;

    # Include application-specific configs
    include /etc/nginx/sites-available/default.d-bbts.conf;
    include /etc/nginx/sites-available/default.d-da.conf;    # Will be added

    # Other locations (/, /qgisserver, etc.)
}
```

**BBTS Config** (`default.d-bbts.conf`):
```nginx
location /BBTS {
    rewrite ^/BBTS(/.*)$ $1 break;
    proxy_pass http://127.0.0.1:5000;
    proxy_set_header X-Script-Name /BBTS;
}
```

**DA Tool Config** (`default.d-da.conf`):
```nginx
location /DA {
    rewrite ^/DA(/.*)$ $1 break;
    proxy_pass http://127.0.0.1:5002;
    proxy_set_header X-Script-Name /DA;
}
```

## Resource Isolation

### Process Isolation
Each application runs with its own:
- Gunicorn master process
- Worker processes (auto-scaled based on CPU)
- Python virtual environment
- Application code directory

### Log File Separation
```
BBTS:
  - /var/www/marbefes-bbt/logs/

DA Tool:
  - /home/razinka/OneDrive/.../DAViewer/logs/
```

### Configuration Separation
```
BBTS:
  - Systemd: /etc/systemd/system/marbefes-bbt.service
  - Gunicorn: /var/www/marbefes-bbt/gunicorn_config.py
  - Environment: /var/www/marbefes-bbt/.env

DA Tool:
  - Systemd: /etc/systemd/system/marinesabres-da.service
  - Gunicorn: .../DAViewer/gunicorn.conf.py
  - Environment: .../DAViewer/.env
```

## Deployment Safety

### No Conflicts
- ✅ Different ports (5000 vs 5002)
- ✅ Different URL paths (/BBTS/ vs /DA/)
- ✅ Different systemd services
- ✅ Different application directories
- ✅ Different nginx config files
- ✅ Different log directories
- ✅ Independent virtual environments

### Deployment of DA Tool Won't Affect BBTS
When deploying the DA Tool:
1. BBTS service keeps running on port 5000
2. Only nginx configuration is updated (include added)
3. New service is created independently
4. No changes to BBTS code or configuration
5. Nginx gracefully reloads (no downtime)

## Service Management

### Managing Both Applications

**Check all services:**
```bash
systemctl status marbefes-bbt
systemctl status marinesabres-da
```

**Restart individual service:**
```bash
# Only restarts BBTS, DA Tool unaffected
sudo systemctl restart marbefes-bbt

# Only restarts DA Tool, BBTS unaffected
sudo systemctl restart marinesabres-da
```

**View logs separately:**
```bash
# BBTS logs
sudo journalctl -u marbefes-bbt -f

# DA Tool logs
sudo journalctl -u marinesabres-da -f
```

## Testing Isolation

After deploying DA Tool, verify both apps work:

```bash
# Test BBTS (should still work)
curl -I http://laguna.ku.lt/BBTS/
curl http://laguna.ku.lt/BBTS/health

# Test DA Tool (new)
curl -I http://laguna.ku.lt/DA/
curl http://laguna.ku.lt/DA/health
```

## Architecture Diagram

```
Internet
   |
   v
nginx (port 80)
   |
   |-- /BBTS/  --> Gunicorn (127.0.0.1:5000) --> MARBEFES BBT Flask App
   |                |
   |                +-- Workers (4-8 processes)
   |                +-- /var/www/marbefes-bbt/
   |
   |-- /DA/    --> Gunicorn (127.0.0.1:5002) --> MarineSABRES DA Flask App
   |                |
   |                +-- Workers (4-8 processes)
   |                +-- .../DAViewer/
   |
   +-- /       --> Static HTML (default)
   +-- /qgisserver --> QGIS Server
   +-- /pgadmin --> pgAdmin
```

## Rollback Safety

If DA Tool deployment fails:
1. BBTS continues running normally
2. Use rollback script: `./scripts/rollback.sh`
3. Remove DA nginx include if needed:
   ```bash
   sudo sed -i '/default.d-da.conf/d' /etc/nginx/sites-available/default
   sudo systemctl reload nginx
   ```

## Summary

**Isolation Guarantees:**
- ✅ **No port conflicts** - Different ports
- ✅ **No URL conflicts** - Different paths
- ✅ **No process conflicts** - Independent services
- ✅ **No file conflicts** - Separate directories
- ✅ **No deployment conflicts** - BBTS untouched during DA deployment
- ✅ **Independent scaling** - Each app manages its own workers
- ✅ **Independent restarts** - Restart one without affecting the other

**Safe to Deploy:**
The MarineSABRES DA Tool deployment is completely isolated from the existing MARBEFES BBT application and will not interfere with its operation.

---

**Last Updated:** October 17, 2025
**Applications:** MARBEFES BBT + MarineSABRES DA Tool
