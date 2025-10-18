#!/bin/bash
# ============================================================================
# MarineSABRES Demonstration Area Tool - Deploy Development to Production
# Safely transitions development version to production
# ============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
BASE_DIR="/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES"
MAIN_REPO="$BASE_DIR/DAViewer"
DEV_DIR="$BASE_DIR/DAViewer-dev"
PROD_DIR="$BASE_DIR/DAViewer"  # NOTE: Currently production runs from DAViewer, not DAViewer-prod
BACKUP_DIR="$BASE_DIR/DAViewer-backups"
DEV_SERVICE="marinesabres-da-dev"
PROD_SERVICE="marinesabres-da"  # NOTE: Actual service is marinesabres-da, not marinesabres-da-prod

# Print functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "============================================================================"
    echo -e "${MAGENTA}$1${NC}"
    echo "============================================================================"
}

# Check if running with correct permissions
check_permissions() {
    print_header "Checking Permissions"

    if [ "$EUID" -eq 0 ]; then
        print_error "This script should NOT be run as root"
        print_info "Run it as regular user (razinka)"
        print_info "Sudo will be requested when needed"
        exit 1
    fi

    print_success "Running as user: $(whoami)"
}

# Verify development version is working
check_development() {
    print_header "Verifying Development Version"

    # Check if development directory exists
    if [ ! -d "$DEV_DIR" ]; then
        print_error "Development directory not found: $DEV_DIR"
        exit 1
    fi
    print_success "Development directory found"

    # Check if development server is running (on-demand, not systemd)
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
        cd "$DEV_DIR"
        ./start_dev.sh || {
            print_error "Failed to start development server"
            exit 1
        }
        sleep 3
    fi

    # Test development health endpoint
    print_info "Testing development health endpoint..."
    if curl -s -f http://localhost:5003/health > /dev/null; then
        print_success "Development version is healthy"
    else
        print_error "Development version health check failed"
        print_info "Cannot deploy unhealthy development version"
        exit 1
    fi
}

# Create backup of current production
backup_production() {
    print_header "Backing Up Current Production"

    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"

    # Create timestamped backup
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_PATH="$BACKUP_DIR/backup_$TIMESTAMP"

    print_info "Creating backup at: $BACKUP_PATH"
    cp -r "$PROD_DIR" "$BACKUP_PATH"
    print_success "Backup created successfully"

    # Keep only last 5 backups
    print_info "Cleaning up old backups (keeping last 5)..."
    cd "$BACKUP_DIR"
    ls -t | tail -n +6 | xargs -r rm -rf
    BACKUP_COUNT=$(ls | wc -l)
    print_success "Backup cleanup complete ($BACKUP_COUNT backups retained)"
}

# Show differences between dev and prod
show_differences() {
    print_header "Analyzing Changes"

    print_info "Comparing development and production..."

    # Show which files have changed
    echo -e "\n${BLUE}Modified files:${NC}"
    diff -rq "$DEV_DIR" "$PROD_DIR" \
        --exclude=venv \
        --exclude=__pycache__ \
        --exclude=.git \
        --exclude=logs \
        --exclude='*.pyc' \
        --exclude='.pytest_cache' \
        | grep -v "Only in" || echo "  (No differences detected)"

    echo ""
    read -p "$(echo -e ${YELLOW}Continue with deployment? [y/N]:${NC} )" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled by user"
        exit 0
    fi
}

# Stop production service
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

# Sync development to production
sync_code() {
    print_header "Syncing Development to Production"

    print_info "Syncing code from development to production..."

    # Sync application code (exclude venv, logs, caches, git)
    rsync -av --delete \
        --exclude=venv \
        --exclude=logs \
        --exclude=__pycache__ \
        --exclude='*.pyc' \
        --exclude=.git \
        --exclude=.pytest_cache \
        --exclude=.claude \
        --exclude='*.log' \
        "$DEV_DIR/" "$PROD_DIR/"

    print_success "Code synced successfully"

    # Ensure production-specific files are correct
    print_info "Verifying production configuration..."

    # Check if production gunicorn config exists
    if [ ! -f "$PROD_DIR/gunicorn.conf.py" ]; then
        print_error "Production gunicorn config missing!"
        exit 1
    fi

    # Check if production service file exists
    if [ ! -f "$PROD_DIR/marinesabres-da-prod.service" ]; then
        print_error "Production service file missing!"
        exit 1
    fi

    print_success "Production configuration verified"
}

# Update dependencies if needed
update_dependencies() {
    print_header "Updating Production Dependencies"

    print_info "Checking if requirements have changed..."

    if ! diff -q "$DEV_DIR/requirements.txt" "$PROD_DIR/requirements.txt" > /dev/null 2>&1; then
        print_warning "Requirements have changed!"
        print_info "Updating production dependencies..."

        cd "$PROD_DIR"
        source venv/bin/activate
        pip install -r requirements.txt --upgrade
        deactivate

        print_success "Dependencies updated"
    else
        print_info "No dependency changes detected"
    fi
}

# Install/update systemd service
install_service() {
    print_header "Installing Production Service"

    # Copy service file to systemd directory
    sudo cp "$PROD_DIR/marinesabres-da-prod.service" /etc/systemd/system/

    # Reload systemd
    sudo systemctl daemon-reload
    print_success "Systemd service installed"

    # Enable service
    sudo systemctl enable "$PROD_SERVICE"
    print_success "Service enabled for auto-start"
}

# Start production service
start_production() {
    print_header "Starting Production Service"

    print_info "Starting $PROD_SERVICE..."
    sudo systemctl start "$PROD_SERVICE"

    # Wait for service to start
    sleep 5

    # Check if service started successfully
    if sudo systemctl is-active --quiet "$PROD_SERVICE"; then
        print_success "Production service started successfully"
    else
        print_error "Production service failed to start"
        print_info "Check logs with: sudo journalctl -u $PROD_SERVICE -n 50"
        exit 1
    fi
}

# Test production deployment
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
        print_warning "Rolling back to backup..."
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
        print_warning "Rolling back to backup..."
        rollback
        exit 1
    fi
}

# Rollback function
rollback() {
    print_header "Rolling Back to Previous Version"

    # Get latest backup
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR" | head -n 1)

    if [ -z "$LATEST_BACKUP" ]; then
        print_error "No backup found for rollback!"
        exit 1
    fi

    print_info "Restoring from backup: $LATEST_BACKUP"

    # Stop production
    sudo systemctl stop "$PROD_SERVICE"

    # Restore backup
    rm -rf "$PROD_DIR"
    cp -r "$BACKUP_DIR/$LATEST_BACKUP" "$PROD_DIR"

    # Restart production
    sudo systemctl start "$PROD_SERVICE"

    print_success "Rollback complete"
}

# Show deployment summary
show_summary() {
    print_header "Deployment Summary"

    echo -e "\n${GREEN}✓ Deployment Successful!${NC}\n"

    echo -e "${BLUE}Production Status:${NC}"
    sudo systemctl status "$PROD_SERVICE" --no-pager -l | head -15

    echo -e "\n${BLUE}Access URLs:${NC}"
    echo "  • Production:    http://laguna.ku.lt/DA/"
    echo "  • Development:   http://laguna.ku.lt:5003"
    echo "  • Health Check:  http://laguna.ku.lt/DA/health"

    echo -e "\n${BLUE}Useful Commands:${NC}"
    echo "  • View prod logs:  sudo journalctl -u $PROD_SERVICE -f"
    echo "  • View dev logs:   tail -f $DEV_DIR/logs/dev-console.log"
    echo "  • Restart prod:    sudo systemctl restart $PROD_SERVICE"
    echo "  • Start dev:       cd $DEV_DIR && ./start_dev.sh"
    echo "  • Rollback:        $MAIN_REPO/deployment/scripts/deploy_dev_to_prod.sh --rollback"

    echo -e "\n${BLUE}Next Steps:${NC}"
    echo "  1. Test the production deployment thoroughly"
    echo "  2. Monitor logs for any issues"
    echo "  3. Continue development in: $DEV_DIR"
}

# Main deployment function
main() {
    print_header "MarineSABRES DA Tool - Deploy Development to Production"

    print_info "Development: $DEV_DIR"
    print_info "Production:  $PROD_DIR"

    # Run deployment steps
    check_permissions
    check_development
    show_differences
    backup_production
    stop_production
    sync_code
    update_dependencies
    install_service
    start_production
    test_production
    show_summary

    print_success "Deployment completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    --rollback)
        rollback
        ;;
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Deploy development version to production"
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
