#!/bin/bash
# Deploy logo path fix to production server

set -e  # Exit on any error

echo "=========================================="
echo "Deploying Logo Path Fix"
echo "=========================================="

# Configuration
REMOTE_USER="razinka"
REMOTE_HOST="laguna.ku.lt"
REMOTE_APP_DIR="/var/www/marbefes-bbt"
SERVICE_NAME="marbefes-bbt"

echo ""
echo "1. Backing up current files on remote server..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "
    cd ${REMOTE_APP_DIR}
    # Create backup with timestamp
    BACKUP_DIR=backups/logo_fix_\$(date +%Y%m%d_%H%M%S)
    mkdir -p \$BACKUP_DIR
    cp app.py \$BACKUP_DIR/
    cp templates/index.html \$BACKUP_DIR/
    echo 'Backup created in \$BACKUP_DIR'
"

echo ""
echo "2. Copying updated files to remote server..."
scp app.py ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_APP_DIR}/
scp templates/index.html ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_APP_DIR}/templates/

echo ""
echo "3. Restarting service..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "
    sudo systemctl restart ${SERVICE_NAME}
    sleep 2
    sudo systemctl status ${SERVICE_NAME} --no-pager
"

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "The logo should now be visible at: http://laguna.ku.lt/BBTS"
echo ""
echo "To verify the fix:"
echo "  curl -I http://laguna.ku.lt/BBTS/logo/marbefes_02.png"
echo ""
echo "To rollback if needed:"
echo "  ssh ${REMOTE_USER}@${REMOTE_HOST}"
echo "  cd ${REMOTE_APP_DIR}"
echo "  # Find the latest backup directory and restore files"
echo ""
