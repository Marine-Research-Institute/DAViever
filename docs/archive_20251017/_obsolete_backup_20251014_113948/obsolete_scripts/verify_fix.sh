#!/bin/bash
#
# Pre-Deployment Verification Script
# Verifies that all necessary changes have been made to the local files
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_header() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }

ERRORS=0

print_header "MARBEFES BBT - Pre-Deployment Verification"

# Check app.py
print_header "Checking app.py"

if grep -q "APPLICATION_ROOT=app.config.get('APPLICATION_ROOT', '')" app.py; then
    print_success "app.py: APPLICATION_ROOT passed to template context"
else
    print_error "app.py: Missing APPLICATION_ROOT in template context"
    ERRORS=$((ERRORS + 1))
fi

# Check templates/index.html
print_header "Checking templates/index.html"

# Check logo URL
if grep -q '{{ APPLICATION_ROOT }}/logo/marbefes_02.png' templates/index.html; then
    print_success "Logo URL uses APPLICATION_ROOT"
else
    print_error "Logo URL does not use APPLICATION_ROOT"
    ERRORS=$((ERRORS + 1))
fi

# Check API_BASE_URL constant
if grep -q "const API_BASE_URL = '{{ APPLICATION_ROOT }}';" templates/index.html; then
    print_success "API_BASE_URL constant defined"
else
    print_error "API_BASE_URL constant not found"
    ERRORS=$((ERRORS + 1))
fi

# Check API calls
print_info "Checking API fetch calls..."

API_CALL_COUNT=$(grep -c '\${API_BASE_URL}/api/vector/layer/' templates/index.html || true)
if [ "$API_CALL_COUNT" -ge 4 ]; then
    print_success "Found $API_CALL_COUNT API calls using API_BASE_URL (expected 4+)"
else
    print_warning "Found only $API_CALL_COUNT API calls using API_BASE_URL (expected 4)"
fi

# Check for hardcoded API URLs (should be none)
HARDCODED_COUNT=$(grep -c "fetch.*['\`]/api/" templates/index.html | grep -v API_BASE_URL || true)
if [ "$HARDCODED_COUNT" = "0" ] || [ -z "$HARDCODED_COUNT" ]; then
    print_success "No hardcoded /api/ URLs found"
else
    print_warning "Found $HARDCODED_COUNT potential hardcoded /api/ URLs"
    print_info "Running detailed check..."
    grep -n "fetch.*['\`]/api/" templates/index.html | grep -v API_BASE_URL || print_success "All API calls use API_BASE_URL"
fi

# Summary
print_header "Verification Summary"

if [ $ERRORS -eq 0 ]; then
    print_success "All checks passed! Files are ready for deployment."
    echo ""
    print_info "Next step: Run ./deploy_subpath_fix.sh"
    exit 0
else
    print_error "Found $ERRORS error(s). Please review the changes before deploying."
    exit 1
fi
