#!/bin/bash
################################################################################
# Add /BBTS location to existing nginx default config
################################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Add /BBTS to Nginx Default Config                       ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Please run as root or with sudo${NC}"
    exit 1
fi

CONFIG_FILE="/etc/nginx/sites-available/default"

echo -e "${BLUE}[1/4]${NC} Backing up nginx config..."
cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${GREEN}✓${NC} Backup created"

echo ""
echo -e "${BLUE}[2/4]${NC} Checking if /BBTS location already exists..."
if grep -q "location /BBTS" "$CONFIG_FILE"; then
    echo -e "${YELLOW}⚠${NC} /BBTS location already exists in config"
    echo -e "${YELLOW}  Skipping addition${NC}"
else
    echo -e "${BLUE}→${NC} Adding /BBTS location block..."

    # Find the line with "location /flask" and add after its closing brace
    awk '
    /location \/flask/,/^[[:space:]]*\}/ {
        print
        if (/^[[:space:]]*\}/ && !added) {
            print ""
            print "\t# MARBEFES BBT Database"
            print "\tlocation /BBTS {"
            print "\t\tproxy_pass http://127.0.0.1:5000/BBTS;"
            print "\t\tproxy_set_header Host $host;"
            print "\t\tproxy_set_header X-Real-IP $remote_addr;"
            print "\t\tproxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;"
            print "\t\tproxy_set_header X-Forwarded-Proto $scheme;"
            print ""
            print "\t\tproxy_http_version 1.1;"
            print "\t\tproxy_set_header Upgrade $http_upgrade;"
            print "\t\tproxy_set_header Connection \"upgrade\";"
            print ""
            print "\t\tproxy_connect_timeout 120s;"
            print "\t\tproxy_send_timeout 120s;"
            print "\t\tproxy_read_timeout 120s;"
            print "\t}"
            added = 1
        }
        next
    }
    { print }
    ' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"

    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo -e "${GREEN}✓${NC} /BBTS location added"
fi

echo ""
echo -e "${BLUE}[3/4]${NC} Testing nginx configuration..."
if nginx -t 2>&1 | grep -q "syntax is ok"; then
    echo -e "${GREEN}✓${NC} Configuration is valid"
else
    echo -e "${RED}✗${NC} Configuration has errors:"
    nginx -t
    echo ""
    echo -e "${YELLOW}Restoring backup...${NC}"
    cp "${CONFIG_FILE}.backup."* "$CONFIG_FILE"
    exit 1
fi

echo ""
echo -e "${BLUE}[4/4]${NC} Reloading nginx..."
systemctl reload nginx
echo -e "${GREEN}✓${NC} Nginx reloaded"

sleep 2

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   /BBTS Added Successfully!                                ║${NC}"
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""

echo -e "${BLUE}Testing access...${NC}"
if curl -sf -I http://localhost/BBTS > /dev/null 2>&1; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/BBTS)
    echo -e "${GREEN}✓${NC} http://localhost/BBTS - HTTP $HTTP_CODE"
else
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/BBTS)
    echo -e "${YELLOW}⚠${NC} http://localhost/BBTS - HTTP $HTTP_CODE"
fi

echo ""
echo -e "${BLUE}Access URLs:${NC}"
echo -e "  ${YELLOW}http://localhost/BBTS${NC}"
echo -e "  ${YELLOW}http://laguna.ku.lt/BBTS${NC}"
echo ""
