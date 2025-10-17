#!/bin/bash
#
# Manual Deployment Steps - No backup creation (due to permissions)
# This script copies files directly and restarts the service
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "MARBEFES BBT - Manual Deployment"
echo "==========================================${NC}"
echo ""
echo -e "${YELLOW}This deployment includes:${NC}"
echo "  • Logo subpath fix"
echo "  • API subpath fix"
echo "  • WMS click query feature (NEW)"
echo ""

# Configuration
REMOTE_USER="razinka"
REMOTE_HOST="laguna.ku.lt"
REMOTE_APP_DIR="/var/www/marbefes-bbt"

echo -e "${BLUE}Step 1: Copying app.py${NC}"
scp app.py ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_APP_DIR}/
echo -e "${GREEN}✅ app.py copied${NC}"
echo ""

echo -e "${BLUE}Step 2: Copying templates/index.html${NC}"
scp templates/index.html ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_APP_DIR}/templates/
echo -e "${GREEN}✅ templates/index.html copied${NC}"
echo ""

echo -e "${BLUE}Step 3: Restarting service${NC}"
ssh ${REMOTE_USER}@${REMOTE_HOST} "sudo systemctl restart marbefes-bbt"
echo -e "${GREEN}✅ Service restarted${NC}"
echo ""

echo -e "${BLUE}Step 4: Checking service status${NC}"
ssh ${REMOTE_USER}@${REMOTE_HOST} "sudo systemctl is-active marbefes-bbt" && \
    echo -e "${GREEN}✅ Service is running${NC}" || \
    echo -e "${YELLOW}⚠️  Service status check failed${NC}"
echo ""

echo -e "${BLUE}Step 5: Verification${NC}"
echo -e "${YELLOW}Testing logo...${NC}"
LOGO_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://laguna.ku.lt/BBTS/logo/marbefes_02.png")
if [ "$LOGO_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ Logo accessible (HTTP $LOGO_STATUS)${NC}"
else
    echo -e "${YELLOW}⚠️  Logo returned HTTP $LOGO_STATUS${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "Deployment Complete!"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}Please verify:${NC}"
echo "  1. Open: http://laguna.ku.lt/BBTS"
echo "  2. Check logo appears in header"
echo "  3. Open browser console (F12)"
echo "  4. Verify no 404 errors"
echo "  5. Click on a WMS layer to test click query"
echo ""
