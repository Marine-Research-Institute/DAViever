#!/bin/bash
# ============================================================================
# MarineSABRES DA Tool - Pre-Deployment Checklist
# ============================================================================
# Runs pre-deployment checks before deploying to production
# Usage: ./pre_deploy_check.sh
# ============================================================================

set -e

# Configuration
APP_DIR="/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer"
REQUIRED_FILES=(
    "app.py"
    "gunicorn.conf.py"
    "requirements.txt"
    "deploy_to_da.sh"
    "marinesabres-da.service"
    "nginx-da.conf"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

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

# Check functions

check_working_directory() {
    print_header "Checking Working Directory"

    if [ ! -d "$APP_DIR" ]; then
        print_error "Application directory not found: $APP_DIR"
        return 1
    fi

    if [ "$(pwd)" != "$APP_DIR" ]; then
        print_warning "Not in application directory. Current: $(pwd)"
        print_info "Run: cd $APP_DIR"
        return 1
    else
        print_success "In correct directory: $APP_DIR"
        return 0
    fi
}

check_required_files() {
    print_header "Checking Required Files"

    local all_found=0

    for file in "${REQUIRED_FILES[@]}"; do
        if [ -f "$APP_DIR/$file" ]; then
            print_success "Found: $file"
        else
            print_error "Missing: $file"
            all_found=1
        fi
    done

    return $all_found
}

check_python_version() {
    print_header "Checking Python Version"

    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | awk '{print $2}')
        PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
        PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)

        if [ "$PYTHON_MAJOR" -ge 3 ] && [ "$PYTHON_MINOR" -ge 9 ]; then
            print_success "Python version: $PYTHON_VERSION (>= 3.9)"
            return 0
        else
            print_error "Python version: $PYTHON_VERSION (requires >= 3.9)"
            return 1
        fi
    else
        print_error "Python 3 not found"
        return 1
    fi
}

check_virtual_environment() {
    print_header "Checking Virtual Environment"

    if [ -d "$APP_DIR/venv" ]; then
        print_success "Virtual environment exists"

        # Check if venv has required packages
        if [ -f "$APP_DIR/venv/bin/python" ]; then
            if "$APP_DIR/venv/bin/python" -c "import flask, gunicorn, requests" 2>/dev/null; then
                print_success "Required Python packages installed"
                return 0
            else
                print_error "Required Python packages missing"
                print_info "Run: source venv/bin/activate && pip install -r requirements.txt"
                return 1
            fi
        else
            print_error "Virtual environment appears corrupt"
            return 1
        fi
    else
        print_error "Virtual environment not found"
        print_info "Run: python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt"
        return 1
    fi
}

check_dependencies() {
    print_header "Checking System Dependencies"

    local deps_ok=0

    # Check nginx
    if command -v nginx &> /dev/null; then
        print_success "nginx is installed ($(nginx -v 2>&1 | grep -oP 'nginx/\K[0-9.]+'))"
    else
        print_error "nginx is not installed"
        print_info "Run: sudo apt install nginx"
        deps_ok=1
    fi

    # Check systemctl
    if command -v systemctl &> /dev/null; then
        print_success "systemd is available"
    else
        print_error "systemd is not available"
        deps_ok=1
    fi

    # Check curl
    if command -v curl &> /dev/null; then
        print_success "curl is installed"
    else
        print_warning "curl is not installed (optional but recommended)"
        print_info "Run: sudo apt install curl"
    fi

    return $deps_ok
}

check_permissions() {
    print_header "Checking Permissions"

    # Check if running as correct user
    if [ "$EUID" -eq 0 ]; then
        print_error "Running as root - should run as regular user"
        print_info "Run as user: razinka"
        return 1
    else
        print_success "Running as user: $(whoami)"
    fi

    # Check file permissions
    if [ -x "$APP_DIR/deploy_to_da.sh" ]; then
        print_success "deploy_to_da.sh is executable"
    else
        print_warning "deploy_to_da.sh is not executable"
        print_info "Run: chmod +x deploy_to_da.sh"
    fi

    # Check if user can sudo
    if sudo -n true 2>/dev/null; then
        print_success "User has passwordless sudo (not required but convenient)"
    else
        print_info "User will need to enter sudo password during deployment"
    fi

    return 0
}

check_git_status() {
    print_header "Checking Git Status"

    if [ ! -d "$APP_DIR/.git" ]; then
        print_warning "Not a git repository"
        return 1
    fi

    cd "$APP_DIR"

    # Check for uncommitted changes
    if [ -n "$(git status --porcelain)" ]; then
        print_warning "Uncommitted changes detected:"
        git status --short | head -10
        print_info "Consider committing changes before deployment"
    else
        print_success "No uncommitted changes"
    fi

    # Check current branch
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$CURRENT_BRANCH" ]; then
        print_info "Current branch: $CURRENT_BRANCH"
    fi

    # Check if branch is up to date with remote
    if git rev-parse --abbrev-ref --symbolic-full-name @{u} &>/dev/null; then
        LOCAL=$(git rev-parse @)
        REMOTE=$(git rev-parse @{u})

        if [ "$LOCAL" = "$REMOTE" ]; then
            print_success "Branch is up to date with remote"
        else
            print_warning "Branch is not in sync with remote"
            print_info "Consider running: git pull"
        fi
    else
        print_warning "No remote tracking branch configured"
    fi

    return 0
}

check_configuration_files() {
    print_header "Checking Configuration Files"

    # Check gunicorn.conf.py
    if "$APP_DIR/venv/bin/python" -m py_compile "$APP_DIR/gunicorn.conf.py" 2>/dev/null; then
        print_success "gunicorn.conf.py syntax OK"
    else
        print_error "gunicorn.conf.py has syntax errors"
        return 1
    fi

    # Check app.py
    if "$APP_DIR/venv/bin/python" -m py_compile "$APP_DIR/app.py" 2>/dev/null; then
        print_success "app.py syntax OK"
    else
        print_error "app.py has syntax errors"
        return 1
    fi

    # Check nginx config template
    if [ -f "$APP_DIR/nginx-da.conf" ]; then
        print_success "nginx-da.conf template exists"
    else
        print_error "nginx-da.conf template missing"
        return 1
    fi

    # Check systemd service template
    if [ -f "$APP_DIR/marinesabres-da.service" ]; then
        # Check for default SECRET_KEY
        if grep -q "change-this-in-production-to-secure-key" "$APP_DIR/marinesabres-da.service"; then
            print_info "Default SECRET_KEY detected (will be auto-generated during deployment)"
        else
            print_success "Custom SECRET_KEY configured"
        fi
    else
        print_error "marinesabres-da.service template missing"
        return 1
    fi

    return 0
}

check_static_assets() {
    print_header "Checking Static Assets"

    local assets_ok=0

    # Check static directories
    if [ -d "$APP_DIR/static" ]; then
        print_success "static/ directory exists"
    else
        print_error "static/ directory missing"
        assets_ok=1
    fi

    if [ -d "$APP_DIR/templates" ]; then
        print_success "templates/ directory exists"
    else
        print_error "templates/ directory missing"
        assets_ok=1
    fi

    if [ -d "$APP_DIR/LOGO" ]; then
        print_success "LOGO/ directory exists"
    else
        print_warning "LOGO/ directory missing (optional)"
    fi

    # Check for index.html
    if [ -f "$APP_DIR/templates/index.html" ]; then
        print_success "templates/index.html exists"
    else
        print_error "templates/index.html missing"
        assets_ok=1
    fi

    return $assets_ok
}

check_logs_directory() {
    print_header "Checking Logs Directory"

    if [ -d "$APP_DIR/logs" ]; then
        print_success "logs/ directory exists"

        # Check permissions
        if [ -w "$APP_DIR/logs" ]; then
            print_success "logs/ directory is writable"
        else
            print_error "logs/ directory is not writable"
            return 1
        fi
    else
        print_warning "logs/ directory does not exist (will be created automatically)"
    fi

    return 0
}

check_wms_connectivity() {
    print_header "Checking EMODnet WMS Connectivity"

    if ! command -v curl &> /dev/null; then
        print_warning "curl not available, skipping WMS check"
        return 1
    fi

    WMS_URL="https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms?service=WMS&version=1.3.0&request=GetCapabilities"

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$WMS_URL" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
        print_success "EMODnet WMS service is accessible"
        return 0
    else
        print_warning "EMODnet WMS service returned HTTP $HTTP_CODE (fallback layers will be used)"
        return 1
    fi
}

check_port_availability() {
    print_header "Checking Port Availability"

    PORT=5002

    if command -v lsof &> /dev/null; then
        if lsof -i :$PORT >/dev/null 2>&1; then
            print_warning "Port $PORT is already in use"
            print_info "Existing service will be stopped during deployment"
        else
            print_success "Port $PORT is available"
        fi
    else
        print_info "lsof not available, skipping port check"
    fi

    return 0
}

# Summary function
print_summary() {
    print_header "Pre-Deployment Check Summary"

    local total_checks=$((CHECKS_PASSED + CHECKS_FAILED + CHECKS_WARNING))

    echo ""
    echo -e "${BLUE}Total Checks:${NC}   $total_checks"
    echo -e "${GREEN}Passed:${NC}         $CHECKS_PASSED"
    echo -e "${YELLOW}Warnings:${NC}       $CHECKS_WARNING"
    echo -e "${RED}Failed:${NC}         $CHECKS_FAILED"

    echo ""

    if [ $CHECKS_FAILED -eq 0 ] && [ $CHECKS_WARNING -eq 0 ]; then
        echo -e "${GREEN}✓ All pre-deployment checks passed!${NC}"
        echo -e "${GREEN}✓ Ready to deploy${NC}"
        echo ""
        echo -e "${BLUE}To deploy, run:${NC}"
        echo "  cd $APP_DIR"
        echo "  ./deploy_to_da.sh"
        return 0
    elif [ $CHECKS_FAILED -eq 0 ]; then
        echo -e "${YELLOW}⚠ Pre-deployment checks completed with warnings${NC}"
        echo -e "${YELLOW}⚠ Review warnings before deploying${NC}"
        echo ""
        echo -e "${BLUE}To deploy anyway, run:${NC}"
        echo "  cd $APP_DIR"
        echo "  ./deploy_to_da.sh"
        return 1
    else
        echo -e "${RED}✗ Pre-deployment checks failed!${NC}"
        echo -e "${RED}✗ Fix errors before deploying${NC}"
        echo ""
        echo -e "${BLUE}Fix the issues above and run this script again${NC}"
        return 2
    fi
}

# Main execution
main() {
    print_header "MarineSABRES DA Tool - Pre-Deployment Checklist"
    print_info "Application: MarineSABRES Demonstration Area Tool"
    print_info "Target URL: http://laguna.ku.lt/DA/"
    print_info "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"

    echo ""
    print_info "Running pre-deployment checks..."

    # Run all checks
    check_working_directory
    check_required_files
    check_python_version
    check_virtual_environment
    check_dependencies
    check_permissions
    check_git_status
    check_configuration_files
    check_static_assets
    check_logs_directory
    check_wms_connectivity
    check_port_availability

    # Print summary
    print_summary
    exit_code=$?

    exit $exit_code
}

# Run main function
main "$@"
