#!/bin/bash
# ============================================================================
# MarineSABRES DA Tool - Initial Two-Version Setup Script
# Sets up development (on-demand) and production (systemd) environments
# ============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
BASE_DIR="/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES"
DEV_DIR="$BASE_DIR/DAViewer-dev"
PROD_DIR="$BASE_DIR/DAViewer-prod"
BACKUP_DIR="$BASE_DIR/DAViewer-prod-backups"

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
print_header "MarineSABRES DA Tool - Two-Version Setup"
print_info "Development: On-demand (start/stop scripts)"
print_info "Production:  Systemd service (auto-start)"

# 1. Create virtual environments
print_header "Setting Up Virtual Environments"

if [ ! -d "$DEV_DIR/venv" ]; then
    print_info "Creating development virtual environment..."
    cd "$DEV_DIR"
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    deactivate
    print_success "Development venv created"
else
    print_info "Development venv already exists"
fi

if [ ! -d "$PROD_DIR/venv" ]; then
    print_info "Creating production virtual environment..."
    cd "$PROD_DIR"
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    deactivate
    print_success "Production venv created"
else
    print_info "Production venv already exists"
fi

# 2. Create log directories
print_header "Creating Log Directories"
mkdir -p "$DEV_DIR/logs"
mkdir -p "$PROD_DIR/logs"
mkdir -p "$BACKUP_DIR"
print_success "Log directories created"

# 3. Install production systemd service (dev runs on-demand)
print_header "Installing Production Systemd Service"

# NOTE: Currently using marinesabres-da.service from DAViewer directory
sudo cp "$BASE_DIR/DAViewer/marinesabres-da.service" /etc/systemd/system/
sudo systemctl daemon-reload
print_success "Production service installed"

sudo systemctl enable marinesabres-da
print_success "Production service enabled for auto-start"

# 4. Configure nginx
print_header "Configuring Nginx"

NGINX_CONF="/etc/nginx/sites-available/default.d-marinesabres.conf"
sudo cp "$BASE_DIR/DAViewer/deployment/docs/nginx-combined.conf" "$NGINX_CONF"
print_success "Nginx configuration copied"

# Check if included in main config
if ! sudo grep -q "include.*default.d-marinesabres.conf" /etc/nginx/sites-available/default; then
    print_warning "Nginx configuration not included in main config"
    print_info "Adding include directive..."

    # Backup main config
    sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup.$(date +%Y%m%d_%H%M%S)

    # Add include after server_name
    sudo sed -i '/server_name _;/a \    include /etc/nginx/sites-available/default.d-marinesabres.conf;' /etc/nginx/sites-available/default

    print_success "Include directive added"
else
    print_info "Nginx configuration already included"
fi

# Test nginx
print_info "Testing nginx configuration..."
if sudo nginx -t; then
    print_success "Nginx configuration valid"
    sudo systemctl reload nginx
    print_success "Nginx reloaded"
else
    print_error "Nginx configuration test failed"
    exit 1
fi

# 5. Configure firewall
print_header "Configuring Firewall"

if command -v ufw &> /dev/null; then
    if sudo ufw status | grep -q "5003.*ALLOW"; then
        print_info "Port 5003 already allowed"
    else
        print_info "Allowing port 5003 for development..."
        sudo ufw allow 5003/tcp comment 'MarineSABRES DA Development'
        print_success "Port 5003 allowed"
    fi
else
    print_warning "UFW not installed, skipping firewall configuration"
fi

# 6. Start production service (development runs on-demand)
print_header "Starting Production Service"

print_info "Starting production service..."
sudo systemctl start marinesabres-da
sleep 2

if sudo systemctl is-active --quiet marinesabres-da; then
    print_success "Production service started"
else
    print_error "Production service failed to start"
    sudo journalctl -u marinesabres-da -n 20
    exit 1
fi

# 7. Test production endpoint
print_header "Testing Production Endpoint"

sleep 3

print_info "Testing production health endpoint..."
if curl -s -f http://laguna.ku.lt/DA/health > /dev/null; then
    print_success "Production health check passed"
else
    print_warning "Production health check failed (may need time to start)"
fi

# 8. Show summary
print_header "Setup Complete"

echo -e "\n${GREEN}✓ Two-version setup successful!${NC}\n"

echo -e "${BLUE}Access URLs:${NC}"
echo "  • Production:   http://laguna.ku.lt/DA/ (auto-starts on boot)"
echo "  • Development:  http://laguna.ku.lt:5003 (on-demand)"
echo "  • Prod Health:  http://laguna.ku.lt/DA/health"

echo -e "\n${BLUE}Production Service (Systemd):${NC}"
sudo systemctl status marinesabres-da --no-pager -l | head -5

echo -e "\n${BLUE}Development Server (On-Demand):${NC}"
echo "  • Start:  cd $DEV_DIR && ./start_dev.sh"
echo "  • Stop:   cd $DEV_DIR && ./stop_dev.sh"
echo "  • Status: cd $DEV_DIR && ./status_dev.sh"

echo -e "\n${BLUE}Next Steps:${NC}"
echo "  1. Start development server: cd $DEV_DIR && ./start_dev.sh"
echo "  2. Test both versions in your browser"
echo "  3. Make changes in DAViewer-dev/"
echo "  4. Deploy to production: $BASE_DIR/DAViewer/deployment/scripts/deploy_dev_to_prod.sh"
echo "  5. Read documentation: $BASE_DIR/DAViewer/deployment/docs/DEPLOYMENT_TWO_VERSION.md"

echo -e "\n${BLUE}Useful Commands:${NC}"
echo "  • View prod logs:  sudo journalctl -u marinesabres-da -f"
echo "  • View dev logs:   tail -f $DEV_DIR/logs/dev-console.log"
echo "  • Deploy to prod:  $BASE_DIR/DAViewer/deployment/scripts/deploy_dev_to_prod.sh"
echo "  • Rollback:        $BASE_DIR/DAViewer/deployment/scripts/deploy_dev_to_prod.sh --rollback"

print_success "Setup completed successfully!"
