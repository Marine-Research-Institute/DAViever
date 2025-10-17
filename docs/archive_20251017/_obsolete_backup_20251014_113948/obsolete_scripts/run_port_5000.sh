#!/bin/bash
# Quick deployment to laguna.ku.lt on port 5000
# This script deploys and runs the application directly on port 5000

set -e

SERVER="razinka@laguna.ku.lt"
APP_DIR="/var/www/marbefes-bbt"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}MARBEFES BBT - Deploy to Port 5000${NC}"
echo -e "${GREEN}========================================${NC}"

# 1. Test connection
echo -e "${YELLOW}[1/6] Testing SSH connection...${NC}"
ssh ${SERVER} "echo 'Connected'" || exit 1
echo -e "${GREEN}✓ Connected${NC}"

# 2. Stop existing processes on port 5000
echo -e "${YELLOW}[2/6] Stopping any existing processes on port 5000...${NC}"
ssh ${SERVER} "sudo pkill -f 'gunicorn.*app:app' || true"
ssh ${SERVER} "sudo pkill -f 'python.*app.py' || true"
sleep 2
echo -e "${GREEN}✓ Stopped${NC}"

# 3. Deploy files
echo -e "${YELLOW}[3/6] Deploying files...${NC}"
rsync -avz --progress \
  --exclude='venv' --exclude='__pycache__' --exclude='*.pyc' \
  --exclude='.git' --exclude='cache' --exclude='logs' \
  --exclude='*.md' --exclude='test_*.html' --exclude='_archive' \
  --exclude='FactSheets' --exclude='.env' \
  ./ ${SERVER}:${APP_DIR}/
echo -e "${GREEN}✓ Files deployed${NC}"

# 4. Install dependencies
echo -e "${YELLOW}[4/6] Installing dependencies...${NC}"
ssh ${SERVER} "cd ${APP_DIR} && \
  source venv/bin/activate && \
  pip install -q -r requirements.txt"
echo -e "${GREEN}✓ Dependencies installed${NC}"

# 5. Start application on port 5000
echo -e "${YELLOW}[5/6] Starting application on port 5000...${NC}"
ssh ${SERVER} "cd ${APP_DIR} && \
  nohup venv/bin/gunicorn -c gunicorn_config.py app:app \
  > logs/gunicorn.log 2>&1 &"
sleep 3
echo -e "${GREEN}✓ Application started${NC}"

# 6. Verify
echo -e "${YELLOW}[6/6] Verifying deployment...${NC}"

# Check if process is running
if ssh ${SERVER} "pgrep -f 'gunicorn.*app:app' > /dev/null"; then
    WORKER_COUNT=$(ssh ${SERVER} "pgrep -f 'gunicorn.*app:app' | wc -l")
    echo -e "${GREEN}✓ Gunicorn running with ${WORKER_COUNT} workers${NC}"
else
    echo -e "${YELLOW}⚠ Gunicorn not detected (may still be starting)${NC}"
fi

# Test endpoint
sleep 2
if curl -s -f http://laguna.ku.lt:5000/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Health endpoint responding on port 5000${NC}"
else
    echo -e "${YELLOW}⚠ Health endpoint not responding yet${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Application URL:${NC} http://laguna.ku.lt:5000"
echo -e "${BLUE}Health Check:${NC} http://laguna.ku.lt:5000/health"
echo -e "${BLUE}API Layers:${NC} http://laguna.ku.lt:5000/api/layers"
echo ""
echo -e "${YELLOW}View Logs:${NC}"
echo "  ssh ${SERVER} 'tail -f ${APP_DIR}/logs/gunicorn.log'"
echo ""
echo -e "${YELLOW}Check Processes:${NC}"
echo "  ssh ${SERVER} 'pgrep -a gunicorn'"
echo ""
echo -e "${YELLOW}Stop Application:${NC}"
echo "  ssh ${SERVER} 'pkill -f gunicorn.*app:app'"
echo ""
