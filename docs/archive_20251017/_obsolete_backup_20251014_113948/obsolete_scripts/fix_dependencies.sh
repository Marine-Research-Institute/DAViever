#!/bin/bash
################################################################################
# Fix NumPy/Pandas Binary Incompatibility
#
# Reinstalls numpy and pandas with matching binary versions
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
echo -e "${BLUE}║   Fix NumPy/Pandas Binary Incompatibility                 ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Please run as root or with sudo${NC}"
    exit 1
fi

cd "$PROD_DIR"

echo -e "${BLUE}[1/5]${NC} Stopping service..."
systemctl stop marbefes-bbt.service 2>/dev/null || true
echo -e "${GREEN}✓${NC} Service stopped"

echo ""
echo -e "${BLUE}[2/5]${NC} Activating virtual environment..."
source "$PROD_DIR/venv/bin/activate"

echo ""
echo -e "${BLUE}[3/5]${NC} Current numpy/pandas versions:"
pip list | grep -E "(numpy|pandas)"

echo ""
echo -e "${BLUE}[4/5]${NC} Reinstalling numpy and pandas (forcing rebuild)..."
echo -e "${YELLOW}This may take a few minutes...${NC}"

# Uninstall problematic packages
pip uninstall -y numpy pandas 2>/dev/null || true

# Reinstall with no cache to force fresh compile
pip install --no-cache-dir numpy
pip install --no-cache-dir pandas

# Verify geopandas still works
pip install --no-cache-dir --upgrade geopandas

echo ""
echo -e "${BLUE}[5/5]${NC} New numpy/pandas versions:"
pip list | grep -E "(numpy|pandas|geopandas)"

deactivate

echo ""
echo -e "${GREEN}✓ Dependencies fixed!${NC}"
echo ""
echo -e "${BLUE}Testing Python imports...${NC}"

cd "$PROD_DIR"
sudo -u www-data "$PROD_DIR/venv/bin/python" << 'PYEOF'
import sys
sys.path.insert(0, '/var/www/marbefes-bbt')

try:
    print("  Testing numpy...")
    import numpy as np
    print(f"    ✓ numpy {np.__version__}")

    print("  Testing pandas...")
    import pandas as pd
    print(f"    ✓ pandas {pd.__version__}")

    print("  Testing geopandas...")
    import geopandas as gpd
    print(f"    ✓ geopandas {gpd.__version__}")

    print("  Testing app imports...")
    from wsgi_subpath import application
    print(f"    ✓ application loaded successfully")

    print("\n✓ All imports successful!")
except Exception as e:
    print(f"\n✗ Import failed: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   Dependencies Fixed Successfully!                         ║${NC}"
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo ""
    echo -e "${BLUE}Now start the service:${NC}"
    echo -e "  ${YELLOW}sudo systemctl start marbefes-bbt${NC}"
    echo -e "  ${YELLOW}sudo systemctl status marbefes-bbt${NC}"
else
    echo ""
    echo -e "${RED}✗ Import test failed${NC}"
    echo -e "${YELLOW}Check the error above for details${NC}"
    exit 1
fi
