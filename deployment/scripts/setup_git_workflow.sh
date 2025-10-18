#!/bin/bash
# ============================================================================
# MarineSABRES DA Tool - Git Workflow Setup
# Sets up branch-based workflow for two-version deployment
# ============================================================================

set -e
set -u

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
BASE_DIR="/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES"
MAIN_REPO="$BASE_DIR/DAViewer"
DEV_DIR="$BASE_DIR/DAViewer-dev"
PROD_DIR="$BASE_DIR/DAViewer-prod"
REMOTE_NAME="origin"
REMOTE_URL="git@github.com:Marine-Research-Institute/DAViever.git"

print_header() {
    echo ""
    echo "============================================================================"
    echo -e "${MAGENTA}$1${NC}"
    echo "============================================================================"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Main setup
print_header "MarineSABRES DA Tool - Git Workflow Setup"
print_info "Setting up branch-based workflow for two-version deployment"

# 1. Update .gitignore in main repository
print_header "Updating .gitignore"

cd "$MAIN_REPO"

# Add development-specific ignores if not present
if ! grep -q ".gunicorn.pid" .gitignore 2>/dev/null; then
    print_info "Adding development-specific entries to .gitignore..."
    cat >> .gitignore <<'EOF'

# Development server
.gunicorn.pid
logs/dev-console.log

# Deployment backups
DAViewer-prod-backups/

# Claude Code
.claude/
EOF
    print_success ".gitignore updated"
else
    print_info ".gitignore already configured"
fi

# 2. Create development branch in main repository
print_header "Creating Development Branch"

cd "$MAIN_REPO"

# Check if development branch exists locally
if git show-ref --verify --quiet refs/heads/development; then
    print_info "Development branch already exists locally"
else
    print_info "Creating development branch from main..."
    git checkout -b development
    print_success "Development branch created"
fi

# Check if development branch exists on remote
if git ls-remote --heads "$REMOTE_NAME" development | grep -q development; then
    print_info "Development branch already exists on remote"
else
    print_info "Pushing development branch to remote..."
    git push -u "$REMOTE_NAME" development
    print_success "Development branch pushed to remote"
fi

# Return to main branch
git checkout main

# 3. Initialize git in DAViewer-dev (development branch)
print_header "Setting Up Git in DAViewer-dev"

cd "$DEV_DIR"

if [ -d ".git" ]; then
    print_warning "Git already initialized in DAViewer-dev"
    print_info "Current branch: $(git branch --show-current)"
else
    print_info "Initializing git repository..."
    git init

    print_info "Adding remote origin..."
    git remote add origin "$REMOTE_URL"

    print_info "Fetching from remote..."
    git fetch origin

    print_info "Checking out development branch..."
    git checkout -b development --track origin/development

    print_success "Git initialized in DAViewer-dev (development branch)"
fi

# Ensure on development branch
current_branch=$(git branch --show-current)
if [ "$current_branch" != "development" ]; then
    print_warning "DAViewer-dev is on branch '$current_branch', switching to development..."
    git checkout development
fi

print_success "DAViewer-dev is on development branch"

# 4. Initialize git in DAViewer-prod (main branch)
print_header "Setting Up Git in DAViewer-prod"

cd "$PROD_DIR"

if [ -d ".git" ]; then
    print_warning "Git already initialized in DAViewer-prod"
    print_info "Current branch: $(git branch --show-current)"
else
    print_info "Initializing git repository..."
    git init

    print_info "Adding remote origin..."
    git remote add origin "$REMOTE_URL"

    print_info "Fetching from remote..."
    git fetch origin

    print_info "Checking out main branch..."
    git checkout -b main --track origin/main

    print_success "Git initialized in DAViewer-prod (main branch)"
fi

# Ensure on main branch
current_branch=$(git branch --show-current)
if [ "$current_branch" != "main" ]; then
    print_warning "DAViewer-prod is on branch '$current_branch', switching to main..."
    git checkout main
fi

print_success "DAViewer-prod is on main branch"

# 5. Show current status
print_header "Git Configuration Summary"

echo -e "\n${BLUE}Main Repository (DAViewer/):${NC}"
cd "$MAIN_REPO"
echo "  • Remote: $(git remote get-url origin)"
echo "  • Current branch: $(git branch --show-current)"
echo "  • Branches:"
git branch -a | sed 's/^/    /'

echo -e "\n${BLUE}Development Deployment (DAViewer-dev/):${NC}"
cd "$DEV_DIR"
echo "  • Remote: $(git remote get-url origin 2>/dev/null || echo 'Not configured')"
echo "  • Current branch: $(git branch --show-current 2>/dev/null || echo 'Not initialized')"
echo "  • Tracking: origin/development"

echo -e "\n${BLUE}Production Deployment (DAViewer-prod/):${NC}"
cd "$PROD_DIR"
echo "  • Remote: $(git remote get-url origin 2>/dev/null || echo 'Not configured')"
echo "  • Current branch: $(git branch --show-current 2>/dev/null || echo 'Not initialized')"
echo "  • Tracking: origin/main"

# 6. Show workflow instructions
print_header "Git Workflow Ready"

echo -e "\n${GREEN}✓ Git workflow configured successfully!${NC}\n"

echo -e "${BLUE}Branch Structure:${NC}"
echo "  • main        → DAViewer-prod/ → http://laguna.ku.lt/DA/"
echo "  • development → DAViewer-dev/  → http://laguna.ku.lt:5003"

echo -e "\n${BLUE}Daily Development Workflow:${NC}"
echo "  1. Work in DAViewer-dev/ (development branch)"
echo "     cd $DEV_DIR"
echo "     ./start_dev.sh"
echo "     # Make changes, they auto-reload"
echo ""
echo "  2. Commit changes"
echo "     git add ."
echo "     git commit -m \"feat: Add new feature\""
echo "     git push origin development"
echo ""
echo "  3. Deploy to production"
echo "     $MAIN_REPO/deployment/scripts/deploy_dev_to_prod_git.sh"

echo -e "\n${BLUE}Useful Git Commands:${NC}"
echo "  • Check status:     git status"
echo "  • View branches:    git branch -a"
echo "  • Switch branches:  git checkout <branch>"
echo "  • Pull updates:     git pull"
echo "  • View changes:     git diff"

echo -e "\n${BLUE}Documentation:${NC}"
echo "  • Full workflow guide: $MAIN_REPO/deployment/docs/GIT_WORKFLOW.md"
echo "  • Quick start:         $MAIN_REPO/deployment/docs/QUICK_START_TWO_VERSIONS.md"

echo -e "\n${BLUE}Next Steps:${NC}"
echo "  1. Read $MAIN_REPO/deployment/docs/GIT_WORKFLOW.md for complete documentation"
echo "  2. Start developing in $DEV_DIR/"
echo "  3. Commit and push changes to development branch"
echo "  4. Deploy to production when ready"

print_success "Git workflow setup completed!"
