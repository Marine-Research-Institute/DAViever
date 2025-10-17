# Deployment Scripts

This directory contains operational scripts for deploying, monitoring, and maintaining the MarineSABRES Demonstration Area Tool.

## Scripts Overview

| Script | Purpose | Usage |
|--------|---------|-------|
| `pre_deploy_check.sh` | Pre-deployment validation | Run before deploying to check readiness |
| `health_check.sh` | Service health monitoring | Manual or automated health checks |
| `backup_deployment.sh` | Create deployment backups | Backup before updates |
| `rollback.sh` | Restore previous deployment | Rollback to a previous backup |
| `verify_deployment.sh` | Post-deployment testing | Verify deployment succeeded |

---

## Pre-Deployment Check

**Script:** `pre_deploy_check.sh`

Validates the application is ready for deployment by checking:
- Required files exist
- Python version and dependencies
- Virtual environment setup
- System dependencies (nginx, systemd)
- File permissions
- Git status
- Configuration file syntax
- Static assets
- EMODnet WMS connectivity

### Usage

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer
./scripts/pre_deploy_check.sh
```

### Example Output

```
============================================================================
Pre-Deployment Check Summary
============================================================================

Total Checks:   12
Passed:         11
Warnings:       1
Failed:         0

✓ All pre-deployment checks passed!
✓ Ready to deploy

To deploy, run:
  cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer
  ./deploy_to_da.sh
```

### Exit Codes

- `0` - All checks passed
- `1` - Checks passed with warnings
- `2` - One or more checks failed

---

## Health Check

**Script:** `health_check.sh`

Performs comprehensive health monitoring of the deployed application.

### What It Checks

- Service status (running, enabled)
- Worker process count
- HTTP endpoints (/, /health, /api/*)
- Static file accessibility
- Response times
- Memory usage
- Disk space
- Log files for errors
- EMODnet WMS connectivity

### Usage

**Manual health check:**
```bash
./scripts/health_check.sh
```

**Automated monitoring (cron):**
```bash
# Add to crontab (every 5 minutes)
crontab -e

# Add this line:
*/5 * * * * /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer/scripts/health_check.sh >> /var/log/marinesabres-health.log 2>&1
```

### Configuration

Environment variables:
```bash
APP_URL=http://laguna.ku.lt/DA        # Application URL
SERVICE_NAME=marinesabres-da           # Systemd service name
LOG_FILE=/tmp/marinesabres-da-health.log  # Health check log
ALERT_EMAIL=admin@example.com          # Email for alerts (optional)
```

### Example Output

```
============================================================================
Health Check Summary
============================================================================
Passed:  11
Warnings: 1
Failed:   0

✓ All health checks PASSED
```

### Exit Codes

- `0` - All checks passed
- `1` - Checks passed with warnings
- `2` - One or more critical checks failed

---

## Backup Deployment

**Script:** `backup_deployment.sh`

Creates a comprehensive backup of the current deployment including application code, configuration files, logs, and service status.

### What It Backs Up

- Application files (app.py, gunicorn.conf.py, etc.)
- Source code (src/, config/, static/, templates/)
- Configuration files (systemd service, nginx config)
- Recent logs (last 50k lines)
- Service status and environment
- Git information
- Python package list

### Usage

**Create automatic backup:**
```bash
./scripts/backup_deployment.sh
```

**Create named backup:**
```bash
./scripts/backup_deployment.sh my-backup-name
```

### Backup Location

Backups are stored in: `/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer/backups/`

Format: `marinesabres-da-YYYYMMDD_HHMMSS.tar.gz`

### Example Output

```
============================================================================
Backup Complete
============================================================================
✓ Backup created successfully: marinesabres-da-20251017_143022.tar.gz

To restore this backup:
  ./scripts/rollback.sh marinesabres-da-20251017_143022

To list all backups:
  ls -lth /home/razinka/.../backups/
```

### Automatic Cleanup

The script automatically keeps only the 10 most recent backups and removes older ones.

---

## Rollback

**Script:** `rollback.sh`

Restores the application to a previous backup. Creates a safety backup before rolling back.

### Usage

**Interactive rollback (lists available backups):**
```bash
./scripts/rollback.sh
```

**Direct rollback to specific backup:**
```bash
./scripts/rollback.sh marinesabres-da-20251017_143022
```

### Process

1. Lists available backups (if no argument provided)
2. Confirms rollback action
3. Creates safety backup of current state
4. Stops service
5. Extracts and restores backup files
6. Restores configuration files
7. Optionally restores logs
8. Restarts service
9. Reloads nginx
10. Verifies rollback success

### Example Output

```
============================================================================
Available Backups
============================================================================

Available backups (most recent first):

  1) marinesabres-da-20251017_143022
     Size: 15M | Date: 2025-10-17 14:30:22

  2) marinesabres-da-20251017_120000
     Size: 14M | Date: 2025-10-17 12:00:00

Enter backup number to restore (or 'q' to quit): 1

============================================================================
Rollback Complete
============================================================================
✓ Successfully rolled back to: marinesabres-da-20251017_143022
```

### Safety Features

- Creates safety backup before rollback (named `pre-rollback-<timestamp>`)
- Confirmation prompt before proceeding
- Backup manifest display
- Optional log restoration
- Automatic verification after rollback

---

## Verify Deployment

**Script:** `verify_deployment.sh`

Comprehensive post-deployment testing to ensure everything is working correctly.

### Test Categories

**Service Tests:**
- Service running and enabled
- Worker process count
- Environment variables

**HTTP Tests:**
- Main page (/)
- Health endpoint (/health)
- API endpoints (/api/layers, /api/all-layers)
- Static files (JavaScript, CSS)
- Logo files

**Performance Tests:**
- Response time
- Concurrent request handling

**Configuration Tests:**
- Nginx configuration validity
- Subpath URL rewriting
- Security settings

**Integration Tests:**
- EMODnet WMS connectivity
- Log file accessibility

### Usage

```bash
./scripts/verify_deployment.sh
```

**Verbose mode:**
```bash
./scripts/verify_deployment.sh --verbose
```

### Example Output

```
============================================================================
Verification Summary
============================================================================

Total Tests:    17
Passed:         16
Warnings:       1
Failed:         0
Pass Rate:      94%

✓ All verification tests passed successfully!

Deployment URL:  http://laguna.ku.lt/DA/
Health Check:    http://laguna.ku.lt/DA/health
Service Status:  sudo systemctl status marinesabres-da
```

### Exit Codes

- `0` - All tests passed
- `1` - Tests passed with warnings
- `2` - One or more tests failed

---

## Workflow Examples

### Initial Deployment

```bash
# 1. Run pre-deployment check
./scripts/pre_deploy_check.sh

# 2. If checks pass, deploy
./deploy_to_da.sh

# 3. Verify deployment
./scripts/verify_deployment.sh

# 4. Run health check
./scripts/health_check.sh
```

### Update Deployment

```bash
# 1. Create backup before update
./scripts/backup_deployment.sh before-update

# 2. Pull latest changes
git pull origin main

# 3. Run pre-deployment check
./scripts/pre_deploy_check.sh

# 4. Deploy
./deploy_to_da.sh

# 5. Verify
./scripts/verify_deployment.sh
```

### Rollback Deployment

```bash
# 1. List available backups and rollback
./scripts/rollback.sh

# 2. Verify rollback
./scripts/verify_deployment.sh

# 3. Check health
./scripts/health_check.sh
```

### Continuous Monitoring

```bash
# Setup automated health checks
crontab -e

# Add:
# Every 5 minutes - health check
*/5 * * * * /path/to/scripts/health_check.sh >> /var/log/marinesabres-health.log 2>&1

# Every day at 2 AM - backup
0 2 * * * /path/to/scripts/backup_deployment.sh
```

---

## Troubleshooting

### Script Permission Denied

```bash
chmod +x scripts/*.sh
```

### Script Not Found

Ensure you're in the application directory:
```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer
```

### Health Check False Positives

Adjust timeout values in the script:
```bash
# Edit health_check.sh
MAX_RESPONSE_TIME=10  # Increase for slow connections
MIN_WORKER_COUNT=1    # Decrease for development
```

### Backup Space Issues

Old backups are auto-deleted. To manually clean:
```bash
# Keep only last 5 backups
cd backups/
ls -1t *.tar.gz | tail -n +6 | xargs rm -f
```

---

## Script Development

### Adding New Scripts

1. Create script in `scripts/` directory
2. Add shebang: `#!/bin/bash`
3. Make executable: `chmod +x scripts/your-script.sh`
4. Follow existing script structure:
   - Color-coded output
   - Clear section headers
   - Exit code conventions
   - Error handling with `set -e`
5. Update this README

### Best Practices

- Use color-coded output for clarity
- Provide informative error messages
- Return appropriate exit codes
- Include usage documentation
- Add error handling
- Test thoroughly before deployment

---

## Related Documentation

- **DEPLOYMENT.md** - Complete deployment guide
- **CLAUDE.md** - Development documentation
- **README.md** - Project overview
- **../deploy_to_da.sh** - Main deployment script

---

**Last Updated:** October 17, 2025
**Maintainer:** razinka@ku.lt
