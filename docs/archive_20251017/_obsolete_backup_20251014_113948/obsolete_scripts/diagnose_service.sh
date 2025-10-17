#!/bin/bash
################################################################################
# MARBEFES BBT Service Diagnostic Script
#
# Run this to diagnose why the service failed to start
################################################################################

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROD_DIR="/var/www/marbefes-bbt"
SERVICE_NAME="marbefes-bbt"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   MARBEFES BBT Service Diagnostics                        ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}1. Service Status${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
systemctl status ${SERVICE_NAME}.service --no-pager -l

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}2. Recent Service Logs (Last 50 lines)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
journalctl -u ${SERVICE_NAME}.service -n 50 --no-pager

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}3. File Permissions Check${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}Application directory:${NC}"
ls -ld "$PROD_DIR"

echo ""
echo -e "${YELLOW}Python files:${NC}"
ls -l "$PROD_DIR"/*.py 2>/dev/null | head -10

echo ""
echo -e "${YELLOW}Virtual environment:${NC}"
ls -ld "$PROD_DIR/venv" 2>/dev/null || echo "venv not found"

echo ""
echo -e "${YELLOW}wsgi_subpath.py:${NC}"
ls -l "$PROD_DIR/wsgi_subpath.py" 2>/dev/null || echo "wsgi_subpath.py not found"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}4. Test Gunicorn Directly${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}Testing if Gunicorn can load the application...${NC}"
cd "$PROD_DIR"
sudo -u www-data "$PROD_DIR/venv/bin/gunicorn" --check-config --config "$PROD_DIR/gunicorn_config.py" wsgi_subpath:application 2>&1 || true

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}5. Test Python Import${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}Testing if Python can import the application...${NC}"
cd "$PROD_DIR"
sudo -u www-data "$PROD_DIR/venv/bin/python" -c "
import sys
sys.path.insert(0, '$PROD_DIR')
try:
    from wsgi_subpath import application
    print('✓ Successfully imported wsgi_subpath.application')
except Exception as e:
    print(f'✗ Failed to import: {e}')
    import traceback
    traceback.print_exc()
" 2>&1

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}6. Check Dependencies${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}Checking if required packages are installed...${NC}"
cd "$PROD_DIR"
"$PROD_DIR/venv/bin/pip" list | grep -E "(Flask|gunicorn|werkzeug|requests)"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}7. Environment File Check${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if [ -f "$PROD_DIR/.env" ]; then
    echo -e "${GREEN}✓ .env file exists${NC}"
    echo -e "${YELLOW}Contents (without secrets):${NC}"
    grep -v "SECRET_KEY" "$PROD_DIR/.env" | head -15
else
    echo -e "${RED}✗ .env file missing${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}8. Port Check${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}Checking if port 5000 is already in use...${NC}"
if lsof -i :5000 2>/dev/null; then
    echo -e "${RED}✗ Port 5000 is already in use!${NC}"
else
    echo -e "${GREEN}✓ Port 5000 is available${NC}"
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Diagnostic Summary                                       ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""
echo -e "${YELLOW}Common Issues and Solutions:${NC}"
echo ""
echo -e "${BLUE}1. Import Error (ModuleNotFoundError)${NC}"
echo -e "   Solution: Check Python path and installed packages"
echo -e "   Command: cd $PROD_DIR && source venv/bin/activate && pip list"
echo ""
echo -e "${BLUE}2. Permission Denied${NC}"
echo -e "   Solution: Fix ownership"
echo -e "   Command: sudo chown -R www-data:www-data $PROD_DIR"
echo ""
echo -e "${BLUE}3. Port Already in Use${NC}"
echo -e "   Solution: Kill process using port 5000"
echo -e "   Command: sudo lsof -i :5000 | grep LISTEN | awk '{print \$2}' | xargs sudo kill"
echo ""
echo -e "${BLUE}4. Missing wsgi_subpath.py${NC}"
echo -e "   Solution: Create the file"
echo -e "   The deployment script should have created it automatically"
echo ""
echo -e "${BLUE}5. Gunicorn Type Error${NC}"
echo -e "   Solution: Change service type from 'notify' to 'simple'"
echo -e "   Edit: /etc/systemd/system/marbefes-bbt.service"
echo -e "   Change: Type=notify → Type=simple"
echo ""
