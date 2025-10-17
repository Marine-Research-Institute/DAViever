#!/bin/bash
# ============================================================================
# MarineSABRES Demonstration Area Tool - Deployment Script
# Deploys to: http://laguna.ku.lt/DA/
# ============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_DIR="/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer"
SERVICE_NAME="marinesabres-da"
NGINX_CONF_SOURCE="$APP_DIR/nginx-da.conf"
NGINX_CONF_DEST="/etc/nginx/sites-available/default.d-da.conf"
SYSTEMD_SERVICE_SOURCE="$APP_DIR/marinesabres-da.service"
SYSTEMD_SERVICE_DEST="/etc/systemd/system/marinesabres-da.service"
VENV_DIR="$APP_DIR/venv"
LOG_DIR="$APP_DIR/logs"

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
    echo -e "${BLUE}$1${NC}"
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

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check if in correct directory
    if [ ! -f "$APP_DIR/app.py" ]; then
        print_error "app.py not found in $APP_DIR"
        exit 1
    fi
    print_success "Found app.py"

    # Check if virtual environment exists
    if [ ! -d "$VENV_DIR" ]; then
        print_error "Virtual environment not found at $VENV_DIR"
        print_info "Run: python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt"
        exit 1
    fi
    print_success "Virtual environment exists"

    # Check if dependencies are installed
    if ! "$VENV_DIR/bin/python" -c "import flask, gunicorn, requests" 2>/dev/null; then
        print_error "Python dependencies not installed"
        print_info "Run: source venv/bin/activate && pip install -r requirements.txt"
        exit 1
    fi
    print_success "Python dependencies installed"

    # Check if nginx is installed
    if ! command -v nginx &> /dev/null; then
        print_error "Nginx is not installed"
        print_info "Install with: sudo apt-get install nginx"
        exit 1
    fi
    print_success "Nginx is installed"

    # Check if systemd is available
    if ! command -v systemctl &> /dev/null; then
        print_error "systemctl not found"
        exit 1
    fi
    print_success "systemd is available"
}

# Create logs directory
setup_logs() {
    print_header "Setting Up Logs Directory"

    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        print_success "Created logs directory"
    else
        print_info "Logs directory already exists"
    fi

    # Ensure correct permissions
    chmod 755 "$LOG_DIR"
    print_success "Set logs directory permissions"
}

# Generate production SECRET_KEY
generate_secret_key() {
    print_header "Checking SECRET_KEY Configuration"

    if grep -q "change-this-in-production-to-secure-key" "$SYSTEMD_SERVICE_SOURCE" 2>/dev/null; then
        print_warning "Default SECRET_KEY detected in service file"
        print_info "Generating secure SECRET_KEY..."

        # Generate a secure random key
        SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(32))')

        # Create a temporary service file with the new key
        sed "s/change-this-in-production-to-secure-key/$SECRET_KEY/" "$SYSTEMD_SERVICE_SOURCE" > "${SYSTEMD_SERVICE_SOURCE}.tmp"

        print_success "Generated new SECRET_KEY"
        print_info "Service file updated with secure key"

        SYSTEMD_SERVICE_SOURCE="${SYSTEMD_SERVICE_SOURCE}.tmp"
    else
        print_success "SECRET_KEY configuration looks good"
    fi
}

# Stop existing service
stop_service() {
    print_header "Stopping Existing Service"

    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        print_info "Stopping $SERVICE_NAME service..."
        sudo systemctl stop "$SERVICE_NAME"
        print_success "Service stopped"
    else
        print_info "Service is not running"
    fi
}

# Install nginx configuration
install_nginx_config() {
    print_header "Installing Nginx Configuration"

    # Copy nginx configuration
    sudo cp "$NGINX_CONF_SOURCE" "$NGINX_CONF_DEST"
    print_success "Copied nginx configuration to $NGINX_CONF_DEST"

    # Check if default config includes our conf file
    if ! grep -q "include /etc/nginx/sites-available/default.d-da.conf;" /etc/nginx/sites-available/default; then
        print_warning "Nginx default config doesn't include $NGINX_CONF_DEST"
        print_info "Adding include directive..."

        # Backup default config
        sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup.$(date +%Y%m%d_%H%M%S)

        # Add include directive after server_name directive
        sudo sed -i '/server_name _;/a \    include /etc/nginx/sites-available/default.d-da.conf;' /etc/nginx/sites-available/default

        print_success "Added include directive to nginx default config"
    else
        print_success "Nginx default config already includes our configuration"
    fi

    # Test nginx configuration
    print_info "Testing nginx configuration..."
    if sudo nginx -t; then
        print_success "Nginx configuration test passed"
    else
        print_error "Nginx configuration test failed"
        exit 1
    fi
}

# Install systemd service
install_systemd_service() {
    print_header "Installing Systemd Service"

    # Copy service file
    sudo cp "$SYSTEMD_SERVICE_SOURCE" "$SYSTEMD_SERVICE_DEST"
    print_success "Copied service file to $SYSTEMD_SERVICE_DEST"

    # Reload systemd daemon
    sudo systemctl daemon-reload
    print_success "Reloaded systemd daemon"

    # Enable service to start on boot
    sudo systemctl enable "$SERVICE_NAME"
    print_success "Enabled $SERVICE_NAME to start on boot"
}

# Start service
start_service() {
    print_header "Starting Service"

    # Start the service
    sudo systemctl start "$SERVICE_NAME"

    # Wait a moment for the service to start
    sleep 3

    # Check service status
    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "$SERVICE_NAME service is running"
    else
        print_error "$SERVICE_NAME service failed to start"
        print_info "Check logs with: sudo journalctl -u $SERVICE_NAME -n 50 --no-pager"
        exit 1
    fi
}

# Reload nginx
reload_nginx() {
    print_header "Reloading Nginx"

    sudo systemctl reload nginx
    print_success "Nginx reloaded"
}

# Show status
show_status() {
    print_header "Deployment Status"

    # Service status
    echo -e "\n${BLUE}Service Status:${NC}"
    sudo systemctl status "$SERVICE_NAME" --no-pager -l | head -20

    # Show URLs
    echo -e "\n${GREEN}Deployment Complete!${NC}"
    echo -e "\n${BLUE}Access the application at:${NC}"
    echo "  • Public URL:  http://laguna.ku.lt/DA/"
    echo "  • Health Check: http://laguna.ku.lt/DA/health"
    echo "  • Test Page:    http://laguna.ku.lt/DA/test"

    # Show useful commands
    echo -e "\n${BLUE}Useful Commands:${NC}"
    echo "  • View logs:       sudo journalctl -u $SERVICE_NAME -f"
    echo "  • Restart service: sudo systemctl restart $SERVICE_NAME"
    echo "  • Stop service:    sudo systemctl stop $SERVICE_NAME"
    echo "  • Service status:  sudo systemctl status $SERVICE_NAME"
    echo "  • Nginx status:    sudo systemctl status nginx"
}

# Cleanup temporary files
cleanup() {
    if [ -f "${SYSTEMD_SERVICE_SOURCE}.tmp" ]; then
        rm -f "${SYSTEMD_SERVICE_SOURCE}.tmp"
    fi
}

# Main deployment function
main() {
    print_header "MarineSABRES Demonstration Area Tool - Deployment"
    print_info "Deploying to: http://laguna.ku.lt/DA/"

    # Set trap for cleanup
    trap cleanup EXIT

    # Run deployment steps
    check_permissions
    check_prerequisites
    setup_logs
    generate_secret_key
    stop_service
    install_nginx_config
    install_systemd_service
    start_service
    reload_nginx
    show_status

    print_success "Deployment completed successfully!"
}

# Run main function
main "$@"
