#!/bin/bash
# ============================================================================
# MarineSABRES DA Tool - Health Check Script
# ============================================================================
# This script performs comprehensive health checks on the deployed application
# Can be run manually or scheduled via cron for continuous monitoring
# ============================================================================

set -e

# Configuration
APP_URL="${APP_URL:-http://laguna.ku.lt/DA}"
SERVICE_NAME="${SERVICE_NAME:-marinesabres-da}"
LOG_FILE="${LOG_FILE:-/tmp/marinesabres-da-health.log}"
ALERT_EMAIL="${ALERT_EMAIL:-}"  # Set to enable email alerts
MAX_RESPONSE_TIME=5  # seconds
MIN_WORKER_COUNT=2

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Exit codes
EXIT_SUCCESS=0
EXIT_WARNING=1
EXIT_CRITICAL=2

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    CHECKS_WARNING=$((CHECKS_WARNING + 1))
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
}

print_header() {
    echo ""
    echo "============================================================================"
    echo -e "${BLUE}$1${NC}"
    echo "============================================================================"
}

# Health check functions

check_service_running() {
    print_header "Checking Service Status"

    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Service $SERVICE_NAME is running"
        log "INFO: Service $SERVICE_NAME is active"
        return 0
    else
        print_error "Service $SERVICE_NAME is not running"
        log "CRITICAL: Service $SERVICE_NAME is not active"
        return 1
    fi
}

check_service_enabled() {
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        print_success "Service $SERVICE_NAME is enabled at boot"
        return 0
    else
        print_warning "Service $SERVICE_NAME is not enabled at boot"
        return 1
    fi
}

check_worker_processes() {
    print_header "Checking Worker Processes"

    WORKER_COUNT=$(pgrep -f "gunicorn.*marinesabres-da" | wc -l)

    if [ "$WORKER_COUNT" -ge "$MIN_WORKER_COUNT" ]; then
        print_success "Found $WORKER_COUNT Gunicorn worker processes"
        log "INFO: $WORKER_COUNT workers running"
        return 0
    elif [ "$WORKER_COUNT" -gt 0 ]; then
        print_warning "Only $WORKER_COUNT worker(s) running (expected >= $MIN_WORKER_COUNT)"
        log "WARNING: Low worker count: $WORKER_COUNT"
        return 1
    else
        print_error "No Gunicorn worker processes found"
        log "CRITICAL: No workers running"
        return 1
    fi
}

check_http_endpoint() {
    local endpoint="$1"
    local expected_status="${2:-200}"
    local timeout=10

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$APP_URL$endpoint" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "$expected_status" ]; then
        print_success "HTTP $endpoint returned $HTTP_CODE"
        return 0
    else
        print_error "HTTP $endpoint returned $HTTP_CODE (expected $expected_status)"
        log "ERROR: Endpoint $endpoint failed with HTTP $HTTP_CODE"
        return 1
    fi
}

check_health_endpoint() {
    print_header "Checking Health Endpoint"

    RESPONSE=$(curl -s --max-time 10 "$APP_URL/health" 2>/dev/null || echo "")

    if [ -n "$RESPONSE" ]; then
        STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

        if [ "$STATUS" = "healthy" ]; then
            print_success "Health endpoint reports: $STATUS"
            log "INFO: Health endpoint OK"
            return 0
        else
            print_warning "Health endpoint reports: ${STATUS:-unknown}"
            log "WARNING: Health status: ${STATUS:-unknown}"
            return 1
        fi
    else
        print_error "Health endpoint not responding"
        log "ERROR: Health endpoint unreachable"
        return 1
    fi
}

check_response_time() {
    print_header "Checking Response Time"

    START_TIME=$(date +%s.%N)
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "$APP_URL/" 2>/dev/null || echo "000")
    END_TIME=$(date +%s.%N)

    RESPONSE_TIME=$(echo "$END_TIME - $START_TIME" | bc)

    if [ "$HTTP_CODE" != "200" ]; then
        print_error "HTTP request failed with code $HTTP_CODE"
        return 1
    fi

    if (( $(echo "$RESPONSE_TIME < $MAX_RESPONSE_TIME" | bc -l) )); then
        print_success "Response time: ${RESPONSE_TIME}s (< ${MAX_RESPONSE_TIME}s)"
        log "INFO: Response time OK: ${RESPONSE_TIME}s"
        return 0
    else
        print_warning "Slow response time: ${RESPONSE_TIME}s (>= ${MAX_RESPONSE_TIME}s)"
        log "WARNING: Slow response: ${RESPONSE_TIME}s"
        return 1
    fi
}

check_static_files() {
    print_header "Checking Static Files"

    check_http_endpoint "/static/js/map-init.js" "200"
    local js_result=$?

    check_http_endpoint "/logo/marinesabres_logo.png" "200" || \
    check_http_endpoint "/logo/marbefes_02.png" "200"
    local logo_result=$?

    if [ $js_result -eq 0 ] && [ $logo_result -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

check_api_endpoints() {
    print_header "Checking API Endpoints"

    # Check /api/layers endpoint
    LAYERS_RESPONSE=$(curl -s --max-time 15 "$APP_URL/api/layers" 2>/dev/null || echo "")

    if [ -n "$LAYERS_RESPONSE" ]; then
        LAYER_COUNT=$(echo "$LAYERS_RESPONSE" | grep -o '"name"' | wc -l)
        if [ "$LAYER_COUNT" -gt 0 ]; then
            print_success "API /api/layers returned $LAYER_COUNT layers"
            log "INFO: API layers OK ($LAYER_COUNT layers)"
        else
            print_warning "API /api/layers returned empty or invalid response"
            log "WARNING: API layers returned no data"
        fi
    else
        print_error "API /api/layers not responding"
        log "ERROR: API layers unreachable"
        return 1
    fi

    # Check /api/all-layers endpoint
    ALL_LAYERS_RESPONSE=$(curl -s --max-time 15 "$APP_URL/api/all-layers" 2>/dev/null || echo "")

    if [ -n "$ALL_LAYERS_RESPONSE" ]; then
        print_success "API /api/all-layers responding"
        log "INFO: API all-layers OK"
        return 0
    else
        print_warning "API /api/all-layers not responding"
        log "WARNING: API all-layers unreachable"
        return 1
    fi
}

check_memory_usage() {
    print_header "Checking Memory Usage"

    # Get memory usage for all Gunicorn processes
    TOTAL_MEM=0
    for pid in $(pgrep -f "gunicorn.*marinesabres-da"); do
        MEM=$(ps -o rss= -p "$pid" 2>/dev/null || echo 0)
        TOTAL_MEM=$((TOTAL_MEM + MEM))
    done

    # Convert to MB
    TOTAL_MEM_MB=$((TOTAL_MEM / 1024))

    if [ "$TOTAL_MEM_MB" -gt 0 ]; then
        if [ "$TOTAL_MEM_MB" -lt 1000 ]; then
            print_success "Memory usage: ${TOTAL_MEM_MB}MB"
            log "INFO: Memory usage OK: ${TOTAL_MEM_MB}MB"
            return 0
        elif [ "$TOTAL_MEM_MB" -lt 2000 ]; then
            print_warning "High memory usage: ${TOTAL_MEM_MB}MB"
            log "WARNING: High memory: ${TOTAL_MEM_MB}MB"
            return 1
        else
            print_error "Very high memory usage: ${TOTAL_MEM_MB}MB"
            log "CRITICAL: Very high memory: ${TOTAL_MEM_MB}MB"
            return 1
        fi
    else
        print_warning "Could not determine memory usage"
        return 1
    fi
}

check_disk_space() {
    print_header "Checking Disk Space"

    APP_DIR="/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer"

    if [ -d "$APP_DIR" ]; then
        DISK_USAGE=$(df -h "$APP_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')

        if [ "$DISK_USAGE" -lt 80 ]; then
            print_success "Disk usage: ${DISK_USAGE}%"
            log "INFO: Disk usage OK: ${DISK_USAGE}%"
            return 0
        elif [ "$DISK_USAGE" -lt 90 ]; then
            print_warning "High disk usage: ${DISK_USAGE}%"
            log "WARNING: High disk usage: ${DISK_USAGE}%"
            return 1
        else
            print_error "Critical disk usage: ${DISK_USAGE}%"
            log "CRITICAL: Critical disk usage: ${DISK_USAGE}%"
            return 1
        fi
    else
        print_warning "Application directory not found"
        return 1
    fi
}

check_log_files() {
    print_header "Checking Log Files"

    APP_DIR="/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer"

    if [ -d "$APP_DIR/logs" ]; then
        # Check for recent errors
        ERROR_COUNT=$(find "$APP_DIR/logs" -name "*.log" -mtime -1 -exec grep -c "ERROR\|CRITICAL" {} + 2>/dev/null | awk '{s+=$1} END {print s}')
        ERROR_COUNT=${ERROR_COUNT:-0}

        if [ "$ERROR_COUNT" -eq 0 ]; then
            print_success "No errors in logs (last 24h)"
            log "INFO: No recent errors in logs"
            return 0
        elif [ "$ERROR_COUNT" -lt 10 ]; then
            print_warning "Found $ERROR_COUNT errors in logs (last 24h)"
            log "WARNING: $ERROR_COUNT errors in logs"
            return 1
        else
            print_error "Found $ERROR_COUNT errors in logs (last 24h)"
            log "CRITICAL: $ERROR_COUNT errors in logs"
            return 1
        fi
    else
        print_warning "Log directory not found"
        return 1
    fi
}

check_wms_connectivity() {
    print_header "Checking EMODnet WMS Connectivity"

    WMS_URL="https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms?service=WMS&version=1.3.0&request=GetCapabilities"

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$WMS_URL" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
        print_success "EMODnet WMS service is accessible"
        log "INFO: WMS connectivity OK"
        return 0
    else
        print_warning "EMODnet WMS service returned HTTP $HTTP_CODE"
        log "WARNING: WMS connectivity issue: HTTP $HTTP_CODE"
        return 1
    fi
}

# Alert function
send_alert() {
    local message="$1"

    if [ -n "$ALERT_EMAIL" ]; then
        echo "$message" | mail -s "MarineSABRES DA Tool Health Alert" "$ALERT_EMAIL"
        log "INFO: Alert sent to $ALERT_EMAIL"
    fi
}

# Main execution
main() {
    print_header "MarineSABRES DA Tool - Health Check"
    print_info "URL: $APP_URL"
    print_info "Service: $SERVICE_NAME"
    print_info "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"

    log "INFO: Starting health check"

    # Run all health checks
    check_service_running
    check_service_enabled
    check_worker_processes
    check_health_endpoint
    check_response_time
    check_static_files
    check_api_endpoints
    check_memory_usage
    check_disk_space
    check_log_files
    check_wms_connectivity

    # Summary
    print_header "Health Check Summary"
    echo -e "${GREEN}Passed:  $CHECKS_PASSED${NC}"
    echo -e "${YELLOW}Warnings: $CHECKS_WARNING${NC}"
    echo -e "${RED}Failed:   $CHECKS_FAILED${NC}"

    log "INFO: Health check complete - Passed: $CHECKS_PASSED, Warnings: $CHECKS_WARNING, Failed: $CHECKS_FAILED"

    # Determine exit code and send alerts
    if [ "$CHECKS_FAILED" -gt 0 ]; then
        print_error "Health check FAILED - Critical issues detected"
        send_alert "MarineSABRES DA Tool health check FAILED with $CHECKS_FAILED critical issues"
        exit $EXIT_CRITICAL
    elif [ "$CHECKS_WARNING" -gt 0 ]; then
        print_warning "Health check completed with WARNINGS"
        exit $EXIT_WARNING
    else
        print_success "All health checks PASSED"
        exit $EXIT_SUCCESS
    fi
}

# Run main function
main "$@"
