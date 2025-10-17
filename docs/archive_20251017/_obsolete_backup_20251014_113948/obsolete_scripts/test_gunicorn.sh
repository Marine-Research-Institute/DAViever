#!/bin/bash
################################################################################
# Test Gunicorn Directly to See Real Error Messages
################################################################################

set -e

PROD_DIR="/var/www/marbefes-bbt"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Testing Gunicorn Directly                               ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""

echo -e "${BLUE}[1/5]${NC} Testing Python import..."
cd "$PROD_DIR"
sudo -u www-data "$PROD_DIR/venv/bin/python" << 'PYEOF'
import sys
sys.path.insert(0, '/var/www/marbefes-bbt')

print("Testing imports...")
try:
    import app
    print("✓ app.py imported successfully")
except Exception as e:
    print(f"✗ Failed to import app.py: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

try:
    import wsgi_subpath
    print("✓ wsgi_subpath.py imported successfully")
except Exception as e:
    print(f"✗ Failed to import wsgi_subpath.py: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

try:
    from wsgi_subpath import application
    print("✓ wsgi_subpath.application imported successfully")
    print(f"  Application type: {type(application)}")
except Exception as e:
    print(f"✗ Failed to import application: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

echo ""
echo -e "${BLUE}[2/5]${NC} Checking Gunicorn configuration..."
cat "$PROD_DIR/gunicorn_config.py"

echo ""
echo -e "${BLUE}[3/5]${NC} Testing Gunicorn config validation..."
sudo -u www-data "$PROD_DIR/venv/bin/gunicorn" --check-config --config "$PROD_DIR/gunicorn_config.py" wsgi_subpath:application 2>&1

echo ""
echo -e "${BLUE}[4/5]${NC} Running Gunicorn in foreground (will show actual errors)..."
echo -e "${YELLOW}Press Ctrl+C to stop when you see the error${NC}"
echo ""

cd "$PROD_DIR"
sudo -u www-data "$PROD_DIR/venv/bin/gunicorn" \
    --config "$PROD_DIR/gunicorn_config.py" \
    --bind 127.0.0.1:5000 \
    wsgi_subpath:application

