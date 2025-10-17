#!/bin/bash
################################################################################
# Fix Systemd Service Type Issue
#
# Changes Type=notify to Type=simple for Gunicorn compatibility
################################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SERVICE_FILE="/etc/systemd/system/marbefes-bbt.service"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Fixing Systemd Service Type                             ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Please run as root or with sudo${NC}"
    exit 1
fi

echo -e "${BLUE}[1/4]${NC} Backing up service file..."
cp "$SERVICE_FILE" "${SERVICE_FILE}.backup"
echo -e "${GREEN}✓${NC} Backup created: ${SERVICE_FILE}.backup"

echo ""
echo -e "${BLUE}[2/4]${NC} Changing Type=notify to Type=simple..."
sed -i 's/Type=notify/Type=simple/' "$SERVICE_FILE"
echo -e "${GREEN}✓${NC} Service type updated"

echo ""
echo -e "${BLUE}[3/4]${NC} Reloading systemd daemon..."
systemctl daemon-reload
echo -e "${GREEN}✓${NC} Daemon reloaded"

echo ""
echo -e "${BLUE}[4/4]${NC} Starting service..."
if systemctl start marbefes-bbt.service; then
    echo -e "${GREEN}✓${NC} Service started successfully!"
    echo ""
    echo -e "${BLUE}Service Status:${NC}"
    systemctl status marbefes-bbt.service --no-pager -l | head -15
else
    echo -e "${RED}✗${NC} Service failed to start"
    echo ""
    echo -e "${YELLOW}Recent logs:${NC}"
    journalctl -u marbefes-bbt.service -n 20 --no-pager
    exit 1
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Service Fixed and Running!                               ║${NC}"
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""
echo -e "${BLUE}Test the application:${NC}"
echo -e "  curl -I http://localhost/BBTS"
echo -e "  curl http://localhost/BBTS/api/layers"
echo ""
