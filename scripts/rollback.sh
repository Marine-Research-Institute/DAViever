#!/bin/bash
# ============================================================================
# MarineSABRES DA Tool - Rollback Script
# ============================================================================
# Restores a previous backup of the application
# Usage: ./rollback.sh [backup_name]
#   If no backup_name provided, lists available backups and prompts for selection
# ============================================================================

set -e

# Configuration
APP_DIR="/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer"
BACKUP_BASE_DIR="${BACKUP_DIR:-$APP_DIR/backups}"
SERVICE_NAME="marinesabres-da"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "============================================================================"
    echo -e "${BLUE}$1${NC}"
    echo "============================================================================"
}

# List available backups
list_backups() {
    print_header "Available Backups"

    if [ ! -d "$BACKUP_BASE_DIR" ] || [ -z "$(ls -A "$BACKUP_BASE_DIR"/*.tar.gz 2>/dev/null)" ]; then
        print_error "No backups found in $BACKUP_BASE_DIR"
        exit 1
    fi

    echo ""
    echo -e "${BLUE}Available backups (most recent first):${NC}"
    echo ""

    local index=1
    ls -1t "$BACKUP_BASE_DIR"/*.tar.gz | while read -r backup_file; do
        local backup_name=$(basename "$backup_file" .tar.gz)
        local backup_size=$(du -h "$backup_file" | awk '{print $1}')
        local backup_date=$(stat -c %y "$backup_file" | cut -d'.' -f1)
        echo "  $index) $backup_name"
        echo "     Size: $backup_size | Date: $backup_date"
        echo ""
        index=$((index + 1))
    done
}

# Select backup interactively
select_backup() {
    list_backups

    echo ""
    read -p "Enter backup number to restore (or 'q' to quit): " selection

    if [ "$selection" = "q" ] || [ "$selection" = "Q" ]; then
        print_info "Rollback cancelled"
        exit 0
    fi

    # Get the selected backup
    BACKUP_FILE=$(ls -1t "$BACKUP_BASE_DIR"/*.tar.gz | sed -n "${selection}p")

    if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
        print_error "Invalid selection"
        exit 1
    fi

    BACKUP_NAME=$(basename "$BACKUP_FILE" .tar.gz)
}

# Confirm rollback
confirm_rollback() {
    print_header "Rollback Confirmation"

    echo -e "${YELLOW}WARNING:${NC} This will restore the application to a previous state"
    echo ""
    echo "Backup to restore: $BACKUP_NAME"
    echo "Backup file: $BACKUP_FILE"
    echo ""
    echo "Current deployment will be backed up first as a safety measure."
    echo ""
    read -p "Are you sure you want to proceed? (yes/no): " confirmation

    if [ "$confirmation" != "yes" ]; then
        print_info "Rollback cancelled"
        exit 0
    fi
}

# Create safety backup of current deployment
create_safety_backup() {
    print_header "Creating Safety Backup"

    print_info "Backing up current deployment before rollback..."

    if [ -f "$APP_DIR/scripts/backup_deployment.sh" ]; then
        "$APP_DIR/scripts/backup_deployment.sh" "pre-rollback-$(date +%Y%m%d_%H%M%S)"
        print_success "Safety backup created"
    else
        print_warning "Backup script not found, skipping safety backup"
        read -p "Continue without safety backup? (yes/no): " proceed
        if [ "$proceed" != "yes" ]; then
            exit 1
        fi
    fi
}

# Stop service
stop_service() {
    print_header "Stopping Service"

    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        print_info "Stopping $SERVICE_NAME service..."
        sudo systemctl stop "$SERVICE_NAME"
        sleep 2
        print_success "Service stopped"
    else
        print_info "Service is not running"
    fi
}

# Extract backup
extract_backup() {
    print_header "Extracting Backup"

    cd "$BACKUP_BASE_DIR"

    if [ ! -f "$BACKUP_FILE" ]; then
        print_error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi

    # Extract to temporary directory
    TEMP_DIR=$(mktemp -d)
    print_info "Extracting to temporary directory: $TEMP_DIR"

    tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

    if [ -d "$TEMP_DIR/$BACKUP_NAME" ]; then
        EXTRACT_DIR="$TEMP_DIR/$BACKUP_NAME"
        print_success "Backup extracted successfully"
    else
        print_error "Backup extraction failed"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
}

# Restore application files
restore_application() {
    print_header "Restoring Application Files"

    if [ ! -d "$EXTRACT_DIR/app" ]; then
        print_error "Application files not found in backup"
        return 1
    fi

    # Restore files and directories
    cd "$EXTRACT_DIR/app"

    for item in *; do
        if [ -e "$item" ]; then
            cp -r "$item" "$APP_DIR/"
            print_success "Restored: $item"
        fi
    done
}

# Restore configuration files
restore_configuration() {
    print_header "Restoring Configuration Files"

    if [ ! -d "$EXTRACT_DIR/config" ]; then
        print_warning "Configuration files not found in backup"
        return 0
    fi

    cd "$EXTRACT_DIR/config"

    # Restore systemd service
    if [ -f "$SERVICE_NAME.service" ]; then
        sudo cp "$SERVICE_NAME.service" "/etc/systemd/system/"
        sudo systemctl daemon-reload
        print_success "Restored: systemd service"
    fi

    # Restore nginx configuration
    if [ -f "default.d-da.conf" ]; then
        sudo cp "default.d-da.conf" "/etc/nginx/sites-available/"
        sudo nginx -t && print_success "Restored: nginx configuration" || print_warning "Nginx configuration test failed"
    fi
}

# Restore logs (optional)
restore_logs() {
    print_header "Restoring Logs"

    if [ ! -d "$EXTRACT_DIR/logs" ]; then
        print_info "No logs in backup to restore"
        return 0
    fi

    read -p "Restore logs from backup? (yes/no): " restore_logs_choice

    if [ "$restore_logs_choice" = "yes" ]; then
        mkdir -p "$APP_DIR/logs"
        cp -r "$EXTRACT_DIR/logs"/* "$APP_DIR/logs/"
        print_success "Logs restored"
    else
        print_info "Skipped log restoration"
    fi
}

# Display backup information
display_backup_info() {
    print_header "Backup Information"

    if [ -f "$EXTRACT_DIR/MANIFEST.txt" ]; then
        cat "$EXTRACT_DIR/MANIFEST.txt"
    else
        print_warning "Backup manifest not found"
    fi

    if [ -f "$EXTRACT_DIR/status/git_info.txt" ]; then
        echo ""
        echo -e "${BLUE}Git Information:${NC}"
        cat "$EXTRACT_DIR/status/git_info.txt"
    fi
}

# Cleanup extraction directory
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        print_info "Cleaned up temporary files"
    fi
}

# Start service
start_service() {
    print_header "Starting Service"

    print_info "Starting $SERVICE_NAME service..."
    sudo systemctl start "$SERVICE_NAME"

    # Wait for service to start
    sleep 3

    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Service started successfully"
    else
        print_error "Service failed to start"
        print_info "Check logs with: sudo journalctl -u $SERVICE_NAME -n 50"
        exit 1
    fi
}

# Reload nginx
reload_nginx() {
    print_header "Reloading Nginx"

    sudo nginx -t && sudo systemctl reload nginx
    print_success "Nginx reloaded"
}

# Verify rollback
verify_rollback() {
    print_header "Verifying Rollback"

    # Check service status
    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Service is running"
    else
        print_error "Service is not running"
        return 1
    fi

    # Check HTTP endpoint
    sleep 2
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://laguna.ku.lt/DA/health" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
        print_success "HTTP endpoint responding (HTTP $HTTP_CODE)"
    else
        print_warning "HTTP endpoint returned HTTP $HTTP_CODE"
    fi

    # Run health check if available
    if [ -f "$APP_DIR/scripts/health_check.sh" ]; then
        echo ""
        print_info "Running comprehensive health check..."
        "$APP_DIR/scripts/health_check.sh" || true
    fi
}

# Main execution
main() {
    print_header "MarineSABRES DA Tool - Rollback"

    # Set trap for cleanup
    trap cleanup EXIT

    # Determine backup to restore
    if [ -n "$1" ]; then
        # Backup name provided as argument
        BACKUP_NAME="$1"
        BACKUP_FILE="$BACKUP_BASE_DIR/${BACKUP_NAME}.tar.gz"

        if [ ! -f "$BACKUP_FILE" ]; then
            print_error "Backup not found: $BACKUP_FILE"
            list_backups
            exit 1
        fi
    else
        # No argument, list backups and prompt for selection
        select_backup
    fi

    # Confirm rollback
    confirm_rollback

    # Display backup information
    print_info "Backup: $BACKUP_NAME"
    echo ""

    # Perform rollback
    create_safety_backup
    stop_service
    extract_backup
    display_backup_info
    restore_application
    restore_configuration
    restore_logs
    start_service
    reload_nginx
    verify_rollback

    # Summary
    print_header "Rollback Complete"
    print_success "Successfully rolled back to: $BACKUP_NAME"

    echo ""
    echo -e "${BLUE}Verification URLs:${NC}"
    echo "  • Main page:    http://laguna.ku.lt/DA/"
    echo "  • Health check: http://laguna.ku.lt/DA/health"

    echo ""
    echo -e "${BLUE}Useful commands:${NC}"
    echo "  • View logs:       sudo journalctl -u $SERVICE_NAME -f"
    echo "  • Service status:  sudo systemctl status $SERVICE_NAME"
    echo "  • Full health check: ./scripts/health_check.sh"

    echo ""
    print_warning "If issues persist, restore from safety backup:"
    echo "  ./scripts/rollback.sh pre-rollback-<timestamp>"
}

# Run main function
main "$@"
