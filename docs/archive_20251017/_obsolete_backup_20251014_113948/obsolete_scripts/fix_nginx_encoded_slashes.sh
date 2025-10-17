#!/bin/bash
#
# Fix Nginx to Handle Encoded Slashes in URLs
# This fixes the 404 errors for vector layer API calls with encoded slashes
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================================================"
echo "           Fix Nginx for Encoded Slashes in Vector Layer URLs"
echo "======================================================================"
echo ""

NGINX_CONFIG="/etc/nginx/sites-available/default"
BACKUP_FILE="${NGINX_CONFIG}.backup.encoded_slash_fix.$(date +%Y%m%d_%H%M%S)"

# Backup the current config
echo -e "${BLUE}→${NC} Creating backup of nginx config..."
cp "$NGINX_CONFIG" "$BACKUP_FILE"
echo -e "${GREEN}✓${NC} Backup created: $BACKUP_FILE"

# Create the updated BBTS location block
echo ""
echo -e "${BLUE}→${NC} Updating /BBTS location block..."

# Use awk to replace the /BBTS location block
awk '
/^[[:space:]]*# MARBEFES BBT Database/ {
    print "	# MARBEFES BBT Database"
    print "	location /BBTS {"
    print "		# Allow encoded slashes in URLs (needed for vector layer IDs like \"BBts.gpkg/layer\")"
    print "		rewrite ^ $request_uri;"
    print "		rewrite ^/BBTS(/.*) $1 break;"
    print "		"
    print "		proxy_pass http://127.0.0.1:5000/BBTS$uri$is_args$args;"
    print "		proxy_set_header Host $host;"
    print "		proxy_set_header X-Real-IP $remote_addr;"
    print "		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;"
    print "		proxy_set_header X-Forwarded-Proto $scheme;"
    print ""
    print "		proxy_http_version 1.1;"
    print "		proxy_set_header Upgrade $http_upgrade;"
    print "		proxy_set_header Connection \"upgrade\";"
    print ""
    print "		proxy_connect_timeout 120s;"
    print "		proxy_send_timeout 120s;"
    print "		proxy_read_timeout 120s;"
    print "	}"
    # Skip until we find the closing brace
    in_block = 1
    next
}

in_block && /^[[:space:]]*}[[:space:]]*$/ {
    in_block = 0
    next
}

!in_block { print }
' "$NGINX_CONFIG" > "${NGINX_CONFIG}.tmp"

# Also need to add merge_slashes directive at http level
echo ""
echo -e "${BLUE}→${NC} Checking for merge_slashes directive..."

if grep -q "merge_slashes" "$NGINX_CONFIG"; then
    echo -e "${YELLOW}⚠${NC} merge_slashes already configured"
else
    echo -e "${BLUE}→${NC} Adding merge_slashes off to nginx.conf..."
    # This needs to be in the main nginx.conf, not site config
    if ! grep -q "merge_slashes" /etc/nginx/nginx.conf; then
        sed -i '/http {/a \    merge_slashes off;  # Allow encoded slashes in URLs' /etc/nginx/nginx.conf
        echo -e "${GREEN}✓${NC} Added merge_slashes off to nginx.conf"
    fi
fi

# Move temp file to actual config
mv "${NGINX_CONFIG}.tmp" "$NGINX_CONFIG"
echo -e "${GREEN}✓${NC} Nginx config updated"

# Test nginx configuration
echo ""
echo -e "${BLUE}→${NC} Testing nginx configuration..."
if nginx -t 2>&1 | grep -q "successful"; then
    echo -e "${GREEN}✓${NC} Nginx configuration is valid"
else
    echo "❌ Nginx configuration test failed!"
    echo "Restoring backup..."
    cp "$BACKUP_FILE" "$NGINX_CONFIG"
    exit 1
fi

# Reload nginx
echo ""
echo -e "${BLUE}→${NC} Reloading nginx..."
systemctl reload nginx
echo -e "${GREEN}✓${NC} Nginx reloaded"

# Test the API
echo ""
echo -e "${BLUE}→${NC} Testing vector layer API..."
sleep 2

RESPONSE=$(curl -s "http://localhost/BBTS/api/vector/layer/BBts.gpkg/Broad%20Belt%20Transects")

if echo "$RESPONSE" | grep -q '"type":"FeatureCollection"'; then
    echo -e "${GREEN}✓${NC} Vector layer API working correctly!"
    FEATURE_COUNT=$(echo "$RESPONSE" | grep -o '"type":"Feature"' | wc -l)
    echo "  Found $FEATURE_COUNT features"
elif echo "$RESPONSE" | grep -q "404"; then
    echo -e "${YELLOW}⚠${NC} Still getting 404 - may need Flask app restart"
    echo "  Run: sudo systemctl restart marbefes-bbt"
else
    echo "Response: $RESPONSE" | head -5
fi

echo ""
echo "======================================================================"
echo -e "${GREEN}✅ Nginx configuration updated!${NC}"
echo "======================================================================"
echo ""
echo "If still getting 404, run the full fix:"
echo "  sudo /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/apply_vector_fix.sh"
echo ""
