#!/bin/bash
################################################################################
# MARBEFES BBT Database - Subpath Deployment Verification Script
#
# Verifies deployment at http://YOUR_SERVER/BBTS
################################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROD_DIR="/var/www/marbefes-bbt"
SERVICE_NAME="marbefes-bbt"
NGINX_SITE="marbefes-bbt"
BASE_URL="http://localhost"
SUBPATH="/BBTS"
TEST_URL="${BASE_URL}${SUBPATH}"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   MARBEFES BBT Database - Subpath Deployment Verification ║${NC}"
echo -e "${BLUE}║   Testing URL: ${TEST_URL}                              ║${NC}"
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

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}1. File System Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

run_test "Production directory exists" "[ -d '$PROD_DIR' ]"
run_test "app.py exists" "[ -f '$PROD_DIR/app.py' ]"
run_test "wsgi_subpath.py exists" "[ -f '$PROD_DIR/wsgi_subpath.py' ]"
run_test "Virtual environment exists" "[ -d '$PROD_DIR/venv' ]"
run_test ".env file exists" "[ -f '$PROD_DIR/.env' ]"
run_test "gunicorn_config.py exists" "[ -f '$PROD_DIR/gunicorn_config.py' ]"
run_test "logs directory exists" "[ -d '$PROD_DIR/logs' ]"

# Check APPLICATION_ROOT in .env
if grep -q "APPLICATION_ROOT=${SUBPATH}" "$PROD_DIR/.env" 2>/dev/null; then
    echo -e "${BLUE}[TEST]${NC} APPLICATION_ROOT set to ${SUBPATH}... ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${BLUE}[TEST]${NC} APPLICATION_ROOT set to ${SUBPATH}... ${YELLOW}⚠ WARNING${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}2. Systemd Service Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

run_test "Systemd service file exists" "[ -f '/etc/systemd/system/${SERVICE_NAME}.service' ]"
run_test "Service is enabled" "systemctl is-enabled ${SERVICE_NAME}"
run_test "Service is active" "systemctl is-active ${SERVICE_NAME}"

# Check if service uses wsgi_subpath
if grep -q "wsgi_subpath:application" "/etc/systemd/system/${SERVICE_NAME}.service"; then
    echo -e "${BLUE}[TEST]${NC} Service uses wsgi_subpath wrapper... ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${BLUE}[TEST]${NC} Service uses wsgi_subpath wrapper... ${RED}✗ FAIL${NC}"
    ((TESTS_FAILED++))
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}3. Nginx Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

run_test "Nginx configuration exists" "[ -f '/etc/nginx/sites-available/${NGINX_SITE}' ]"
run_test "Nginx site is enabled" "[ -L '/etc/nginx/sites-enabled/${NGINX_SITE}' ]"
run_test "Nginx configuration is valid" "nginx -t"
run_test "Nginx is running" "systemctl is-active nginx"

# Check if nginx configured for /BBTS
if grep -q "location ${SUBPATH}" "/etc/nginx/sites-available/${NGINX_SITE}"; then
    echo -e "${BLUE}[TEST]${NC} Nginx configured for ${SUBPATH} path... ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${BLUE}[TEST]${NC} Nginx configured for ${SUBPATH} path... ${RED}✗ FAIL${NC}"
    ((TESTS_FAILED++))
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}4. Subpath HTTP Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Test main page at /BBTS
if curl -sf -o /dev/null "$TEST_URL"; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TEST_URL")
    echo -e "${BLUE}[TEST]${NC} ${SUBPATH} main page accessible... ${GREEN}✓ PASS${NC} (HTTP $HTTP_CODE)"
    ((TESTS_PASSED++))
else
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TEST_URL")
    echo -e "${BLUE}[TEST]${NC} ${SUBPATH} main page accessible... ${RED}✗ FAIL${NC} (HTTP $HTTP_CODE)"
    ((TESTS_FAILED++))
fi

# Test API endpoints at /BBTS
ENDPOINTS=(
    "/api/layers"
    "/api/all-layers"
    "/api/vector/layers"
    "/api/capabilities"
)

for endpoint in "${ENDPOINTS[@]}"; do
    FULL_URL="${TEST_URL}${endpoint}"
    if curl -sf -o /dev/null "$FULL_URL"; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$FULL_URL")
        echo -e "${BLUE}[TEST]${NC} ${SUBPATH}${endpoint} accessible... ${GREEN}✓ PASS${NC} (HTTP $HTTP_CODE)"
        ((TESTS_PASSED++))
    else
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$FULL_URL")
        echo -e "${BLUE}[TEST]${NC} ${SUBPATH}${endpoint} accessible... ${RED}✗ FAIL${NC} (HTTP $HTTP_CODE)"
        ((TESTS_FAILED++))
    fi
done

# Test that root path shows redirect message
if curl -sf "$BASE_URL" | grep -q "BBT Database"; then
    echo -e "${BLUE}[TEST]${NC} Root path shows BBT redirect message... ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${BLUE}[TEST]${NC} Root path shows BBT redirect message... ${YELLOW}⚠ WARNING${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}5. Performance Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Response time test
RESPONSE_TIME=$(curl -o /dev/null -s -w '%{time_total}' "${TEST_URL}/api/layers")
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
echo -e "${BLUE}6. Python Dependencies Test${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

cd "$PROD_DIR"
source venv/bin/activate

REQUIRED_PACKAGES=(
    "flask"
    "gunicorn"
    "requests"
    "werkzeug"
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
echo -e "${BLUE}7. Network Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if ss -tunlp | grep ":5000" > /dev/null; then
    echo -e "${BLUE}[TEST]${NC} Gunicorn listening on port 5000... ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${BLUE}[TEST]${NC} Gunicorn listening on port 5000... ${RED}✗ FAIL${NC}"
    ((TESTS_FAILED++))
fi

if ss -tunlp | grep ":80" > /dev/null; then
    echo -e "${BLUE}[TEST]${NC} Nginx listening on port 80... ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${BLUE}[TEST]${NC} Nginx listening on port 80... ${RED}✗ FAIL${NC}"
    ((TESTS_FAILED++))
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}8. URL Path Verification${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Test various URL patterns
echo -e "${BLUE}[INFO]${NC} Testing URL patterns..."

# Should work: /BBTS
if curl -sf -o /dev/null "${BASE_URL}${SUBPATH}"; then
    echo -e "  ${GREEN}✓${NC} ${BASE_URL}${SUBPATH} - accessible"
else
    echo -e "  ${RED}✗${NC} ${BASE_URL}${SUBPATH} - failed"
fi

# Should work: /BBTS/
if curl -sf -o /dev/null "${BASE_URL}${SUBPATH}/"; then
    echo -e "  ${GREEN}✓${NC} ${BASE_URL}${SUBPATH}/ - accessible"
else
    echo -e "  ${RED}✗${NC} ${BASE_URL}${SUBPATH}/ - failed"
fi

# Should work: /BBTS/api/layers
if curl -sf -o /dev/null "${BASE_URL}${SUBPATH}/api/layers"; then
    echo -e "  ${GREEN}✓${NC} ${BASE_URL}${SUBPATH}/api/layers - accessible"
else
    echo -e "  ${RED}✗${NC} ${BASE_URL}${SUBPATH}/api/layers - failed"
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
    echo -e "${BLUE}Application is ready at subpath ${SUBPATH}!${NC}"
    echo ""
    echo -e "${BLUE}Access URLs:${NC}"
    echo -e "  Local:    ${YELLOW}${TEST_URL}${NC}"
    echo -e "  Network:  ${YELLOW}http://$(hostname -I | awk '{print $1}')${SUBPATH}${NC}"
    echo ""
    echo -e "${BLUE}API Endpoints:${NC}"
    echo -e "  Layers:   ${YELLOW}${TEST_URL}/api/layers${NC}"
    echo -e "  All:      ${YELLOW}${TEST_URL}/api/all-layers${NC}"
    echo -e "  Vector:   ${YELLOW}${TEST_URL}/api/vector/layers${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║     ✗ SOME TESTS FAILED - REVIEW ISSUES ABOVE             ║${NC}"
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo -e "  Logs:    ${BLUE}sudo journalctl -u ${SERVICE_NAME} -f${NC}"
    echo -e "  Restart: ${BLUE}sudo systemctl restart ${SERVICE_NAME}${NC}"
    echo -e "  Test:    ${BLUE}curl -I ${TEST_URL}${NC}"
    echo ""
    exit 1
fi
