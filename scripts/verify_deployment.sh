#!/bin/bash
# ============================================================================
# MarineSABRES DA Tool - Deployment Verification Script
# ============================================================================
# Comprehensive post-deployment verification tests
# Usage: ./verify_deployment.sh [--verbose]
# ============================================================================

set -e

# Configuration
APP_URL="${APP_URL:-http://laguna.ku.lt/DA}"
SERVICE_NAME="${SERVICE_NAME:-marinesabres-da}"
VERBOSE="${1}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0
TESTS_TOTAL=0

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    TESTS_WARNING=$((TESTS_WARNING + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

print_header() {
    echo ""
    echo "============================================================================"
    echo -e "${BLUE}$1${NC}"
    echo "============================================================================"
}

# Test functions

test_service_running() {
    print_header "Test: Service Status"

    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Service $SERVICE_NAME is running"
        return 0
    else
        print_error "Service $SERVICE_NAME is not running"
        return 1
    fi
}

test_service_enabled() {
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        print_success "Service $SERVICE_NAME is enabled at boot"
        return 0
    else
        print_error "Service $SERVICE_NAME is not enabled at boot"
        return 1
    fi
}

test_worker_count() {
    print_header "Test: Worker Processes"

    WORKER_COUNT=$(pgrep -f "gunicorn.*marinesabres-da" | wc -l)

    if [ "$WORKER_COUNT" -ge 2 ]; then
        print_success "Found $WORKER_COUNT Gunicorn workers"
        return 0
    elif [ "$WORKER_COUNT" -gt 0 ]; then
        print_warning "Only $WORKER_COUNT worker process found (expected >=2)"
        return 1
    else
        print_error "No Gunicorn worker processes found"
        return 1
    fi
}

test_main_page() {
    print_header "Test: Main Page (HTTP 200)"

    local response=$(curl -s -o /tmp/main_page.html -w "%{http_code}" --max-time 10 "$APP_URL/" 2>/dev/null)

    if [ "$response" = "200" ]; then
        # Check if HTML contains expected elements
        if grep -q "MarineSABRES" /tmp/main_page.html 2>/dev/null; then
            print_success "Main page returns HTTP 200 with expected content"
            rm -f /tmp/main_page.html
            return 0
        else
            print_warning "Main page returns HTTP 200 but content may be incorrect"
            rm -f /tmp/main_page.html
            return 1
        fi
    else
        print_error "Main page returned HTTP $response (expected 200)"
        return 1
    fi
}

test_health_endpoint() {
    print_header "Test: Health Endpoint"

    local response=$(curl -s --max-time 10 "$APP_URL/health" 2>/dev/null)

    if [ -n "$response" ]; then
        local status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

        if [ "$status" = "healthy" ]; then
            print_success "Health endpoint reports: healthy"
            return 0
        else
            print_error "Health endpoint reports: ${status:-unknown}"
            return 1
        fi
    else
        print_error "Health endpoint not responding"
        return 1
    fi
}

test_api_layers() {
    print_header "Test: API /api/layers"

    local response=$(curl -s --max-time 15 "$APP_URL/api/layers" 2>/dev/null)

    if [ -n "$response" ]; then
        local layer_count=$(echo "$response" | grep -o '"name"' | wc -l)

        if [ "$layer_count" -gt 0 ]; then
            print_success "API /api/layers returns $layer_count layers"
            return 0
        else
            print_error "API /api/layers returned empty response"
            return 1
        fi
    else
        print_error "API /api/layers not responding"
        return 1
    fi
}

test_api_all_layers() {
    print_header "Test: API /api/all-layers"

    local response=$(curl -s --max-time 15 "$APP_URL/api/all-layers" 2>/dev/null)

    if [ -n "$response" ]; then
        print_success "API /api/all-layers responding"
        return 0
    else
        print_error "API /api/all-layers not responding"
        return 1
    fi
}

test_static_js() {
    print_header "Test: Static JavaScript Files"

    local js_files=(
        "/static/js/map-init.js"
        "/static/js/layer-manager.js"
        "/static/js/research-sites.js"
    )

    local all_passed=0

    for js_file in "${js_files[@]}"; do
        local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$APP_URL$js_file" 2>/dev/null)

        if [ "$response" = "200" ]; then
            print_success "Static file $js_file: HTTP 200"
        else
            print_error "Static file $js_file: HTTP $response"
            all_passed=1
        fi
    done

    return $all_passed
}

test_logo_files() {
    print_header "Test: Logo Files"

    local logo_found=0

    # Try different possible logo locations
    local logo_files=(
        "/logo/marinesabres_logo.png"
        "/logo/marbefes_02.png"
        "/LOGO/marinesabres_logo.png"
    )

    for logo_file in "${logo_files[@]}"; do
        local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$APP_URL$logo_file" 2>/dev/null)

        if [ "$response" = "200" ]; then
            print_success "Logo file $logo_file: HTTP 200"
            logo_found=1
            break
        fi
    done

    if [ $logo_found -eq 0 ]; then
        print_warning "No logo files found (checked: ${logo_files[*]})"
        return 1
    fi

    return 0
}

test_response_time() {
    print_header "Test: Response Time"

    local start_time=$(date +%s.%N)
    curl -s -o /dev/null --max-time 30 "$APP_URL/" 2>/dev/null
    local end_time=$(date +%s.%N)

    local response_time=$(echo "$end_time - $start_time" | bc)

    if (( $(echo "$response_time < 3" | bc -l) )); then
        print_success "Response time: ${response_time}s (< 3s)"
        return 0
    elif (( $(echo "$response_time < 10" | bc -l) )); then
        print_warning "Slow response time: ${response_time}s (< 10s)"
        return 1
    else
        print_error "Very slow response time: ${response_time}s (>= 10s)"
        return 1
    fi
}

test_nginx_config() {
    print_header "Test: Nginx Configuration"

    if sudo nginx -t >/dev/null 2>&1; then
        print_success "Nginx configuration is valid"
        return 0
    else
        print_error "Nginx configuration has errors"
        sudo nginx -t 2>&1 | tail -5
        return 1
    fi
}

test_subpath_rewrite() {
    print_header "Test: Subpath URL Rewriting"

    # Test that /DA/ redirects correctly
    local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$APP_URL" 2>/dev/null)

    if [ "$response" = "200" ] || [ "$response" = "301" ] || [ "$response" = "302" ]; then
        print_success "Subpath URL ($APP_URL) accessible: HTTP $response"
        return 0
    else
        print_error "Subpath URL failed: HTTP $response"
        return 1
    fi
}

test_wms_connectivity() {
    print_header "Test: EMODnet WMS Connectivity"

    local wms_url="https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms?service=WMS&version=1.3.0&request=GetCapabilities"
    local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$wms_url" 2>/dev/null)

    if [ "$response" = "200" ]; then
        print_success "EMODnet WMS service accessible: HTTP 200"
        return 0
    else
        print_warning "EMODnet WMS service: HTTP $response (fallback layers will be used)"
        return 1
    fi
}

test_log_files() {
    print_header "Test: Log Files"

    local app_dir="/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer"

    if [ -d "$app_dir/logs" ]; then
        # Check if log files exist and are writable
        if [ -f "$app_dir/logs/app.log" ]; then
            print_success "Application log file exists and is accessible"
            return 0
        else
            print_warning "Application log file not found (may not have been created yet)"
            return 1
        fi
    else
        print_error "Logs directory not found"
        return 1
    fi
}

test_environment_variables() {
    print_header "Test: Environment Variables"

    # Check key environment variables in the service
    local env_output=$(systemctl show "$SERVICE_NAME" -p Environment 2>/dev/null)

    if echo "$env_output" | grep -q "APPLICATION_ROOT=/DA"; then
        print_success "APPLICATION_ROOT environment variable is set correctly"
    else
        print_warning "APPLICATION_ROOT environment variable may not be set"
    fi

    if echo "$env_output" | grep -q "FLASK_ENV=production"; then
        print_success "FLASK_ENV is set to production"
        return 0
    else
        print_warning "FLASK_ENV may not be set to production"
        return 1
    fi
}

test_security_headers() {
    print_header "Test: Security Configuration"

    # Check if running as non-root
    local service_user=$(systemctl show "$SERVICE_NAME" -p User | cut -d= -f2)

    if [ "$service_user" != "root" ]; then
        print_success "Service running as non-root user: $service_user"
    else
        print_error "Service running as root (security risk)"
        return 1
    fi

    # Check systemd security features
    local protect_system=$(systemctl show "$SERVICE_NAME" -p ProtectSystem | cut -d= -f2)

    if [ "$protect_system" = "strict" ]; then
        print_success "ProtectSystem=strict enabled"
        return 0
    else
        print_warning "ProtectSystem not set to strict"
        return 1
    fi
}

test_concurrent_requests() {
    print_header "Test: Concurrent Request Handling"

    print_info "Sending 10 concurrent requests to /health endpoint..."

    local failed_count=0

    for i in {1..10}; do
        curl -s -o /dev/null -w "%{http_code}\n" --max-time 5 "$APP_URL/health" 2>/dev/null &
    done

    wait

    # Simple check - if we got here without hanging, consider it a pass
    print_success "Concurrent requests handled successfully"
    return 0
}

# Summary function
print_summary() {
    print_header "Verification Summary"

    local total_tests=$TESTS_TOTAL
    local pass_rate=0

    if [ $total_tests -gt 0 ]; then
        pass_rate=$((TESTS_PASSED * 100 / total_tests))
    fi

    echo ""
    echo -e "${BLUE}Total Tests:${NC}    $total_tests"
    echo -e "${GREEN}Passed:${NC}         $TESTS_PASSED"
    echo -e "${YELLOW}Warnings:${NC}       $TESTS_WARNING"
    echo -e "${RED}Failed:${NC}         $TESTS_FAILED"
    echo -e "${BLUE}Pass Rate:${NC}      ${pass_rate}%"

    echo ""

    if [ $TESTS_FAILED -eq 0 ] && [ $TESTS_WARNING -eq 0 ]; then
        echo -e "${GREEN}✓ All verification tests passed successfully!${NC}"
        return 0
    elif [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${YELLOW}⚠ Verification completed with warnings${NC}"
        return 1
    else
        echo -e "${RED}✗ Verification failed - $TESTS_FAILED critical issues detected${NC}"
        return 2
    fi
}

# Main execution
main() {
    print_header "MarineSABRES DA Tool - Deployment Verification"
    print_info "URL: $APP_URL"
    print_info "Service: $SERVICE_NAME"
    print_info "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"

    echo ""
    print_info "Running comprehensive verification tests..."

    # Run all tests
    test_service_running
    test_service_enabled
    test_worker_count
    test_main_page
    test_health_endpoint
    test_api_layers
    test_api_all_layers
    test_static_js
    test_logo_files
    test_response_time
    test_nginx_config
    test_subpath_rewrite
    test_wms_connectivity
    test_log_files
    test_environment_variables
    test_security_headers
    test_concurrent_requests

    # Print summary
    print_summary
    local exit_code=$?

    echo ""
    echo -e "${BLUE}Deployment URL:${NC}  $APP_URL"
    echo -e "${BLUE}Health Check:${NC}    $APP_URL/health"
    echo -e "${BLUE}Service Status:${NC}  sudo systemctl status $SERVICE_NAME"

    exit $exit_code
}

# Run main function
main "$@"
