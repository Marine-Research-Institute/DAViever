#!/bin/bash
################################################################################
# Update Vector Data in Production
# This script updates the BBT.gpkg file in production and restarts the service
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Updating Vector Data in Production${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo ""

# Configuration
SOURCE_GPKG="data/vector/BBT.gpkg"
PROD_DIR="/var/www/marbefes-bbt"
PROD_GPKG="$PROD_DIR/data/vector/BBT.gpkg"
SERVICE_NAME="marbefes-bbt"

# Check if source file exists
if [ ! -f "$SOURCE_GPKG" ]; then
    echo -e "${RED}✗ Source file not found: $SOURCE_GPKG${NC}"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}⚠ This script requires sudo privileges${NC}"
    echo -e "${BLUE}→ Re-running with sudo...${NC}"
    exec sudo bash "$0" "$@"
fi

echo -e "${BLUE}[1/4]${NC} Backing up current production GPKG..."
if [ -f "$PROD_GPKG" ]; then
    BACKUP_FILE="$PROD_GPKG.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$PROD_GPKG" "$BACKUP_FILE"
    echo -e "${GREEN}✓${NC} Backup created: $BACKUP_FILE"
else
    echo -e "${YELLOW}⚠${NC} No existing file to backup"
fi

echo -e "\n${BLUE}[2/4]${NC} Copying new GPKG to production..."
cp "$SOURCE_GPKG" "$PROD_GPKG"
chown www-data:www-data "$PROD_GPKG"
chmod 644 "$PROD_GPKG"
echo -e "${GREEN}✓${NC} File copied and permissions set"

echo -e "\n${BLUE}[3/4]${NC} Verifying GPKG file..."
# Show file info
echo -e "  Size: $(du -h "$PROD_GPKG" | cut -f1)"
echo -e "  Modified: $(stat -c %y "$PROD_GPKG" | cut -d. -f1)"

# Check layers using Python
python3 << EOF
import fiona
try:
    layers = fiona.listlayers("$PROD_GPKG")
    print(f"  Layers: {len(layers)}")
    for layer in layers:
        with fiona.open("$PROD_GPKG", layer=layer) as src:
            print(f"    - {layer}: {len(src)} features")
except Exception as e:
    print(f"  Error reading GPKG: {e}")
    exit(1)
EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ GPKG file validation failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} GPKG file is valid"

echo -e "\n${BLUE}[4/4]${NC} Restarting service..."
systemctl restart "$SERVICE_NAME"

# Wait for service to start
sleep 2

# Check service status
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo -e "${GREEN}✓${NC} Service restarted successfully"
else
    echo -e "${RED}✗ Service failed to start${NC}"
    systemctl status "$SERVICE_NAME" --no-pager -l
    exit 1
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Vector Data Updated Successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Verification:${NC}"
echo -e "  Production URL: ${YELLOW}http://laguna.ku.lt/BBTS/${NC}"
echo ""
echo -e "${BLUE}Test commands:${NC}"
echo -e "  ${YELLOW}curl http://laguna.ku.lt/BBTS/api/vector/layers${NC}"
echo -e "  ${YELLOW}sudo journalctl -u $SERVICE_NAME -f${NC}"
echo ""
