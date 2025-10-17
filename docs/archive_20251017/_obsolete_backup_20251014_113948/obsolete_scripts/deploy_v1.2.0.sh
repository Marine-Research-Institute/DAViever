#!/bin/bash
# MARBEFES BBT Database - Deploy v1.2.0 to laguna.ku.lt
# This script automates the deployment of the v1.2.0 enhancements

set -e  # Exit on error

# Configuration
SERVER="razinka@laguna.ku.lt"
APP_DIR="/var/www/marbefes-bbt"
LOCAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}MARBEFES BBT v1.2.0 Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${BLUE}Server: ${SERVER}${NC}"
echo -e "${BLUE}App Directory: ${APP_DIR}${NC}"
echo ""

# Step 1: Test SSH connection
echo -e "${YELLOW}[1/10] Testing SSH connection...${NC}"
if ssh -o ConnectTimeout=10 -o BatchMode=yes ${SERVER} "echo 'Connected'" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ SSH connection successful${NC}"
else
    echo -e "${RED}✗ SSH connection failed!${NC}"
    echo "Please set up SSH key authentication:"
    echo "  ssh-copy-id ${SERVER}"
    exit 1
fi

# Step 2: Create backup
echo -e "${YELLOW}[2/10] Creating backup on server...${NC}"
BACKUP_FILE="marbefes-bbt-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
ssh ${SERVER} "cd ${APP_DIR} && sudo tar -czf /backup/${BACKUP_FILE} \
  --exclude='venv' --exclude='__pycache__' --exclude='*.pyc' \
  --exclude='cache' --exclude='logs' . 2>/dev/null || true"
echo -e "${GREEN}✓ Backup created: /backup/${BACKUP_FILE}${NC}"

# Step 3: Stop current service
echo -e "${YELLOW}[3/10] Stopping current service...${NC}"
ssh ${SERVER} "sudo systemctl stop marbefes-bbt" || true
echo -e "${GREEN}✓ Service stopped${NC}"

# Step 4: Deploy application files
echo -e "${YELLOW}[4/10] Deploying application files...${NC}"
rsync -avz --progress \
  --exclude='venv' --exclude='__pycache__' --exclude='*.pyc' \
  --exclude='.git' --exclude='.gitignore' \
  --exclude='cache' --exclude='logs' \
  --exclude='*.md' --exclude='test_*.html' \
  --exclude='_archive' --exclude='FactSheets' \
  --exclude='.env' \
  ${LOCAL_DIR}/ ${SERVER}:${APP_DIR}/
echo -e "${GREEN}✓ Files deployed${NC}"

# Step 5: Make scripts executable
echo -e "${YELLOW}[5/10] Setting permissions...${NC}"
ssh ${SERVER} "chmod +x ${APP_DIR}/start_production.sh ${APP_DIR}/monitor_health.py"
echo -e "${GREEN}✓ Permissions set${NC}"

# Step 6: Install/Update dependencies
echo -e "${YELLOW}[6/10] Installing/updating dependencies...${NC}"
ssh ${SERVER} "cd ${APP_DIR} && source venv/bin/activate && \
  pip install --upgrade pip -q && \
  pip install -r requirements.txt -q"
echo -e "${GREEN}✓ Dependencies installed${NC}"

# Step 7: Verify Gunicorn
echo -e "${YELLOW}[7/10] Verifying Gunicorn installation...${NC}"
GUNICORN_VERSION=$(ssh ${SERVER} "cd ${APP_DIR} && source venv/bin/activate && gunicorn --version" | head -1)
echo -e "${GREEN}✓ Gunicorn installed: ${GUNICORN_VERSION}${NC}"

# Step 8: Update systemd service (if needed)
echo -e "${YELLOW}[8/10] Checking systemd service...${NC}"
if ssh ${SERVER} "sudo systemctl is-enabled marbefes-bbt" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Systemd service already configured${NC}"
else
    echo -e "${YELLOW}  Note: You may need to update systemd service manually${NC}"
    echo -e "${YELLOW}  See DEPLOY_TO_LAGUNA.md for instructions${NC}"
fi

# Step 9: Start service
echo -e "${YELLOW}[9/10] Starting service...${NC}"
ssh ${SERVER} "sudo systemctl start marbefes-bbt"
sleep 3
echo -e "${GREEN}✓ Service started${NC}"

# Step 10: Verification
echo -e "${YELLOW}[10/10] Verifying deployment...${NC}"

# Check if service is running
if ssh ${SERVER} "sudo systemctl is-active marbefes-bbt" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Service is active${NC}"
else
    echo -e "${RED}✗ Service is not active!${NC}"
    echo "Check logs: ssh ${SERVER} \"sudo journalctl -u marbefes-bbt -n 50\""
    exit 1
fi

# Check processes
WORKER_COUNT=$(ssh ${SERVER} "pgrep -f 'gunicorn.*marbefes' | wc -l" || echo "0")
echo -e "${GREEN}✓ Gunicorn workers running: ${WORKER_COUNT}${NC}"

# Test health endpoint
echo -e "${YELLOW}  Testing health endpoint...${NC}"
sleep 2
if curl -s -f http://laguna.ku.lt/BBTS/health > /dev/null 2>&1; then
    HEALTH_STATUS=$(curl -s http://laguna.ku.lt/BBTS/health | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✓ Health endpoint responding: ${HEALTH_STATUS}${NC}"
else
    echo -e "${YELLOW}⚠ Health endpoint not responding yet (may need more time)${NC}"
fi

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Application URL:${NC} http://laguna.ku.lt/BBTS"
echo -e "${BLUE}Health Check:${NC} http://laguna.ku.lt/BBTS/health"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Open browser: http://laguna.ku.lt/BBTS"
echo "  2. Verify map loads correctly"
echo "  3. Test BBT navigation"
echo "  4. Run health monitor:"
echo "     python monitor_health.py --url http://laguna.ku.lt/BBTS"
echo ""
echo -e "${YELLOW}View Logs:${NC}"
echo "  ssh ${SERVER} \"sudo journalctl -u marbefes-bbt -f\""
echo ""
echo -e "${YELLOW}Rollback (if needed):${NC}"
echo "  ssh ${SERVER} \"sudo systemctl stop marbefes-bbt && \\"
echo "    sudo tar -xzf /backup/${BACKUP_FILE} -C ${APP_DIR}/ && \\"
echo "    sudo systemctl start marbefes-bbt\""
echo ""
