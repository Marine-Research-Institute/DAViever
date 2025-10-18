# Git Workflow for Two-Version MarineSABRES DA Tool

## Repository Organization Strategy

For the two-version deployment (development on-demand, production systemd), here's the recommended Git organization:

### Recommended Approach: Single Repository with Branches

```
Repository: Marine-Research-Institute/DAViever
├── main (production-ready code)
├── development (active development)
└── feature/* (feature branches)
```

## Why Single Repository with Branches?

**Advantages:**
- ✅ **Single source of truth** - All code in one place
- ✅ **Easy deployment** - Pull from branches to deploy
- ✅ **Clear history** - See all changes in one repository
- ✅ **Simple CI/CD** - One repository to manage
- ✅ **Easier collaboration** - One place for issues, PRs, discussions

**How it works with your setup:**
- `main` branch → deployed to `DAViewer-prod/`
- `development` branch → cloned/pulled to `DAViewer-dev/`

## Branch Strategy

### Main Branch (`main`)
- **Purpose**: Production-ready code
- **Protection**: Protected branch, requires PR approval
- **Deploys to**: `DAViewer-prod/` (systemd service at /DA/)
- **Auto-deploy**: Via systemd service restart after merge
- **Testing**: Fully tested in development before merge

### Development Branch (`development`)
- **Purpose**: Active development and testing
- **Protection**: Can be pushed directly or via PRs
- **Deploys to**: `DAViewer-dev/` (on-demand server at :5003)
- **Testing**: Real-time testing with auto-reload
- **Merges to**: `main` when stable

### Feature Branches (`feature/*`)
- **Purpose**: Individual features or bug fixes
- **Naming**: `feature/add-new-layer`, `fix/health-endpoint`, etc.
- **Created from**: `development`
- **Merged to**: `development` via PR
- **Deleted after**: Merge is complete

## Workflow Diagram

```
feature/new-feature ──PR──> development ──PR──> main
                              │                  │
                              ↓                  ↓
                         DAViewer-dev      DAViewer-prod
                         (port 5003)       (/DA/)
```

## Directory Structure with Git

```
/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/
│
├── DAViewer/              # Original repo (optional, can archive)
│   └── .git/             # Git repository
│
├── DAViewer-dev/          # Development deployment (clone)
│   ├── .git/             # Git working directory (development branch)
│   ├── start_dev.sh
│   └── ...
│
├── DAViewer-prod/         # Production deployment (clone)
│   ├── .git/             # Git working directory (main branch)
│   └── ...
│
└── deployment/
    ├── scripts/
    │   ├── deploy_dev_to_prod.sh
    │   ├── deploy_dev_to_prod_git.sh
    │   ├── setup_two_versions.sh
    │   └── setup_git_workflow.sh
    └── docs/
        ├── GIT_WORKFLOW.md
        ├── DEPLOYMENT_TWO_VERSION.md
        ├── QUICK_START_TWO_VERSIONS.md
        └── nginx-combined.conf
```

## Initial Setup

### 1. Create Development Branch

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer

# Create and push development branch
git checkout -b development
git push -u origin development

# Return to main
git checkout main
```

### 2. Initialize Git in Deployment Directories

```bash
# Development directory - track development branch
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer-dev
git init
git remote add origin git@github.com:Marine-Research-Institute/DAViever.git
git fetch origin
git checkout -b development --track origin/development
git pull

# Production directory - track main branch
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer-prod
git init
git remote add origin git@github.com:Marine-Research-Institute/DAViever.git
git fetch origin
git checkout -b main --track origin/main
git pull
```

### 3. Create Shared .gitignore

```bash
# In the main repository
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer
```

Create/update `.gitignore`:
```
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
env/
*.egg-info/
dist/
build/

# Development
.gunicorn.pid
*.log
logs/
.pytest_cache/
.coverage
htmlcov/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store

# Environment
.env
.env.local

# Deployment specific
DAViewer-prod-backups/
*.backup
.claude/

# Data
data/vector/*.gpkg
data/*.csv
```

## Daily Development Workflow

### 1. Working on Development

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer-dev

# Start dev server
./start_dev.sh

# Make changes
nano app.py

# Commit changes
git add .
git commit -m "feat: Add new feature"

# Push to development branch
git push origin development
```

### 2. Testing Before Production

```bash
# Test at http://laguna.ku.lt:5003
# Verify all features work correctly
```

### 3. Deploy to Production

**Option A: Using deployment script (recommended)**
```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES
./deployment/scripts/deploy_dev_to_prod.sh
```

**Option B: Manual Git workflow**
```bash
# In DAViewer-dev (development branch)
cd DAViewer-dev
git push origin development

# Switch to main repository to create PR
# Or merge directly if you're the only developer:
cd ../DAViewer
git checkout main
git pull
git merge development
git push origin main

# Update production deployment
cd ../DAViewer-prod
git pull origin main
sudo systemctl restart marinesabres-da-prod
```

## Feature Development Workflow

### 1. Create Feature Branch

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer-dev

# Create feature branch from development
git checkout development
git pull
git checkout -b feature/new-wms-layer
```

### 2. Develop Feature

```bash
# Make changes
nano app.py

# Test with auto-reload (dev server running)
# Changes appear immediately at http://laguna.ku.lt:5003

# Commit incrementally
git add .
git commit -m "feat: Add EMODnet bathymetry layer"
```

### 3. Merge to Development

```bash
# Push feature branch
git push origin feature/new-wms-layer

# Merge to development (if working solo)
git checkout development
git merge feature/new-wms-layer
git push origin development

# Delete feature branch
git branch -d feature/new-wms-layer
git push origin --delete feature/new-wms-layer
```

### 4. Deploy to Production

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES
./deployment/scripts/deploy_dev_to_prod.sh
```

## Modified Deployment Script (Git-Aware)

The `deploy_dev_to_prod.sh` should be updated to:

```bash
# 1. Check if development has uncommitted changes
# 2. Ensure development is pushed to remote
# 3. Merge development → main on GitHub (or locally)
# 4. Pull main into DAViewer-prod
# 5. Restart production service
```

## Branch Protection Rules (GitHub)

Configure on GitHub repository:

### Main Branch
- ✅ Require pull request reviews before merging
- ✅ Require status checks to pass
- ✅ Require branches to be up to date
- ✅ Include administrators (optional)

### Development Branch
- ⚠️ Optional: Require PR for features
- ✅ Allow direct pushes (for solo development)

## Git Commands Cheat Sheet

### Daily Commands

```bash
# Development work
cd DAViewer-dev
git status                    # Check status
git add .                     # Stage changes
git commit -m "message"       # Commit
git push origin development   # Push to remote

# Update from remote
git pull origin development   # Pull latest changes

# Production update
cd DAViewer-prod
git pull origin main          # Pull production code
sudo systemctl restart marinesabres-da-prod
```

### Branch Management

```bash
# List branches
git branch -a

# Create branch
git checkout -b feature/name

# Switch branches
git checkout development
git checkout main

# Delete branch
git branch -d feature/name
git push origin --delete feature/name
```

### Synchronization

```bash
# Update all branches
git fetch --all

# See differences
git diff development..main

# Merge branches
git checkout main
git merge development
```

## Rollback Strategies

### Rollback Production (Git)

```bash
cd DAViewer-prod

# Option 1: Revert to previous commit
git log --oneline -5          # Find commit hash
git reset --hard <commit-hash>
sudo systemctl restart marinesabres-da-prod

# Option 2: Use deployment script backup
cd ..
./deployment/scripts/deploy_dev_to_prod.sh --rollback
```

### Rollback Development

```bash
cd DAViewer-dev

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Undo last commit (discard changes)
git reset --hard HEAD~1

# Revert specific file
git checkout -- filename
```

## Alternative: Separate Repositories (Not Recommended)

If you prefer completely separate repositories:

```
Repository 1: DAViewer-Development
Repository 2: DAViewer-Production
```

**Disadvantages:**
- ❌ Code duplication
- ❌ Harder to track changes
- ❌ More complex deployment
- ❌ Diverging codebases over time

**Only use if:** You need completely independent evolution of dev and prod.

## Recommended Git Workflow Summary

1. **Setup** (once):
   - Create `development` branch
   - Initialize git in DAViewer-dev/ and DAViewer-prod/
   - Configure .gitignore

2. **Daily Development**:
   - Work in `DAViewer-dev/` on `development` branch
   - Commit and push changes
   - Test at :5003

3. **Deploy to Production**:
   - Run `./deployment/scripts/deploy_dev_to_prod.sh`
   - Or manually merge development → main
   - Pull in DAViewer-prod/ and restart service

4. **Feature Development**:
   - Create feature branches from `development`
   - Merge back to `development` when complete
   - Deploy to production when stable

## Migration Steps

To implement this workflow:

```bash
# 1. Create development branch in main repo
cd DAViewer
git checkout -b development
git push -u origin development

# 2. Initialize git in deployment directories
# (See "Initial Setup" section above)

# 3. Update .gitignore
# (See .gitignore section above)

# 4. Push all changes
git add .
git commit -m "chore: Set up two-version git workflow"
git push origin development
git push origin main

# 5. Update deployment script to be git-aware
# (Use updated deploy_dev_to_prod.sh)
```

## Best Practices

1. **Always commit before deploying** - Ensure code is in git
2. **Use descriptive commit messages** - Follow conventional commits
3. **Test in development first** - Never push untested code to main
4. **Keep branches in sync** - Regularly merge development → main
5. **Use .gitignore properly** - Don't commit logs, venv, or backups
6. **Document major changes** - Update CHANGELOG.md

## Troubleshooting

### Merge Conflicts

```bash
# During merge
git status                    # See conflicting files
nano <conflicting-file>       # Resolve conflicts
git add <conflicting-file>    # Mark as resolved
git commit                    # Complete merge
```

### Diverged Branches

```bash
# If DAViewer-dev has diverged from remote
cd DAViewer-dev
git fetch origin
git rebase origin/development
# Or
git pull --rebase origin development
```

---

**Implementation**: Use the single repository with `main` and `development` branches approach for best results with your two-version deployment setup.
