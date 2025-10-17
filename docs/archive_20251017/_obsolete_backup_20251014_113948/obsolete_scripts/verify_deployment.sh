#!/bin/bash
################################################################################
# MARBEFES BBT Database - Post-Deployment Verification Script
#
# This script verifies that the production deployment is working correctly
################################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROD_DIR="/var/www/marbefes-bbt"
SERVICE_NAME="marbefes-bbt"
NGINX_SITE="marbefes-bbt"
TEST_URL="http://localhost"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   MARBEFES BBT Database - Deployment Verification         ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"

    echo -ne "${BLUE}[TEST]${NC} ${test_name}... "

    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test function with output
run_test_with_output() {
    local test_name="$1"
    local test_command="$2"

    echo -e "${BLUE}[TEST]${NC} ${test_name}"

    if eval "$test_command"; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}1. File System Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

run_test "Production directory exists" "[ -d '$PROD_DIR' ]"
run_test "app.py exists" "[ -f '$PROD_DIR/app.py' ]"
run_test "Virtual environment exists" "[ -d '$PROD_DIR/venv' ]"
run_test ".env file exists" "[ -f '$PROD_DIR/.env' ]"
run_test "gunicorn_config.py exists" "[ -f '$PROD_DIR/gunicorn_config.py' ]"
run_test "logs directory exists" "[ -d '$PROD_DIR/logs' ]"
run_test "Vector data directory exists" "[ -d '$PROD_DIR/data/vector' ]"

# Check for vector data files
if [ -n "$(ls -A $PROD_DIR/data/vector/*.gpkg 2>/dev/null)" ]; then
    echo -e "${BLUE}[TEST]${NC} Vector GPKG files exist... ${GREEN}✓ PASS${NC}"
    echo -e "       ${YELLOW}$(ls -1 $PROD_DIR/data/vector/*.gpkg | wc -l) GPKG files found${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${BLUE}[TEST]${NC} Vector GPKG files exist... ${YELLOW}⚠ WARNING${NC}"
    echo -e "       ${YELLOW}No GPKG files found in data/vector/${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}2. Permissions Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

run_test "Production directory owned by www-data" "[ \$(stat -c '%U' '$PROD_DIR') = 'www-data' ]"
run_test "logs directory is writable" "[ -w '$PROD_DIR/logs' ]"
run_test ".env file has correct permissions" "[ \$(stat -c '%a' '$PROD_DIR/.env') = '644' ]"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}3. Systemd Service Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

run_test "Systemd service file exists" "[ -f '/etc/systemd/system/${SERVICE_NAME}.service' ]"
run_test "Service is enabled" "systemctl is-enabled ${SERVICE_NAME}"
run_test "Service is active" "systemctl is-active ${SERVICE_NAME}"

if systemctl is-active ${SERVICE_NAME} > /dev/null 2>&1; then
    echo -e "${BLUE}[INFO]${NC} Service status:"
    systemctl status ${SERVICE_NAME} --no-pager -l | head -10 | sed 's/^/       /'
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}4. Nginx Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

run_test "Nginx configuration exists" "[ -f '/etc/nginx/sites-available/${NGINX_SITE}' ]"
run_test "Nginx site is enabled" "[ -L '/etc/nginx/sites-enabled/${NGINX_SITE}' ]"
run_test "Nginx configuration is valid" "nginx -t"
run_test "Nginx is running" "systemctl is-active nginx"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}5. Application HTTP Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Test main page
if curl -sf -o /dev/null "$TEST_URL"; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TEST_URL")
    echo -e "${BLUE}[TEST]${NC} Main page accessible... ${GREEN}✓ PASS${NC} (HTTP $HTTP_CODE)"
    ((TESTS_PASSED++))
else
    echo -e "${BLUE}[TEST]${NC} Main page accessible... ${RED}✗ FAIL${NC}"
    ((TESTS_FAILED++))
fi

# Test API endpoints
ENDPOINTS=(
    "/api/layers"
    "/api/all-layers"
    "/api/vector/layers"
    "/api/capabilities"
)

for endpoint in "${ENDPOINTS[@]}"; do
    if curl -sf -o /dev/null "$TEST_URL$endpoint"; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TEST_URL$endpoint")
        echo -e "${BLUE}[TEST]${NC} $endpoint accessible... ${GREEN}✓ PASS${NC} (HTTP $HTTP_CODE)"
        ((TESTS_PASSED++))
    else
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TEST_URL$endpoint")
        echo -e "${BLUE}[TEST]${NC} $endpoint accessible... ${RED}✗ FAIL${NC} (HTTP $HTTP_CODE)"
        ((TESTS_FAILED++))
    fi
done

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}6. Performance Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Response time test
RESPONSE_TIME=$(curl -o /dev/null -s -w '%{time_total}' "$TEST_URL/api/layers")
RESPONSE_TIME_MS=$(echo "$RESPONSE_TIME * 1000" | bc)

echo -e "${BLUE}[TEST]${NC} API response time: ${YELLOW}${RESPONSE_TIME_MS}ms${NC}"

if [ $(echo "$RESPONSE_TIME < 2.0" | bc) -eq 1 ]; then
    echo -e "       ${GREEN}✓ Response time is good (< 2000ms)${NC}"
    ((TESTS_PASSED++))
else
    echo -e "       ${YELLOW}⚠ Response time is slow (> 2000ms)${NC}"
    ((TESTS_FAILED++))
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}7. Python Dependencies Test${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Test Python packages
cd "$PROD_DIR"
source venv/bin/activate

REQUIRED_PACKAGES=(
    "flask"
    "gunicorn"
    "requests"
    "geopandas"
    "fiona"
    "pyproj"
)

for package in "${REQUIRED_PACKAGES[@]}"; do
    if python -c "import $package" 2>/dev/null; then
        VERSION=$(python -c "import $package; print($package.__version__)" 2>/dev/null || echo "unknown")
        echo -e "${BLUE}[TEST]${NC} Python package '$package' installed... ${GREEN}✓ PASS${NC} (v$VERSION)"
        ((TESTS_PASSED++))
    else
        echo -e "${BLUE}[TEST]${NC} Python package '$package' installed... ${RED}✗ FAIL${NC}"
        ((TESTS_FAILED++))
    fi
done

deactivate

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}8. Log Files Test${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Check for error patterns in logs
if journalctl -u ${SERVICE_NAME} --since "5 minutes ago" | grep -i "error" > /dev/null; then
    echo -e "${BLUE}[TEST]${NC} Check for errors in service logs... ${YELLOW}⚠ WARNINGS FOUND${NC}"
    echo -e "       ${YELLOW}Recent errors in systemd journal:${NC}"
    journalctl -u ${SERVICE_NAME} --since "5 minutes ago" | grep -i "error" | tail -3 | sed 's/^/       /'
else
    echo -e "${BLUE}[TEST]${NC} Check for errors in service logs... ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
fi

# Check nginx logs
if [ -f /var/log/nginx/marbefes-bbt-error.log ]; then
    ERROR_COUNT=$(wc -l < /var/log/nginx/marbefes-bbt-error.log)
    if [ "$ERROR_COUNT" -eq 0 ]; then
        echo -e "${BLUE}[TEST]${NC} Nginx error log empty... ${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${BLUE}[TEST]${NC} Nginx error log empty... ${YELLOW}⚠ $ERROR_COUNT errors found${NC}"
    fi
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}9. Network Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Check if port 5000 is listening
if ss -tunlp | grep ":5000" > /dev/null; then
    echo -e "${BLUE}[TEST]${NC} Gunicorn listening on port 5000... ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${BLUE}[TEST]${NC} Gunicorn listening on port 5000... ${RED}✗ FAIL${NC}"
    ((TESTS_FAILED++))
fi

# Check nginx ports
for port in 80 443; do
    if ss -tunlp | grep ":$port" > /dev/null; then
        echo -e "${BLUE}[TEST]${NC} Nginx listening on port $port... ${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
    else
        if [ "$port" -eq 443 ]; then
            echo -e "${BLUE}[TEST]${NC} Nginx listening on port $port... ${YELLOW}⚠ Not configured (SSL not setup)${NC}"
        else
            echo -e "${BLUE}[TEST]${NC} Nginx listening on port $port... ${RED}✗ FAIL${NC}"
            ((TESTS_FAILED++))
        fi
    fi
done

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}10. Security Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Test security headers
HEADERS=$(curl -sI "$TEST_URL" | grep -E "(X-Frame-Options|X-Content-Type-Options|X-XSS-Protection)")

if echo "$HEADERS" | grep -q "X-Frame-Options"; then
    echo -e "${BLUE}[TEST]${NC} X-Frame-Options header present... ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${BLUE}[TEST]${NC} X-Frame-Options header present... ${RED}✗ FAIL${NC}"
    ((TESTS_FAILED++))
fi

if echo "$HEADERS" | grep -q "X-Content-Type-Options"; then
    echo -e "${BLUE}[TEST]${NC} X-Content-Type-Options header present... ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${BLUE}[TEST]${NC} X-Content-Type-Options header present... ${RED}✗ FAIL${NC}"
    ((TESTS_FAILED++))
fi

# Check if debug mode is disabled
if grep -q "FLASK_DEBUG=False" "$PROD_DIR/.env"; then
    echo -e "${BLUE}[TEST]${NC} Debug mode disabled... ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${BLUE}[TEST]${NC} Debug mode disabled... ${RED}✗ FAIL - DEBUG IS ENABLED!${NC}"
    ((TESTS_FAILED++))
fi

################################################################################
# Summary
################################################################################

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Test Summary                            ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
PASS_RATE=$(echo "scale=1; $TESTS_PASSED * 100 / $TOTAL_TESTS" | bc)

echo -e "  Total Tests:    ${BLUE}${TOTAL_TESTS}${NC}"
echo -e "  Tests Passed:   ${GREEN}${TESTS_PASSED}${NC}"
echo -e "  Tests Failed:   ${RED}${TESTS_FAILED}${NC}"
echo -e "  Pass Rate:      ${YELLOW}${PASS_RATE}%${NC}"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       ✓ ALL TESTS PASSED - DEPLOYMENT SUCCESSFUL!         ║${NC}"
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo ""
    echo -e "${BLUE}Application is ready for production use!${NC}"
    echo ""
    echo -e "${BLUE}Access your application at:${NC}"
    echo -e "  Local:    ${YELLOW}http://localhost${NC}"
    echo -e "  Network:  ${YELLOW}http://$(hostname -I | awk '{print $1}')${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║     ✗ SOME TESTS FAILED - REVIEW ISSUES ABOVE             ║${NC}"
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting commands:${NC}"
    echo -e "  Service logs:   ${BLUE}sudo journalctl -u ${SERVICE_NAME} -f${NC}"
    echo -e "  Nginx logs:     ${BLUE}sudo tail -f /var/log/nginx/marbefes-bbt-error.log${NC}"
    echo -e "  Service status: ${BLUE}sudo systemctl status ${SERVICE_NAME}${NC}"
    echo -e "  Restart:        ${BLUE}sudo systemctl restart ${SERVICE_NAME}${NC}"
    echo ""
    exit 1
fi
