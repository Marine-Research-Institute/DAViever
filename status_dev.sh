#!/bin/bash
# ============================================================================
# MarineSABRES DA Tool - Development Server Status
# ============================================================================

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
DEV_DIR="/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer-dev"
PID_FILE="$DEV_DIR/.gunicorn.pid"
LOG_FILE="$DEV_DIR/logs/dev-console.log"

cd "$DEV_DIR"

echo -e "${BLUE}MarineSABRES DA Tool - Development Server Status${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
echo ""

# Check if PID file exists
if [ ! -f "$PID_FILE" ]; then
    echo -e "${RED}Status: STOPPED${NC}"
    echo -e "${YELLOW}Start with: ./start_dev.sh${NC}"
    exit 0
fi

# Read PID
PID=$(cat "$PID_FILE")

# Check if process exists
if ! ps -p "$PID" > /dev/null 2>&1; then
    echo -e "${RED}Status: STOPPED (stale PID file)${NC}"
    rm -f "$PID_FILE"
    echo -e "${YELLOW}Start with: ./start_dev.sh${NC}"
    exit 0
fi

# Server is running
echo -e "${GREEN}Status: RUNNING${NC}"
echo ""
echo -e "${BLUE}Process Info:${NC}"
echo "  • PID: $PID"
ps -p "$PID" -o pid,ppid,%cpu,%mem,etime,cmd --no-headers | awk '{printf "  • CPU: %s%%\n  • Memory: %s%%\n  • Uptime: %s\n  • Command: %s %s %s\n", $3, $4, $5, $6, $7, $8}'
echo ""
echo -e "${BLUE}Access URLs:${NC}"
echo "  • Main interface: http://laguna.ku.lt:5003"
echo "  • Health check:   http://laguna.ku.lt:5003/health"
echo "  • Local:          http://localhost:5003"
echo ""
echo -e "${BLUE}Commands:${NC}"
echo "  • View logs:   tail -f $LOG_FILE"
echo "  • Stop server: ./stop_dev.sh"
echo ""

# Test health endpoint
echo -e "${BLUE}Health Check:${NC}"
if curl -s -f http://localhost:5003/health > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ Healthy${NC}"
else
    echo -e "  ${YELLOW}⚠ Health check failed (server may be starting)${NC}"
fi

echo ""
echo -e "${BLUE}Recent Logs (last 5 lines):${NC}"
if [ -f "$LOG_FILE" ]; then
    tail -n 5 "$LOG_FILE" | sed 's/^/  /'
else
    echo "  (no logs yet)"
fi
