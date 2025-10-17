#!/bin/bash
#
# Apply Vector Layer ID Fix
# This script updates both frontend and backend to use source_file/layer_name format
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "======================================================================"
echo "           Vector Layer ID Fix - Complete (Nginx + Backend + Frontend)"
echo "======================================================================"
echo ""

SOURCE_DIR="/home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck"
DEPLOY_DIR="/var/www/marbefes-bbt"

# Step 0: Fix Nginx to allow encoded slashes
echo -e "${BLUE}→${NC} Configuring nginx to allow encoded slashes..."
if ! grep -q "merge_slashes off" /etc/nginx/nginx.conf; then
    sed -i '/http {/a \    merge_slashes off;' /etc/nginx/nginx.conf
    echo -e "${GREEN}✓${NC} Added 'merge_slashes off' to nginx.conf"

    # Test and reload nginx
    if nginx -t 2>&1 | grep -q "successful"; then
        systemctl reload nginx
        echo -e "${GREEN}✓${NC} Nginx reloaded"
    else
        echo "❌ Nginx configuration error"
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} Nginx already configured for encoded slashes"
fi
echo ""

# Step 1: Copy updated config (with APPLICATION_ROOT support)
echo -e "${BLUE}→${NC} Copying updated config to deployment..."
mkdir -p "$DEPLOY_DIR/config"
cp "$SOURCE_DIR/config/config.py" "$DEPLOY_DIR/config/"
if [ -f "$SOURCE_DIR/config/__init__.py" ]; then
    cp "$SOURCE_DIR/config/__init__.py" "$DEPLOY_DIR/config/"
fi
chown -R www-data:www-data "$DEPLOY_DIR/config"
echo -e "${GREEN}✓${NC} Config updated with APPLICATION_ROOT support"

# Step 1b: Verify app.py has API_BASE_URL support
echo ""
echo -e "${BLUE}→${NC} Verifying app.py has API_BASE_URL support..."
if grep -q "API_BASE_URL=api_base" "$DEPLOY_DIR/app.py"; then
    echo -e "${GREEN}✓${NC} app.py has API_BASE_URL support"
else
    echo "❌ app.py not updated - manual intervention needed"
    exit 1
fi

# Step 2: Copy updated vector_loader.py to deployment
echo ""
echo -e "${BLUE}→${NC} Copying updated vector_loader.py to deployment..."
mkdir -p "$DEPLOY_DIR/src/emodnet_viewer/utils"
cp "$SOURCE_DIR/src/emodnet_viewer/utils/vector_loader.py" "$DEPLOY_DIR/src/emodnet_viewer/utils/"

# Also copy __init__.py files if they exist
if [ -f "$SOURCE_DIR/src/emodnet_viewer/__init__.py" ]; then
    mkdir -p "$DEPLOY_DIR/src/emodnet_viewer"
    cp "$SOURCE_DIR/src/emodnet_viewer/__init__.py" "$DEPLOY_DIR/src/emodnet_viewer/"
fi

if [ -f "$SOURCE_DIR/src/emodnet_viewer/utils/__init__.py" ]; then
    cp "$SOURCE_DIR/src/emodnet_viewer/utils/__init__.py" "$DEPLOY_DIR/src/emodnet_viewer/utils/"
fi

# Set proper ownership
chown -R www-data:www-data "$DEPLOY_DIR/src"
echo -e "${GREEN}✓${NC} Backend files updated"

# Step 3: Verify frontend was already updated
echo ""
echo -e "${BLUE}→${NC} Verifying frontend updates..."
if grep -q "API_BASE_URL.*api/vector/layer" "$DEPLOY_DIR/templates/index.html"; then
    echo -e "${GREEN}✓${NC} Frontend updated to use API_BASE_URL"
else
    echo "❌ Frontend not updated with API_BASE_URL - index.html may need manual update"
    exit 1
fi

if grep -q "BBts.gpkg/Broad Belt Transects" "$DEPLOY_DIR/templates/index.html"; then
    echo -e "${GREEN}✓${NC} Frontend updated to use source_file/layer_name format"
else
    echo "❌ Frontend not updated - index.html may need manual update"
    exit 1
fi

# Step 4: Restart the service
echo ""
echo -e "${BLUE}→${NC} Restarting marbefes-bbt service..."
systemctl restart marbefes-bbt
sleep 3
echo -e "${GREEN}✓${NC} Service restarted"

# Step 5: Verify service is running
echo ""
echo -e "${BLUE}→${NC} Checking service status..."
if systemctl is-active --quiet marbefes-bbt; then
    echo -e "${GREEN}✓${NC} Service is running"
else
    echo "❌ Service failed to start"
    systemctl status marbefes-bbt --no-pager
    exit 1
fi

# Step 6: Test the API
echo ""
echo -e "${BLUE}→${NC} Testing vector layer API..."
sleep 2

# Test with correct layer ID
RESPONSE=$(curl -s "http://localhost/BBTS/api/vector/layer/BBts.gpkg/Broad%20Belt%20Transects")

if echo "$RESPONSE" | grep -q '"type":"FeatureCollection"'; then
    echo -e "${GREEN}✓${NC} Vector layer API working correctly!"
    FEATURE_COUNT=$(echo "$RESPONSE" | grep -o '"type":"Feature"' | wc -l)
    echo "  Found $FEATURE_COUNT features"
else
    echo "❌ API test failed"
    echo "Response: $RESPONSE"
    exit 1
fi

echo ""
echo "======================================================================"
echo -e "${GREEN}✅ Vector layer fix applied successfully!${NC}"
echo "======================================================================"
echo ""
echo "Next steps:"
echo "  1. Clear your browser cache (Ctrl+F5)"
echo "  2. Open http://laguna.ku.lt/BBTS"
echo "  3. Check browser console (F12) for:"
echo "     ✅ 'BBT features loaded successfully: 9 features'"
echo ""
echo "Test manually:"
echo "  curl 'http://localhost/BBTS/api/vector/layer/BBts.gpkg/Broad%20Belt%20Transects' | jq '.features | length'"
echo ""
