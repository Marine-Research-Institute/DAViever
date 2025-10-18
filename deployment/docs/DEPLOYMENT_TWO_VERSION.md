# MarineSABRES DA Tool - Two-Version Deployment Guide

## Overview

This document describes the two-version deployment strategy for the MarineSABRES Demonstration Area Tool, with separate development and production environments.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    laguna.ku.lt Server                       │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Production Version                Development Version       │
│  ├─ Directory: DAViewer-prod       ├─ Directory: DAViewer-dev│
│  ├─ URL: /DA/                      ├─ URL: :5003             │
│  ├─ Port: 5002 (internal)          ├─ Port: 5003 (external)  │
│  ├─ Service: marinesabres-da-prod  ├─ Service: marinesabres│
│  └─ Nginx: reverse proxy           │  -da-dev                │
│                                     └─ Nginx: direct access   │
└─────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/
├── DAViewer/                    # Original development directory (can be removed)
├── DAViewer-dev/                # Development version
│   ├── venv/                    # Dedicated virtual environment
│   ├── logs/                    # Development logs
│   ├── gunicorn.conf.py         # Dev config (port 5003, auto-reload)
│   ├── marinesabres-da-dev.service
│   └── ...
├── DAViewer-prod/               # Production version
│   ├── venv/                    # Dedicated virtual environment
│   ├── logs/                    # Production logs
│   ├── gunicorn.conf.py         # Prod config (port 5002, optimized)
│   ├── marinesabres-da-prod.service
│   └── ...
├── DAViewer/                    # Main repository
│   └── deployment/
│       ├── scripts/             # Deployment scripts
│       │   ├── deploy_dev_to_prod.sh
│       │   ├── deploy_dev_to_prod_git.sh
│       │   ├── setup_two_versions.sh
│       │   └── setup_git_workflow.sh
│       └── docs/                # Documentation
│           ├── nginx-combined.conf
│           └── ...
└── DAViewer-prod-backups/       # Automatic backups before deployment
    ├── backup_20251018_120000/
    ├── backup_20251018_140000/
    └── ...
```

## Access URLs

| Environment | URL | Port | Notes |
|------------|-----|------|-------|
| **Production** | http://laguna.ku.lt/DA/ | 5002 (internal) | Stable, public-facing |
| **Development** | http://laguna.ku.lt:5003 | 5003 (external) | Testing, auto-reload |
| **Prod Health** | http://laguna.ku.lt/DA/health | - | Health check endpoint |
| **Dev Health** | http://laguna.ku.lt:5003/health | - | Development health check |

## Initial Setup

### 1. Create Virtual Environments

```bash
# Development environment
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer-dev
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
deactivate

# Production environment
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer-prod
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
deactivate
```

### 2. Create Log Directories

```bash
mkdir -p DAViewer-dev/logs
mkdir -p DAViewer-prod/logs
mkdir -p DAViewer-prod-backups
```

### 3. Install Systemd Services

```bash
# Development service
sudo cp DAViewer-dev/marinesabres-da-dev.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable marinesabres-da-dev

# Production service
sudo cp DAViewer-prod/marinesabres-da-prod.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable marinesabres-da-prod
```

### 4. Configure Nginx

```bash
# Copy combined nginx configuration
sudo cp deployment/docs/nginx-combined.conf /etc/nginx/sites-available/default.d-marinesabres.conf

# Include in main nginx config
sudo nano /etc/nginx/sites-available/default

# Add this line inside the server block:
#   include /etc/nginx/sites-available/default.d-marinesabres.conf;

# Test and reload nginx
sudo nginx -t
sudo systemctl reload nginx
```

### 5. Configure Firewall (if needed)

```bash
# Allow port 5003 for development access
sudo ufw allow 5003/tcp comment 'MarineSABRES DA Development'
```

## Development Workflow

### 1. Make Changes in Development

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer-dev

# Edit code, templates, static files
# Changes are automatically reloaded (Gunicorn auto-reload enabled)
```

### 2. Test Development Version

```bash
# Access development version
curl http://laguna.ku.lt:5003/health

# View development logs
sudo journalctl -u marinesabres-da-dev -f

# Or check log files
tail -f DAViewer-dev/logs/gunicorn-error-dev.log
```

### 3. Deploy to Production

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES

# Run deployment script
./deployment/scripts/deploy_dev_to_prod.sh

# Script will:
# 1. Check development version is healthy
# 2. Show differences between dev and prod
# 3. Create automatic backup
# 4. Stop production service
# 5. Sync code from dev to prod
# 6. Update dependencies if needed
# 7. Start production service
# 8. Test production health
# 9. Rollback if tests fail
```

### 4. Rollback if Needed

```bash
# Automatic rollback (if deployment script detected issues)
# Or manual rollback:
./deployment/scripts/deploy_dev_to_prod.sh --rollback
```

## Service Management

### Start Services

```bash
# Development
sudo systemctl start marinesabres-da-dev

# Production
sudo systemctl start marinesabres-da-prod

# Both
sudo systemctl start marinesabres-da-dev marinesabres-da-prod
```

### Stop Services

```bash
# Development
sudo systemctl stop marinesabres-da-dev

# Production
sudo systemctl stop marinesabres-da-prod
```

### Restart Services

```bash
# Development
sudo systemctl restart marinesabres-da-dev

# Production
sudo systemctl restart marinesabres-da-prod
```

### Check Status

```bash
# Development
sudo systemctl status marinesabres-da-dev

# Production
sudo systemctl status marinesabres-da-prod

# Both
sudo systemctl status marinesabres-da-*
```

### View Logs

```bash
# Development logs (live)
sudo journalctl -u marinesabres-da-dev -f

# Production logs (live)
sudo journalctl -u marinesabres-da-prod -f

# Development logs (last 100 lines)
sudo journalctl -u marinesabres-da-dev -n 100

# Production logs (last 100 lines)
sudo journalctl -u marinesabres-da-prod -n 100
```

## Configuration Differences

### Development (DAViewer-dev/gunicorn.conf.py)

- **Port**: 5003 (external access)
- **Bind**: 0.0.0.0:5003
- **Workers**: 1 (easier debugging)
- **Auto-reload**: Enabled (watches templates/ and static/)
- **Timeout**: 60s (shorter for faster feedback)
- **Logging**: DEBUG level
- **Environment**: FLASK_ENV=development, FLASK_DEBUG=1
- **No subpath**: Direct port access

### Production (DAViewer-prod/gunicorn.conf.py)

- **Port**: 5002 (internal only)
- **Bind**: 127.0.0.1:5002
- **Workers**: Auto-scaled (CPU cores × 2 + 1)
- **Auto-reload**: Disabled
- **Timeout**: 120s (for WMS operations)
- **Logging**: INFO level
- **Environment**: FLASK_ENV=production, APPLICATION_ROOT=/DA
- **Subpath**: /DA/ via nginx reverse proxy

## Deployment Script Features

The `deploy_dev_to_prod.sh` script provides:

### Safety Features
- ✅ Pre-deployment health checks
- ✅ Automatic backups (keeps last 5)
- ✅ Rollback on failure
- ✅ Manual rollback support
- ✅ Confirmation before deployment

### Deployment Steps
1. Verify development is running and healthy
2. Show code differences
3. Create timestamped backup
4. Stop production service
5. Sync code (rsync with exclusions)
6. Update dependencies if changed
7. Install/update systemd service
8. Start production
9. Test production health and main page
10. Automatic rollback if tests fail

### Usage

```bash
# Normal deployment
./deployment/scripts/deploy_dev_to_prod.sh

# Rollback to previous version
./deployment/scripts/deploy_dev_to_prod.sh --rollback

# Help
./deployment/scripts/deploy_dev_to_prod.sh --help
```

## Best Practices

### Development
1. **Test thoroughly** on port 5003 before deploying
2. **Check logs** for errors: `sudo journalctl -u marinesabres-da-dev -f`
3. **Use browser dev tools** to inspect frontend issues
4. **Test all features** including WMS layers, research sites, legends

### Deployment
1. **Deploy during low-traffic periods** if possible
2. **Monitor production logs** after deployment: `sudo journalctl -u marinesabres-da-prod -f`
3. **Keep development running** for quick comparison if issues arise
4. **Test production immediately** after deployment
5. **Document changes** in git commit messages

### Maintenance
1. **Review backups** periodically (automatic cleanup keeps last 5)
2. **Update dependencies** regularly in development first
3. **Monitor disk space** (logs, backups, virtual environments)
4. **Keep development and production in sync** through regular deployments

## Troubleshooting

### Development Service Won't Start

```bash
# Check service status
sudo systemctl status marinesabres-da-dev

# Check logs
sudo journalctl -u marinesabres-da-dev -n 50

# Check if port is in use
sudo lsof -i :5003

# Check virtual environment
cd DAViewer-dev
source venv/bin/activate
python -c "import flask; print('OK')"
```

### Production Service Won't Start

```bash
# Check service status
sudo systemctl status marinesabres-da-prod

# Check logs
sudo journalctl -u marinesabres-da-prod -n 50

# Check if port is in use
sudo lsof -i :5002

# Test nginx configuration
sudo nginx -t
```

### Deployment Script Fails

```bash
# View last backup
ls -lt /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer-prod-backups | head

# Manual rollback
./deployment/scripts/deploy_dev_to_prod.sh --rollback

# Check permissions
ls -la deploy_dev_to_prod.sh
chmod +x deploy_dev_to_prod.sh
```

### Port 5003 Not Accessible

```bash
# Check firewall
sudo ufw status

# Allow port if needed
sudo ufw allow 5003/tcp

# Check if service is binding correctly
sudo netstat -tlnp | grep 5003
```

### Nginx Errors

```bash
# Test configuration
sudo nginx -t

# Check nginx error log
sudo tail -f /var/log/nginx/error.log

# Reload nginx
sudo systemctl reload nginx
```

## Version History

### Current Setup (October 2025)
- **Development**: v1.3.0-dev (DAViewer-dev)
- **Production**: v1.3.0 (DAViewer-prod)
- **Framework**: Flask 3.1.2, Gunicorn 23.0.0
- **Python**: 3.10+

## Contact

For questions about this deployment setup, refer to:
- Main README: `/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer-prod/README.md`
- Claude Code Instructions: `CLAUDE.md`
- MarineSABRES Project: Horizon Europe Grant Agreement No. 101093169
