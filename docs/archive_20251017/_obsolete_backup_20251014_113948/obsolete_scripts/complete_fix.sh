#!/bin/bash
################################################################################
# Complete Fix - Stop Service, Clear Port, Start Everything
################################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Complete Service Fix & Restart                          ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Please run as root or with sudo${NC}"
    exit 1
fi

echo -e "${BLUE}[1/6]${NC} Stopping marbefes-bbt service..."
systemctl stop marbefes-bbt.service 2>/dev/null || true
sleep 2
echo -e "${GREEN}✓${NC} Service stop requested"

echo ""
echo -e "${BLUE}[2/6]${NC} Killing any remaining Gunicorn processes..."
pkill -9 -f "gunicorn.*marbefes" 2>/dev/null || true
sleep 1
echo -e "${GREEN}✓${NC} Processes cleaned up"

echo ""
echo -e "${BLUE}[3/6]${NC} Checking port 5000..."
if lsof -i :5000 > /dev/null 2>&1; then
    echo -e "${YELLOW}Port 5000 still in use, forcing cleanup:${NC}"
    lsof -i :5000
    PIDS=$(lsof -t -i :5000)
    for pid in $PIDS; do
        echo "  Killing PID $pid..."
        kill -9 $pid 2>/dev/null || true
    done
    sleep 1
fi

if lsof -i :5000 > /dev/null 2>&1; then
    echo -e "${RED}✗ Port 5000 still in use!${NC}"
    lsof -i :5000
    exit 1
else
    echo -e "${GREEN}✓${NC} Port 5000 is free"
fi

echo ""
echo -e "${BLUE}[4/6]${NC} Starting marbefes-bbt service..."
if systemctl start marbefes-bbt.service; then
    echo -e "${GREEN}✓${NC} Service started"
else
    echo -e "${RED}✗${NC} Service failed to start"
    echo ""
    echo -e "${YELLOW}Recent logs:${NC}"
    journalctl -u marbefes-bbt.service -n 20 --no-pager
    echo ""
    echo -e "${YELLOW}Gunicorn error log:${NC}"
    tail -20 /var/www/marbefes-bbt/logs/gunicorn-error.log
    exit 1
fi

sleep 3

echo ""
echo -e "${BLUE}[5/6]${NC} Checking if service is running..."
if systemctl is-active marbefes-bbt.service > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Service is active"
    systemctl status marbefes-bbt.service --no-pager -l | head -15
else
    echo -e "${RED}✗${NC} Service is not active"
    systemctl status marbefes-bbt.service --no-pager -l
    exit 1
fi

echo ""
echo -e "${BLUE}[6/6]${NC} Ensuring nginx is running..."
if systemctl is-active nginx > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Nginx is already running"
else
    echo -e "${YELLOW}Starting nginx...${NC}"
    systemctl start nginx
    echo -e "${GREEN}✓${NC} Nginx started"
fi

systemctl reload nginx 2>/dev/null || true

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Services Started Successfully!                           ║${NC}"
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""

echo -e "${BLUE}Testing application...${NC}"
sleep 2

# Test local connection
if curl -sf -I http://localhost/BBTS > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Application responds at http://localhost/BBTS"
else
    echo -e "${YELLOW}⚠${NC} Cannot reach http://localhost/BBTS"
    echo -e "  This might be normal if nginx needs more configuration"
fi

# Test port 5000 directly
if curl -sf -I http://localhost:5000 > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Gunicorn responds on port 5000"
else
    echo -e "${YELLOW}⚠${NC} Gunicorn not responding on port 5000"
fi

echo ""
echo -e "${BLUE}Service Status:${NC}"
echo -e "  marbefes-bbt: $(systemctl is-active marbefes-bbt)"
echo -e "  nginx:        $(systemctl is-active nginx)"

echo ""
echo -e "${BLUE}Access URLs:${NC}"
echo -e "  ${YELLOW}http://localhost/BBTS${NC}"
echo -e "  ${YELLOW}http://laguna.ku.lt/BBTS${NC}"
echo -e "  ${YELLOW}http://$(hostname -I | awk '{print $1}')/BBTS${NC}"

echo ""
echo -e "${BLUE}Monitor logs:${NC}"
echo -e "  sudo journalctl -u marbefes-bbt -f"
echo -e "  sudo tail -f /var/www/marbefes-bbt/logs/gunicorn-error.log"
echo ""
