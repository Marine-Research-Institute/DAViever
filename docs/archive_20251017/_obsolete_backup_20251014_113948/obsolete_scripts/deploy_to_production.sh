#!/bin/bash
# Deploy MARBEFES BBT Database to production
# This script should be run with sudo privileges

set -e

PROD_DIR="/var/www/marbefes-bbt"
echo "🚀 Deploying MARBEFES BBT Database to production..."

# Fix ownership
echo "📁 Fixing file permissions..."
chown -R www-data:www-data "$PROD_DIR"

# Install/update dependencies
echo "📦 Installing dependencies..."
cd "$PROD_DIR"
sudo -u www-data "$PROD_DIR/venv/bin/pip" install -q -r requirements.txt

# Create logs directory if it doesn't exist
echo "📝 Setting up logs directory..."
mkdir -p "$PROD_DIR/logs"
chown www-data:www-data "$PROD_DIR/logs"

# Test the application
echo "🧪 Testing application imports..."
sudo -u www-data "$PROD_DIR/venv/bin/python" -c "import app; print('✅ App imports successfully')"

# Restart the service
echo "🔄 Restarting marbefes-bbt service..."
systemctl restart marbefes-bbt

# Wait a moment for startup
sleep 2

# Check service status
echo "📊 Service status:"
systemctl status marbefes-bbt --no-pager -l

echo ""
echo "✅ Deployment complete!"
echo "🌐 Application should be accessible at: http://laguna.ku.lt/BBTS"
