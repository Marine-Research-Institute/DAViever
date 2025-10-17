#!/bin/bash
################################################################################
# Complete Dependency Fix - Rebuild all geospatial packages
################################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROD_DIR="/var/www/marbefes-bbt"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Complete Dependency Rebuild                             ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Please run as root or with sudo${NC}"
    exit 1
fi

cd "$PROD_DIR"

echo -e "${BLUE}[1/6]${NC} Stopping service..."
systemctl stop marbefes-bbt.service 2>/dev/null || true
pkill -9 -f "gunicorn.*marbefes" 2>/dev/null || true
echo -e "${GREEN}✓${NC} Service stopped"

echo ""
echo -e "${BLUE}[2/6]${NC} Activating virtual environment..."
source "$PROD_DIR/venv/bin/activate"

echo ""
echo -e "${BLUE}[3/6]${NC} Removing problematic packages..."
pip uninstall -y geopandas fiona pyproj shapely pandas numpy 2>/dev/null || true
echo -e "${GREEN}✓${NC} Old packages removed"

echo ""
echo -e "${BLUE}[4/6]${NC} Installing core packages (no cache)..."
echo -e "${YELLOW}This will take several minutes - be patient!${NC}"

# Install in correct order
pip install --no-cache-dir 'numpy>=1.22.4,<2.0'
pip install --no-cache-dir 'pandas>=2.0.0'

echo ""
echo -e "${BLUE}[5/6]${NC} Installing geospatial packages..."
pip install --no-cache-dir pyproj
pip install --no-cache-dir shapely
pip install --no-cache-dir fiona
pip install --no-cache-dir geopandas

echo ""
echo -e "${BLUE}[6/6]${NC} Verifying installation..."
pip list | grep -E "(numpy|pandas|geopandas|fiona|pyproj|shapely)"

deactivate

echo ""
echo -e "${GREEN}✓ All packages reinstalled!${NC}"
echo ""
echo -e "${BLUE}Testing imports as www-data user...${NC}"

cd "$PROD_DIR"
sudo -u www-data "$PROD_DIR/venv/bin/python" << 'PYEOF'
import sys
sys.path.insert(0, '/var/www/marbefes-bbt')
sys.path.insert(0, '/var/www/marbefes-bbt/src')
sys.path.insert(0, '/var/www/marbefes-bbt/config')

print("\nTesting imports step by step:")
print("=" * 50)

try:
    print("1. numpy...", end=" ")
    import numpy as np
    print(f"✓ {np.__version__}")
except Exception as e:
    print(f"✗ FAILED: {e}")
    sys.exit(1)

try:
    print("2. pandas...", end=" ")
    import pandas as pd
    print(f"✓ {pd.__version__}")
except Exception as e:
    print(f"✗ FAILED: {e}")
    sys.exit(1)

try:
    print("3. geopandas...", end=" ")
    import geopandas as gpd
    print(f"✓ {gpd.__version__}")
except Exception as e:
    print(f"✗ FAILED: {e}")
    sys.exit(1)

try:
    print("4. flask...", end=" ")
    from flask import Flask
    print("✓")
except Exception as e:
    print(f"✗ FAILED: {e}")
    sys.exit(1)

try:
    print("5. app module...", end=" ")
    import app
    print("✓")
except Exception as e:
    print(f"✗ FAILED: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

try:
    print("6. wsgi_subpath...", end=" ")
    from wsgi_subpath import application
    print(f"✓ (type: {type(application).__name__})")
except Exception as e:
    print(f"✗ FAILED: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print("=" * 50)
print("✓ ALL IMPORTS SUCCESSFUL!")
print()
PYEOF

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   Dependencies Fixed - Ready to Start!                    ║${NC}"
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo ""

    echo -e "${BLUE}Starting service...${NC}"
    systemctl start marbefes-bbt.service
    sleep 3

    if systemctl is-active marbefes-bbt.service > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Service is running!${NC}"
        echo ""
        systemctl status marbefes-bbt.service --no-pager -l | head -15
        echo ""
        echo -e "${BLUE}Test the application:${NC}"
        echo -e "  ${YELLOW}curl -I http://localhost/BBTS${NC}"
        echo -e "  ${YELLOW}curl http://localhost/BBTS/api/layers | jq .${NC}"
    else
        echo -e "${RED}✗ Service failed to start${NC}"
        echo ""
        echo -e "${YELLOW}Check logs:${NC}"
        journalctl -u marbefes-bbt.service -n 30 --no-pager
        exit 1
    fi
else
    echo ""
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║   Import Test Failed                                       ║${NC}"
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo ""
    echo -e "${YELLOW}Check the error messages above${NC}"
    exit 1
fi
