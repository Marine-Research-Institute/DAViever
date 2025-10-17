#!/bin/bash
################################################################################
# Fix Numpy Binary Incompatibility Issue
# Error: numpy.dtype size changed - binary incompatibility
################################################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}════════════════════════════════════════════════════${NC}"
echo -e "${RED}   CRITICAL: Fixing Numpy Binary Incompatibility${NC}"
echo -e "${RED}════════════════════════════════════════════════════${NC}"
echo ""

PROD_DIR="/var/www/marbefes-bbt"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}⚠ This script requires sudo privileges${NC}"
    echo -e "${BLUE}→ Re-running with sudo...${NC}"
    exec sudo bash "$0" "$@"
fi

echo -e "${BLUE}[1/5]${NC} Stopping service..."
systemctl stop marbefes-bbt
echo -e "${GREEN}✓${NC} Service stopped"

echo -e "\n${BLUE}[2/5]${NC} Activating virtual environment..."
cd "$PROD_DIR"
source venv/bin/activate

echo -e "\n${BLUE}[3/5]${NC} Reinstalling numpy and pandas (fixing binary compatibility)..."
pip uninstall -y numpy pandas
pip install --no-cache-dir numpy pandas
echo -e "${GREEN}✓${NC} Numpy and pandas reinstalled"

echo -e "\n${BLUE}[4/5]${NC} Reinstalling geopandas dependencies..."
pip uninstall -y geopandas
pip install --no-cache-dir geopandas
echo -e "${GREEN}✓${NC} Geopandas reinstalled"

echo -e "\n${BLUE}[5/5]${NC} Testing import..."
python3 -c "import numpy; import pandas; import geopandas; print('✓ All imports successful')"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Import test passed"
else
    echo -e "${RED}✗${NC} Import test failed"
    exit 1
fi

deactivate

echo -e "\n${BLUE}[6/6]${NC} Starting service..."
systemctl start marbefes-bbt
sleep 3

if systemctl is-active --quiet marbefes-bbt; then
    echo -e "${GREEN}✓${NC} Service started successfully"
else
    echo -e "${RED}✗${NC} Service failed to start"
    journalctl -u marbefes-bbt -n 20 --no-pager
    exit 1
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Fixed! Service is running${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Verification:${NC}"
echo -e "  ${YELLOW}curl -I http://laguna.ku.lt/BBTS/${NC}"
echo ""
