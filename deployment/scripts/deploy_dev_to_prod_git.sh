#!/bin/bash
# ============================================================================
# MarineSABRES DA Tool - Git-Aware Deployment Script
# Deploys development branch to production with git integration
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
PROD_DIR="$BASE_DIR/DAViewer"  # NOTE: Currently production runs from DAViewer, not DAViewer-prod
BACKUP_DIR="$BASE_DIR/DAViewer-backups"
PROD_SERVICE="marinesabres-da"  # NOTE: Actual service is marinesabres-da, not marinesabres-da-prod

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() {
    echo ""
    echo "============================================================================"
    echo -e "${MAGENTA}$1${NC}"
    echo "============================================================================"
}

check_permissions() {
    print_header "Checking Permissions"
    if [ "$EUID" -eq 0 ]; then
        print_error "This script should NOT be run as root"
        exit 1
    fi
    print_success "Running as user: $(whoami)"
}

check_git_status() {
    print_header "Checking Git Status"

    # Check development directory
    cd "$DEV_DIR"

    # Check if we're on development branch
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "none")
    if [ "$CURRENT_BRANCH" != "development" ]; then
        print_warning "DAViewer-dev is on branch '$CURRENT_BRANCH' instead of 'development'"
        read -p "$(echo -e ${YELLOW}Continue anyway? [y/N]:${NC} )" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    else
        print_success "On development branch"
    fi

    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        print_warning "You have uncommitted changes in development:"
        git status --short | head -10
        echo ""
        read -p "$(echo -e ${YELLOW}Commit changes before deploying? [Y/n]:${NC} )" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            read -p "Commit message: " COMMIT_MSG
            git add .
            git commit -m "$COMMIT_MSG"
            print_success "Changes committed"
        fi
    else
        print_success "No uncommitted changes"
    fi

    # Check if development is ahead of remote
    git fetch origin development --quiet
    LOCAL=$(git rev-parse development)
    REMOTE=$(git rev-parse origin/development)

    if [ "$LOCAL" != "$REMOTE" ]; then
        print_warning "Local development is not in sync with remote"
        print_info "Pushing to remote..."
        git push origin development
        print_success "Pushed to remote"
    else
        print_success "In sync with remote"
    fi
}

check_development() {
    print_header "Verifying Development Version"

    cd "$DEV_DIR"
    print_success "Development directory found"

    # Check if development server is running
    DEV_PID_FILE="$DEV_DIR/.gunicorn.pid"
    DEV_RUNNING=false

    if [ -f "$DEV_PID_FILE" ]; then
        DEV_PID=$(cat "$DEV_PID_FILE")
        if ps -p "$DEV_PID" > /dev/null 2>&1; then
            print_success "Development server is running (PID: $DEV_PID)"
            DEV_RUNNING=true
        fi
    fi

    if [ "$DEV_RUNNING" = false ]; then
        print_warning "Development server is not running"
        print_info "Starting development server for testing..."
        ./start_dev.sh || {
            print_error "Failed to start development server"
            exit 1
        }
        sleep 3
    fi

    # Test health endpoint
    print_info "Testing development health endpoint..."
    if curl -s -f http://localhost:5003/health > /dev/null; then
        print_success "Development version is healthy"
    else
        print_error "Development version health check failed"
        exit 1
    fi
}

show_git_changes() {
    print_header "Git Changes"

    cd "$DEV_DIR"
    DEV_COMMIT=$(git rev-parse --short HEAD)

    cd "$PROD_DIR"
    PROD_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "none")

    echo -e "${BLUE}Development (DAViewer-dev):${NC}"
    echo "  • Branch: development"
    echo "  • Commit: $DEV_COMMIT"
    cd "$DEV_DIR"
    git log -1 --pretty=format:"  • Message: %s%n  • Author: %an <%ae>%n  • Date: %ar%n"

    echo ""
    echo -e "${BLUE}Production (DAViewer-prod):${NC}"
    echo "  • Branch: main"
    echo "  • Commit: $PROD_COMMIT"

    if [ "$PROD_COMMIT" != "none" ]; then
        cd "$PROD_DIR"
        git log -1 --pretty=format:"  • Message: %s%n  • Author: %an <%ae>%n  • Date: %ar%n"
    fi

    echo ""
    echo -e "${BLUE}Commits to be deployed:${NC}"
    cd "$DEV_DIR"
    if [ "$PROD_COMMIT" != "none" ]; then
        git log --oneline origin/main..HEAD | head -10 | sed 's/^/  /'
    else
        echo "  (All commits - first deployment)"
    fi

    echo ""
    read -p "$(echo -e ${YELLOW}Continue with deployment? [y/N]:${NC} )" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled by user"
        exit 0
    fi
}

merge_to_main() {
    print_header "Merging Development to Main"

    cd "$MAIN_REPO"

    # Ensure we're on main branch
    git checkout main
    git pull origin main

    print_info "Merging development into main..."

    # Try to merge
    if git merge development --no-edit; then
        print_success "Merge successful"

        print_info "Pushing main to remote..."
        git push origin main
        print_success "Main branch updated on remote"
    else
        print_error "Merge conflict detected!"
        print_info "Please resolve conflicts manually:"
        print_info "  1. cd $MAIN_REPO"
        print_info "  2. Resolve conflicts in marked files"
        print_info "  3. git add <resolved-files>"
        print_info "  4. git commit"
        print_info "  5. git push origin main"
        print_info "  6. Re-run this deployment script"
        exit 1
    fi
}

backup_production() {
    print_header "Backing Up Current Production"

    mkdir -p "$BACKUP_DIR"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_PATH="$BACKUP_DIR/backup_$TIMESTAMP"

    print_info "Creating backup at: $BACKUP_PATH"

    # Backup excluding .git directory
    rsync -a --exclude=.git --exclude=venv --exclude=logs "$PROD_DIR/" "$BACKUP_PATH/"

    print_success "Backup created successfully"

    # Keep only last 5 backups
    print_info "Cleaning up old backups (keeping last 5)..."
    cd "$BACKUP_DIR"
    ls -t | tail -n +6 | xargs -r rm -rf
    BACKUP_COUNT=$(ls | wc -l)
    print_success "Backup cleanup complete ($BACKUP_COUNT backups retained)"
}

stop_production() {
    print_header "Stopping Production Service"

    if sudo systemctl is-active --quiet "$PROD_SERVICE"; then
        print_info "Stopping $PROD_SERVICE..."
        sudo systemctl stop "$PROD_SERVICE"
        sleep 2
        print_success "Production service stopped"
    else
        print_info "Production service is not running"
    fi
}

update_production_code() {
    print_header "Updating Production Code via Git"

    cd "$PROD_DIR"

    print_info "Pulling latest main branch..."
    git fetch origin main
    git reset --hard origin/main

    print_success "Production code updated from main branch"

    # Show what changed
    print_info "Latest commit in production:"
    git log -1 --pretty=format:"  • %h - %s (%ar)%n"
}

update_dependencies() {
    print_header "Updating Production Dependencies"

    print_info "Checking if requirements have changed..."

    cd "$PROD_DIR"

    # Check if requirements.txt changed in latest commits
    if git diff HEAD~1 HEAD -- requirements.txt | grep -q "^[+-]"; then
        print_warning "Requirements have changed!"
        print_info "Updating production dependencies..."

        source venv/bin/activate
        pip install -r requirements.txt --upgrade
        deactivate

        print_success "Dependencies updated"
    else
        print_info "No dependency changes detected"
    fi
}

install_service() {
    print_header "Installing Production Service"

    cd "$PROD_DIR"
    sudo cp marinesabres-da-prod.service /etc/systemd/system/
    sudo systemctl daemon-reload
    print_success "Systemd service installed"

    sudo systemctl enable "$PROD_SERVICE"
    print_success "Service enabled for auto-start"
}

start_production() {
    print_header "Starting Production Service"

    print_info "Starting $PROD_SERVICE..."
    sudo systemctl start "$PROD_SERVICE"

    sleep 5

    if sudo systemctl is-active --quiet "$PROD_SERVICE"; then
        print_success "Production service started successfully"
    else
        print_error "Production service failed to start"
        print_info "Check logs with: sudo journalctl -u $PROD_SERVICE -n 50"
        exit 1
    fi
}

test_production() {
    print_header "Testing Production Deployment"

    print_info "Waiting for application to initialize..."
    sleep 3

    # Test health endpoint
    print_info "Testing production health endpoint..."
    if curl -s -f http://laguna.ku.lt/DA/health > /dev/null; then
        print_success "Production health check passed"
    else
        print_error "Production health check failed!"
        print_warning "Rolling back..."
        rollback
        exit 1
    fi

    # Test main page
    print_info "Testing main application page..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://laguna.ku.lt/DA/)
    if [ "$HTTP_CODE" = "200" ]; then
        print_success "Main page is accessible (HTTP $HTTP_CODE)"
    else
        print_error "Main page returned HTTP $HTTP_CODE"
        print_warning "Rolling back..."
        rollback
        exit 1
    fi
}

rollback() {
    print_header "Rolling Back to Previous Version"

    LATEST_BACKUP=$(ls -t "$BACKUP_DIR" | head -n 1)

    if [ -z "$LATEST_BACKUP" ]; then
        print_error "No backup found for rollback!"
        exit 1
    fi

    print_info "Restoring from backup: $LATEST_BACKUP"

    sudo systemctl stop "$PROD_SERVICE"

    cd "$PROD_DIR"
    git stash

    rsync -a --exclude=.git --exclude=venv "$BACKUP_DIR/$LATEST_BACKUP/" "$PROD_DIR/"

    sudo systemctl start "$PROD_SERVICE"

    print_success "Rollback complete"
}

show_summary() {
    print_header "Deployment Summary"

    echo -e "\n${GREEN}✓ Deployment Successful!${NC}\n"

    cd "$PROD_DIR"
    echo -e "${BLUE}Production (main branch):${NC}"
    git log -1 --pretty=format:"  • Commit: %h%n  • Message: %s%n  • Author: %an%n  • Date: %ar%n"

    echo -e "\n${BLUE}Production Status:${NC}"
    sudo systemctl status "$PROD_SERVICE" --no-pager -l | head -10

    echo -e "\n${BLUE}Access URLs:${NC}"
    echo "  • Production:    http://laguna.ku.lt/DA/"
    echo "  • Development:   http://laguna.ku.lt:5003"
    echo "  • Health Check:  http://laguna.ku.lt/DA/health"

    echo -e "\n${BLUE}Git Status:${NC}"
    echo "  • Production branch:  main ($(git rev-parse --short HEAD))"
    cd "$DEV_DIR"
    echo "  • Development branch: development ($(git rev-parse --short HEAD))"

    echo -e "\n${BLUE}Useful Commands:${NC}"
    echo "  • View prod logs:  sudo journalctl -u $PROD_SERVICE -f"
    echo "  • View dev logs:   tail -f $DEV_DIR/logs/dev-console.log"
    echo "  • Git status:      cd DAViewer-prod && git log -5 --oneline"
    echo "  • Rollback:        $MAIN_REPO/deployment/scripts/deploy_dev_to_prod_git.sh --rollback"

    echo -e "\n${BLUE}Next Steps:${NC}"
    echo "  1. Test the production deployment thoroughly"
    echo "  2. Monitor logs for any issues"
    echo "  3. Continue development in: $DEV_DIR"

    print_success "Deployment completed successfully!"
}

main() {
    print_header "MarineSABRES DA Tool - Git-Aware Deployment"

    print_info "Development: $DEV_DIR (development branch)"
    print_info "Production:  $PROD_DIR (main branch)"

    check_permissions
    check_git_status
    check_development
    show_git_changes
    merge_to_main
    backup_production
    stop_production
    update_production_code
    update_dependencies
    install_service
    start_production
    test_production
    show_summary
}

case "${1:-}" in
    --rollback)
        rollback
        ;;
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Deploy development branch to production (git-aware)"
        echo ""
        echo "Options:"
        echo "  (no args)     Deploy development to production"
        echo "  --rollback    Rollback to previous production version"
        echo "  --help, -h    Show this help message"
        echo ""
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
