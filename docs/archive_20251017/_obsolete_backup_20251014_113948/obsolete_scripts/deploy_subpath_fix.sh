#!/bin/bash
#
# Deployment Script: Subpath URL Fix for MARBEFES BBT Application
# Fixes logo and API URL issues when deployed at /BBTS subpath
#
# Usage: ./deploy_subpath_fix.sh
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REMOTE_USER="razinka"
REMOTE_HOST="laguna.ku.lt"
REMOTE_APP_DIR="/var/www/marbefes-bbt"
SERVICE_NAME="marbefes-bbt"
LOCAL_DIR="/home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck"

# Print colored message
print_msg() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

print_header() {
    echo ""
    print_msg "$BLUE" "=========================================="
    print_msg "$BLUE" "$1"
    print_msg "$BLUE" "=========================================="
}

print_success() {
    print_msg "$GREEN" "✅ $1"
}

print_error() {
    print_msg "$RED" "❌ $1"
}

print_warning() {
    print_msg "$YELLOW" "⚠️  $1"
}

print_info() {
    print_msg "$BLUE" "ℹ️  $1"
}

# Change to project directory
cd "$LOCAL_DIR" || {
    print_error "Failed to change to directory: $LOCAL_DIR"
    exit 1
}

print_header "MARBEFES BBT - Subpath URL Fix Deployment"
echo ""
print_info "This script will deploy fixes for:"
print_info "  • Logo not loading (404 error)"
print_info "  • API calls failing (404 errors)"
print_info "  • BBT navigation not working"
echo ""
print_info "Deployment target: $REMOTE_USER@$REMOTE_HOST:$REMOTE_APP_DIR"
echo ""

# Verify local files exist
print_header "Step 1: Verifying Local Files"
echo ""

if [ ! -f "app.py" ]; then
    print_error "app.py not found in current directory"
    exit 1
fi
print_success "app.py found"

if [ ! -f "templates/index.html" ]; then
    print_error "templates/index.html not found"
    exit 1
fi
print_success "templates/index.html found"

# Check SSH connectivity
print_header "Step 2: Testing SSH Connection"
echo ""

print_info "Testing connection to $REMOTE_HOST..."
if ssh -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_USER@$REMOTE_HOST" "echo 'SSH connection successful'" 2>/dev/null; then
    print_success "SSH connection successful (key-based authentication)"
    SSH_METHOD="key"
else
    print_warning "Key-based SSH not available, will use password authentication"
    print_info "You will be prompted for your password multiple times"
    SSH_METHOD="password"
fi

# Prompt for confirmation
echo ""
print_warning "Ready to deploy. This will:"
echo "  1. Create backup of current files on server"
echo "  2. Copy updated app.py and templates/index.html"
echo "  3. Restart the $SERVICE_NAME service"
echo ""
read -p "Continue with deployment? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Deployment cancelled by user"
    exit 0
fi

# Create backup on remote server
print_header "Step 3: Creating Backup on Server"
echo ""

BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backups/subpath_fix_${BACKUP_TIMESTAMP}"

print_info "Creating backup directory: $BACKUP_DIR"

ssh "$REMOTE_USER@$REMOTE_HOST" "
    set -e
    cd $REMOTE_APP_DIR
    mkdir -p $BACKUP_DIR
    cp app.py $BACKUP_DIR/
    cp templates/index.html $BACKUP_DIR/
    echo 'Backup created successfully'
" && print_success "Backup created at $REMOTE_HOST:$REMOTE_APP_DIR/$BACKUP_DIR" || {
    print_error "Failed to create backup"
    exit 1
}

# Copy updated files
print_header "Step 4: Copying Updated Files"
echo ""

print_info "Copying app.py..."
scp app.py "$REMOTE_USER@$REMOTE_HOST:$REMOTE_APP_DIR/" && \
    print_success "app.py copied successfully" || {
    print_error "Failed to copy app.py"
    exit 1
}

print_info "Copying templates/index.html..."
scp templates/index.html "$REMOTE_USER@$REMOTE_HOST:$REMOTE_APP_DIR/templates/" && \
    print_success "templates/index.html copied successfully" || {
    print_error "Failed to copy templates/index.html"
    exit 1
}

# Restart service
print_header "Step 5: Restarting Service"
echo ""

print_info "Restarting $SERVICE_NAME service..."
ssh "$REMOTE_USER@$REMOTE_HOST" "sudo systemctl restart $SERVICE_NAME" && \
    print_success "Service restarted successfully" || {
    print_error "Failed to restart service"
    exit 1
}

# Wait for service to start
print_info "Waiting for service to start..."
sleep 3

# Check service status
print_info "Checking service status..."
ssh "$REMOTE_USER@$REMOTE_HOST" "sudo systemctl is-active $SERVICE_NAME" > /dev/null 2>&1 && \
    print_success "Service is running" || {
    print_error "Service is not running!"
    print_info "Fetching service status..."
    ssh "$REMOTE_USER@$REMOTE_HOST" "sudo systemctl status $SERVICE_NAME --no-pager"
    exit 1
}

# Verification
print_header "Step 6: Verification"
echo ""

BASE_URL="http://laguna.ku.lt/BBTS"

print_info "Testing logo URL..."
LOGO_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/logo/marbefes_02.png")
if [ "$LOGO_STATUS" = "200" ]; then
    print_success "Logo accessible (HTTP $LOGO_STATUS)"
else
    print_warning "Logo returned HTTP $LOGO_STATUS (expected 200)"
fi

print_info "Testing API endpoint..."
API_URL="$BASE_URL/api/vector/layer/Bbts%20-%20Broad%20Belt%20Transects"
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL")
if [ "$API_STATUS" = "200" ]; then
    print_success "API endpoint accessible (HTTP $API_STATUS)"
else
    print_warning "API returned HTTP $API_STATUS (expected 200)"
fi

print_info "Testing main page..."
PAGE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL")
if [ "$PAGE_STATUS" = "200" ]; then
    print_success "Main page accessible (HTTP $PAGE_STATUS)"
else
    print_warning "Main page returned HTTP $PAGE_STATUS (expected 200)"
fi

# Summary
print_header "Deployment Complete!"
echo ""
print_success "All files deployed successfully"
print_success "Service is running"
echo ""
print_info "Application URL: $BASE_URL"
print_info "Backup location: $REMOTE_HOST:$REMOTE_APP_DIR/$BACKUP_DIR"
echo ""
print_msg "$GREEN" "Next Steps:"
echo "  1. Open $BASE_URL in your browser"
echo "  2. Verify the MARBEFES logo appears in the header"
echo "  3. Open browser console (F12) and check for errors"
echo "  4. Test BBT navigation dropdown"
echo "  5. Verify vector layers load correctly"
echo ""
print_info "If you need to rollback:"
echo "  ssh $REMOTE_USER@$REMOTE_HOST"
echo "  cd $REMOTE_APP_DIR"
echo "  cp $BACKUP_DIR/app.py ."
echo "  cp $BACKUP_DIR/index.html templates/"
echo "  sudo systemctl restart $SERVICE_NAME"
echo ""
print_success "Deployment completed successfully! 🎉"
echo ""
