#!/bin/bash
#
# Deploy BBT.gpkg Vector File to Production
# This script uploads the new BBT.gpkg file and restarts the service
#

set -e

echo "=========================================="
echo "Deploying BBT.gpkg Vector File"
echo "=========================================="
echo ""

# Configuration
REMOTE_USER="razinka"
REMOTE_HOST="laguna.ku.lt"
REMOTE_APP_DIR="/var/www/marbefes-bbt"
LOCAL_FILE="data/vector/BBT.gpkg"

# Step 1: Upload to home directory
echo "Step 1: Uploading BBT.gpkg to home directory..."
scp "$LOCAL_FILE" ${REMOTE_USER}@${REMOTE_HOST}:~/BBT.gpkg

if [ $? -eq 0 ]; then
    echo "✅ Upload successful"
else
    echo "❌ Upload failed"
    exit 1
fi

echo ""

# Step 2: Move to production directory and set permissions
echo "Step 2: Moving file to production and setting permissions..."
ssh ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
    # Remove old BBT files if they exist
    sudo rm -f /var/www/marbefes-bbt/data/vector/CheckedBBT.gpkg
    sudo rm -f /var/www/marbefes-bbt/data/vector/CheckedBBTs.gpkg

    # Move new BBT.gpkg file
    sudo mv ~/BBT.gpkg /var/www/marbefes-bbt/data/vector/

    # Set correct ownership
    sudo chown www-data:www-data /var/www/marbefes-bbt/data/vector/BBT.gpkg

    # Set correct permissions
    sudo chmod 644 /var/www/marbefes-bbt/data/vector/BBT.gpkg

    echo "✅ File moved and permissions set"

    # List vector files to confirm
    echo ""
    echo "Vector files in production:"
    ls -lh /var/www/marbefes-bbt/data/vector/*.gpkg
ENDSSH

if [ $? -eq 0 ]; then
    echo "✅ File deployment successful"
else
    echo "❌ File deployment failed"
    exit 1
fi

echo ""

# Step 3: Restart service
echo "Step 3: Restarting marbefes-bbt service..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "sudo systemctl restart marbefes-bbt"

if [ $? -eq 0 ]; then
    echo "✅ Service restarted successfully"
else
    echo "❌ Service restart failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Verification:"
echo "  curl http://laguna.ku.lt/BBTS/api/vector/layers | python3 -m json.tool"
echo ""
echo "Expected result:"
echo "  - 1 vector layer: 'Bbt - Bbt Areas'"
echo "  - 11 features"
echo "  - Source file: BBT.gpkg"
echo ""
