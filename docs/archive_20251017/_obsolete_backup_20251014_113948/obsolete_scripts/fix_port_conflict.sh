#!/bin/bash
################################################################################
# Fix Port 5000 Conflict
#
# Finds and kills the process using port 5000
################################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Fix Port 5000 Conflict                                  ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Please run as root or with sudo${NC}"
    exit 1
fi

echo -e "${BLUE}[1/4]${NC} Checking what's using port 5000..."
echo ""

if lsof -i :5000 > /dev/null 2>&1; then
    echo -e "${YELLOW}Port 5000 is in use:${NC}"
    lsof -i :5000
    echo ""

    # Get PIDs
    PIDS=$(lsof -t -i :5000)

    echo -e "${BLUE}[2/4]${NC} Process details:"
    for pid in $PIDS; do
        echo -e "${YELLOW}PID $pid:${NC} $(ps -p $pid -o comm=) - $(ps -p $pid -o args=)"
    done
    echo ""

    echo -e "${BLUE}[3/4]${NC} Stopping processes on port 5000..."
    for pid in $PIDS; do
        echo -e "  Killing PID $pid..."
        kill -9 $pid 2>/dev/null || true
    done

    sleep 1

    echo -e "${BLUE}[4/4]${NC} Verifying port is free..."
    if lsof -i :5000 > /dev/null 2>&1; then
        echo -e "${RED}✗ Port 5000 is still in use!${NC}"
        lsof -i :5000
        exit 1
    else
        echo -e "${GREEN}✓ Port 5000 is now free!${NC}"
    fi
else
    echo -e "${GREEN}✓ Port 5000 is already free${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Port conflict resolved!${NC}"
echo ""
echo -e "${BLUE}Now start the service:${NC}"
echo -e "  ${YELLOW}sudo systemctl start marbefes-bbt${NC}"
echo ""
echo -e "${BLUE}Or if service is already trying:${NC}"
echo -e "  ${YELLOW}sudo systemctl restart marbefes-bbt${NC}"
echo ""
