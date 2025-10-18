# MarineSABRES DA Tool - Deployment Directory

This directory contains all deployment scripts, documentation, and backups for the two-version MarineSABRES DA Tool setup.

## Directory Structure

```
deployment/
├── README.md                    # This file
├── scripts/                     # Deployment automation scripts
│   ├── setup_two_versions.sh   # Initial two-version setup
│   ├── setup_git_workflow.sh   # Git workflow setup
│   ├── deploy_dev_to_prod.sh   # Deploy dev→prod (rsync)
│   └── deploy_dev_to_prod_git.sh # Deploy dev→prod (git-aware)
├── docs/                        # Documentation
│   ├── QUICK_START_TWO_VERSIONS.md # Quick reference
│   ├── DEPLOYMENT_TWO_VERSION.md   # Complete deployment guide
│   ├── GIT_WORKFLOW.md         # Git workflow documentation
│   └── nginx-combined.conf     # Nginx configuration template
└── backups/                     # Production backups (auto-created)
    └── backup_YYYYMMDD_HHMMSS/  # Timestamped backups
```

## Quick Links

### For First-Time Setup

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer

# 1. Set up two-version deployment
./deployment/scripts/setup_two_versions.sh

# 2. (Optional) Set up git workflow
./deployment/scripts/setup_git_workflow.sh
```

### For Daily Use

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES

# Start development server
cd DAViewer-dev
./start_dev.sh

# Deploy to production
cd ../DAViewer
./deployment/scripts/deploy_dev_to_prod.sh
# or for git-aware deployment:
./deployment/scripts/deploy_dev_to_prod_git.sh
```

## Documentation

- **Quick Start**: [`docs/QUICK_START_TWO_VERSIONS.md`](docs/QUICK_START_TWO_VERSIONS.md)
- **Full Deployment Guide**: [`docs/DEPLOYMENT_TWO_VERSION.md`](docs/DEPLOYMENT_TWO_VERSION.md)
- **Git Workflow**: [`docs/GIT_WORKFLOW.md`](docs/GIT_WORKFLOW.md)

## Scripts

### Setup Scripts (Run Once)

#### `setup_two_versions.sh`
Sets up the two-version deployment:
- Creates virtual environments for dev and prod
- Installs production systemd service
- Configures nginx
- Starts production service

**Usage:**
```bash
./deployment/scripts/setup_two_versions.sh
```

#### `setup_git_workflow.sh`
Sets up git branch-based workflow:
- Creates development branch
- Initializes git in DAViewer-dev and DAViewer-prod
- Updates .gitignore
- Sets up branch tracking

**Usage:**
```bash
./deployment/scripts/setup_git_workflow.sh
```

### Deployment Scripts (Daily Use)

#### `deploy_dev_to_prod.sh`
Deploy development to production (rsync-based):
- Checks development health
- Shows differences
- Creates backup
- Syncs code via rsync
- Restarts production
- Tests and rolls back on failure

**Usage:**
```bash
./deployment/scripts/deploy_dev_to_prod.sh
```

#### `deploy_dev_to_prod_git.sh`
Deploy development to production (git-aware):
- Checks git status
- Commits uncommitted changes
- Merges development → main
- Pulls main into production
- Creates backup
- Restarts and tests
- Rolls back on failure

**Usage:**
```bash
./deployment/scripts/deploy_dev_to_prod_git.sh

# Rollback if needed
./deployment/scripts/deploy_dev_to_prod_git.sh --rollback
```

## Development Workflow

### Two-Version Setup

```
┌─────────────────────────────────────────┐
│  Development (On-Demand)                │
│  ├─ Location: DAViewer-dev/             │
│  ├─ Port: 5003 (external)               │
│  ├─ Start: ./start_dev.sh               │
│  ├─ Stop: ./stop_dev.sh                 │
│  └─ URL: http://laguna.ku.lt:5003       │
└─────────────────────────────────────────┘
                  ↓ deploy
┌─────────────────────────────────────────┐
│  Production (Systemd Service)           │
│  ├─ Location: DAViewer-prod/            │
│  ├─ Port: 5002 (internal via nginx)     │
│  ├─ Start: Auto (systemd)               │
│  ├─ Service: marinesabres-da-prod       │
│  └─ URL: http://laguna.ku.lt/DA/        │
└─────────────────────────────────────────┘
```

### Daily Workflow

1. **Develop** in `DAViewer-dev/`
   ```bash
   cd ../DAViewer-dev
   ./start_dev.sh
   # Make changes (auto-reload)
   ```

2. **Test** at http://laguna.ku.lt:5003

3. **Deploy** to production
   ```bash
   cd ../DAViewer
   ./deployment/scripts/deploy_dev_to_prod.sh
   ```

4. **Stop** development when done
   ```bash
   cd ../DAViewer-dev
   ./stop_dev.sh
   ```

## Git Workflow (Optional)

If using git branch-based workflow:

```
development branch → DAViewer-dev/ → :5003
     ↓ merge
main branch → DAViewer-prod/ → /DA/
```

**Workflow:**
```bash
# In DAViewer-dev
git add .
git commit -m "feat: Add feature"
git push origin development

# Deploy
cd ../DAViewer
./deployment/scripts/deploy_dev_to_prod_git.sh
```

## Backups

Automatic backups are created in `deployment/backups/` before each deployment:

```
backups/
├── backup_20251018_120000/
├── backup_20251018_140000/
└── ...  (keeps last 5)
```

**Restore from backup:**
```bash
# Automatic rollback
./deployment/scripts/deploy_dev_to_prod.sh --rollback

# Or manual
cd ../DAViewer-prod
sudo systemctl stop marinesabres-da-prod
rsync -av deployment/backups/backup_TIMESTAMP/ .
sudo systemctl start marinesabres-da-prod
```

## Nginx Configuration

Production deployment requires nginx reverse proxy configuration.

**Template:** [`docs/nginx-combined.conf`](docs/nginx-combined.conf)

**Install:**
```bash
sudo cp deployment/docs/nginx-combined.conf /etc/nginx/sites-available/default.d-marinesabres.conf

# Add to /etc/nginx/sites-available/default:
# include /etc/nginx/sites-available/default.d-marinesabres.conf;

sudo nginx -t
sudo systemctl reload nginx
```

## Script Permissions

All scripts should be executable. If you encounter permission errors:

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer

# Make all deployment scripts executable
chmod +x deployment/scripts/*.sh

# Verify permissions
ls -l deployment/scripts/*.sh
```

## Troubleshooting

### Scripts Won't Run

```bash
# Check if scripts are executable
ls -l deployment/scripts/*.sh

# Make scripts executable
chmod +x deployment/scripts/*.sh

# Run with explicit bash if needed
bash deployment/scripts/setup_two_versions.sh
```

### Deployment Fails

```bash
# Check logs
tail -f ../DAViewer-dev/logs/dev-console.log
sudo journalctl -u marinesabres-da-prod -n 50

# Rollback
./deployment/scripts/deploy_dev_to_prod.sh --rollback
```

### Production Service Issues

```bash
# Check status
sudo systemctl status marinesabres-da-prod

# Restart
sudo systemctl restart marinesabres-da-prod

# View logs
sudo journalctl -u marinesabres-da-prod -f

# Check nginx
sudo systemctl status nginx
sudo nginx -t
```

### Path Issues

If you see "command not found" or "file not found" errors:

```bash
# Verify you're in the correct directory
pwd
# Should show: /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer

# Use absolute paths if needed
/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer/deployment/scripts/deploy_dev_to_prod.sh
```

## Version Information

- **Development Version**: On-demand, port 5003, auto-reload
- **Production Version**: Systemd service, /DA/ subpath, optimized

For complete version history, see [CHANGELOG.md](../CHANGELOG.md)

## Support

- **Quick Start**: docs/QUICK_START_TWO_VERSIONS.md
- **Full Guide**: docs/DEPLOYMENT_TWO_VERSION.md
- **Git Workflow**: docs/GIT_WORKFLOW.md
- **Main README**: ../README.md

---

**MarineSABRES Project** - Horizon Europe Grant Agreement No. 101093169
