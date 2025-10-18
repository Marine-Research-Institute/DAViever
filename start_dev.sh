#!/bin/bash
# ============================================================================
# MarineSABRES DA Tool - Start Development Server
# Runs on-demand at http://laguna.ku.lt:5003
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
LOG_FILE="$DEV_DIR/logs/dev-console.log"

cd "$DEV_DIR"

# Check if already running
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo -e "${YELLOW}Development server is already running (PID: $PID)${NC}"
        echo -e "${BLUE}Access at: http://laguna.ku.lt:5003${NC}"
        echo -e "${BLUE}Stop with: ./stop_dev.sh${NC}"
        exit 1
    else
        # Stale PID file
        rm -f "$PID_FILE"
    fi
fi

# Create logs directory if it doesn't exist
mkdir -p logs

echo -e "${BLUE}Starting MarineSABRES DA Tool - Development Server${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

# Activate virtual environment
if [ ! -d "venv" ]; then
    echo -e "${RED}Virtual environment not found!${NC}"
    echo -e "${YELLOW}Create it with: python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt${NC}"
    exit 1
fi

source venv/bin/activate

# Start Gunicorn in background
echo -e "${BLUE}Starting Gunicorn with auto-reload...${NC}"

nohup gunicorn -c gunicorn.conf.py app:app > "$LOG_FILE" 2>&1 &
GUNICORN_PID=$!

# Save PID
echo $GUNICORN_PID > "$PID_FILE"

# Wait a moment for server to start
sleep 2

# Check if still running
if ps -p $GUNICORN_PID > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Development server started successfully!${NC}"
    echo ""
    echo -e "${BLUE}Access URLs:${NC}"
    echo "  • Main interface: http://laguna.ku.lt:5003"
    echo "  • Health check:   http://laguna.ku.lt:5003/health"
    echo "  • Local:          http://localhost:5003"
    echo ""
    echo -e "${BLUE}Server Info:${NC}"
    echo "  • PID: $GUNICORN_PID"
    echo "  • Port: 5003"
    echo "  • Auto-reload: Enabled"
    echo "  • Logs: $LOG_FILE"
    echo ""
    echo -e "${BLUE}Commands:${NC}"
    echo "  • View logs:  tail -f $LOG_FILE"
    echo "  • Stop server: ./stop_dev.sh"
    echo "  • Check status: ./status_dev.sh"
    echo ""
    echo -e "${GREEN}Changes to code will automatically reload!${NC}"
else
    echo -e "${RED}✗ Failed to start development server${NC}"
    echo -e "${YELLOW}Check logs: tail -f $LOG_FILE${NC}"
    rm -f "$PID_FILE"
    exit 1
fi
