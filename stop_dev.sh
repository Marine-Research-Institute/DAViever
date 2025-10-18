#!/bin/bash
# ============================================================================
# MarineSABRES DA Tool - Stop Development Server
# ============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
DEV_DIR="/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer-dev"
PID_FILE="$DEV_DIR/.gunicorn.pid"

cd "$DEV_DIR"

echo -e "${BLUE}Stopping MarineSABRES DA Tool - Development Server${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

# Check if PID file exists
if [ ! -f "$PID_FILE" ]; then
    echo -e "${YELLOW}Development server is not running (no PID file found)${NC}"
    exit 0
fi

# Read PID
PID=$(cat "$PID_FILE")

# Check if process exists
if ! ps -p "$PID" > /dev/null 2>&1; then
    echo -e "${YELLOW}Development server is not running (stale PID file)${NC}"
    rm -f "$PID_FILE"
    exit 0
fi

# Stop the process
echo -e "${BLUE}Stopping Gunicorn (PID: $PID)...${NC}"
kill "$PID"

# Wait for graceful shutdown
sleep 2

# Force kill if still running
if ps -p "$PID" > /dev/null 2>&1; then
    echo -e "${YELLOW}Forcing shutdown...${NC}"
    kill -9 "$PID" 2>/dev/null || true
fi

# Remove PID file
rm -f "$PID_FILE"

echo -e "${GREEN}✓ Development server stopped${NC}"
