#!/bin/bash
#
# MARBEFES BBT Deployment Script
# Deploys all fixes to production server
#
# Environment variables (optional):
#   DEPLOY_USER       - SSH username (default: razinka)
#   DEPLOY_HOST       - Remote hostname (default: laguna.ku.lt)
#   DEPLOY_APP_DIR    - Remote app directory (default: /var/www/marbefes-bbt)
#   DEPLOY_LOCAL_DIR  - Local project directory (default: script directory)
#

echo "=========================================="
echo "MARBEFES BBT - Deployment to Production"
echo "=========================================="
echo ""
echo "This deployment includes:"
echo "  ✓ Logo subpath fix"
echo "  ✓ API subpath fix"
echo "  ✓ WMS click query feature"
echo "  ✓ EUNIS 2019 only (no biological zones)"
echo ""

# Configuration - Can be overridden by environment variables
REMOTE_USER="${DEPLOY_USER:-razinka}"
REMOTE_HOST="${DEPLOY_HOST:-laguna.ku.lt}"
REMOTE_APP_DIR="${DEPLOY_APP_DIR:-/var/www/marbefes-bbt}"
LOCAL_DIR="${DEPLOY_LOCAL_DIR:-$(cd "$(dirname "$0")" && pwd)}"

echo "Deployment Configuration:"
echo "  Remote: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_APP_DIR}"
echo "  Local:  ${LOCAL_DIR}"
echo ""

# Change to project directory
cd "$LOCAL_DIR" || {
    echo "ERROR: Cannot change to directory: $LOCAL_DIR"
    exit 1
}

echo "Step 1: Copying app.py to server..."
scp app.py ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_APP_DIR}/ || {
    echo "ERROR: Failed to copy app.py"
    exit 1
}
echo "✓ app.py copied"
echo ""

echo "Step 2: Copying templates/index.html to server..."
scp templates/index.html ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_APP_DIR}/templates/ || {
    echo "ERROR: Failed to copy templates/index.html"
    exit 1
}
echo "✓ templates/index.html copied"
echo ""

echo "Step 3: Restarting service..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "sudo systemctl restart marbefes-bbt" || {
    echo "ERROR: Failed to restart service"
    exit 1
}
echo "✓ Service restarted"
echo ""

echo "Step 4: Checking service status..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "sudo systemctl is-active marbefes-bbt" > /dev/null 2>&1 && {
    echo "✓ Service is running"
} || {
    echo "⚠ WARNING: Service may not be running"
    echo "Check status with: ssh ${REMOTE_USER}@${REMOTE_HOST} sudo systemctl status marbefes-bbt"
}
echo ""

echo "Step 5: Testing deployment..."
sleep 2

LOGO_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://laguna.ku.lt/BBTS/logo/marbefes_02.png" 2>/dev/null)
if [ "$LOGO_STATUS" = "200" ]; then
    echo "✓ Logo accessible (HTTP $LOGO_STATUS)"
else
    echo "⚠ Logo returned HTTP $LOGO_STATUS (expected 200)"
fi

API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://laguna.ku.lt/BBTS/api/vector/layer/BBts.gpkg/Broad%20Belt%20Transects" 2>/dev/null)
if [ "$API_STATUS" = "200" ]; then
    echo "✓ API accessible (HTTP $API_STATUS)"
else
    echo "⚠ API returned HTTP $API_STATUS (expected 200)"
fi

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Please verify in browser:"
echo "  1. Open: http://laguna.ku.lt/BBTS"
echo "  2. Check logo appears in header"
echo "  3. Open DevTools (F12) - verify no errors"
echo "  4. Test BBT navigation dropdown"
echo "  5. Click on EUNIS layer to query (NEW)"
echo ""
echo "The application now uses:"
echo "  • EUNIS 2019 full classification only"
echo "  • No biological zone layers"
echo "  • Click-to-query on all WMS layers"
echo ""
