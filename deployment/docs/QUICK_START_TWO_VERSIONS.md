# Quick Start: Two-Version Setup (On-Demand Development)

## Overview

Two separate MarineSABRES DA Tool deployments:
- **Development** (DAViewer-dev): On-demand server for active development
- **Production** (DAViewer-prod): Systemd service, auto-starts on boot

## Complete Setup (Run Once)

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer
./deployment/scripts/setup_two_versions.sh
```

This will set up both environments automatically.

## Daily Usage

### Development Server (On-Demand)

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer-dev

# Start server
./start_dev.sh

# Check status
./status_dev.sh

# Stop server
./stop_dev.sh

# View logs
tail -f logs/dev-console.log
```

**Access**: http://laguna.ku.lt:5003

### Production Service (Always Running)

```bash
# View status
sudo systemctl status marinesabres-da-prod

# View logs
sudo journalctl -u marinesabres-da-prod -f

# Restart (if needed)
sudo systemctl restart marinesabres-da-prod
```

**Access**: http://laguna.ku.lt/DA/

## Development Workflow

### 1. Start Development Server

```bash
cd DAViewer-dev
./start_dev.sh
```

Output:
```
✓ Development server started successfully!

Access URLs:
  • Main interface: http://laguna.ku.lt:5003
  • Health check:   http://laguna.ku.lt:5003/health

Changes to code will automatically reload!
```

### 2. Make Changes

Edit files in `DAViewer-dev/`:
```bash
nano app.py
nano templates/index.html
nano static/js/layer-manager.js
```

**Auto-reload enabled** - Changes take effect immediately!

### 3. Test

Open browser to http://laguna.ku.lt:5003 and test your changes.

### 4. Deploy to Production

When ready:
```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer
./deployment/scripts/deploy_dev_to_prod.sh
```

The script will:
- ✅ Check development health
- ✅ Show differences
- ✅ Ask for confirmation
- ✅ Create backup
- ✅ Sync code
- ✅ Restart production
- ✅ Test production
- ✅ Rollback if fails

### 5. Stop Development Server (When Done)

```bash
cd DAViewer-dev
./stop_dev.sh
```

## Key Commands Cheat Sheet

### Development

| Task | Command |
|------|---------|
| Start | `cd DAViewer-dev && ./start_dev.sh` |
| Stop | `cd DAViewer-dev && ./stop_dev.sh` |
| Status | `cd DAViewer-dev && ./status_dev.sh` |
| Logs | `tail -f DAViewer-dev/logs/dev-console.log` |
| Access | http://laguna.ku.lt:5003 |

### Production

| Task | Command |
|------|---------|
| Status | `sudo systemctl status marinesabres-da-prod` |
| Restart | `sudo systemctl restart marinesabres-da-prod` |
| Logs | `sudo journalctl -u marinesabres-da-prod -f` |
| Access | http://laguna.ku.lt/DA/ |

### Deployment

| Task | Command |
|------|---------|
| Deploy | `cd DAViewer && ./deployment/scripts/deploy_dev_to_prod.sh` |
| Rollback | `cd DAViewer && ./deployment/scripts/deploy_dev_to_prod.sh --rollback` |

## Configuration Differences

### Development (On-Demand)
- **Port**: 5003 (direct external access)
- **Workers**: 1 (easier debugging)
- **Auto-reload**: ✅ YES (code changes reload instantly)
- **Timeout**: 60s
- **Logging**: DEBUG level
- **Start**: Manual (`./start_dev.sh`)
- **Stop**: Manual (`./stop_dev.sh`)

### Production (Systemd)
- **Port**: 5002 (internal, nginx proxies to /DA/)
- **Workers**: Auto-scaled (CPU cores × 2 + 1)
- **Auto-reload**: ❌ NO (stability)
- **Timeout**: 120s (for WMS operations)
- **Logging**: INFO level
- **Start**: Automatic on boot
- **Stop**: `sudo systemctl stop marinesabres-da-prod`

## Troubleshooting

### Development Server Won't Start

```bash
cd DAViewer-dev

# Check if already running
./status_dev.sh

# Check logs
tail -f logs/dev-console.log

# Check if port is in use
sudo lsof -i :5003

# Kill stale process if needed
rm -f .gunicorn.pid
./start_dev.sh
```

### Production Service Issues

```bash
# Check service status
sudo systemctl status marinesabres-da-prod

# View recent logs
sudo journalctl -u marinesabres-da-prod -n 50

# Restart service
sudo systemctl restart marinesabres-da-prod
```

### Deployment Fails

```bash
# Rollback to previous version
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer
./deployment/scripts/deploy_dev_to_prod.sh --rollback

# Check what backups are available
ls -lt /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer-prod-backups/
```

## Files Created

```
Marine-SABRES/
├── DAViewer/                  # Main repository
│   └── deployment/
│       ├── scripts/
│       │   ├── deploy_dev_to_prod.sh     # Deployment script
│       │   ├── deploy_dev_to_prod_git.sh # Git-aware deployment
│       │   ├── setup_two_versions.sh     # Initial setup
│       │   └── setup_git_workflow.sh     # Git workflow setup
│       └── docs/
│           ├── nginx-combined.conf       # Nginx configuration
│           └── ...
│
├── DAViewer-dev/              # Development version
│   ├── start_dev.sh          # Start development server
│   ├── stop_dev.sh           # Stop development server
│   ├── status_dev.sh         # Check server status
│   ├── .gunicorn.pid         # Process ID (when running)
│   └── logs/dev-console.log  # Development logs
│
├── DAViewer-prod/             # Production version
│   ├── marinesabres-da-prod.service
│   └── logs/                  # Production logs
│
└── DAViewer-prod-backups/     # Automatic backups
```

## Next Steps After Setup

1. **Start development server**:
   ```bash
   cd DAViewer-dev
   ./start_dev.sh
   ```

2. **Test both versions**:
   - Development: http://laguna.ku.lt:5003
   - Production: http://laguna.ku.lt/DA/

3. **Make a test change** in DAViewer-dev and see it auto-reload

4. **Deploy your first change**:
   ```bash
   cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer
   ./deployment/scripts/deploy_dev_to_prod.sh
   ```

## Full Documentation

For complete details: `deployment/docs/DEPLOYMENT_TWO_VERSION.md`

---

**MarineSABRES Project** - Horizon Europe Grant No. 101093169
