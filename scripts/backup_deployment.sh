#!/bin/bash
# ============================================================================
# MarineSABRES DA Tool - Backup Script
# ============================================================================
# Creates a backup of the current deployment before updates
# Backups include: application code, configuration, logs
# Usage: ./backup_deployment.sh [backup_name]
# ============================================================================

set -e

# Configuration
APP_DIR="/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer"
BACKUP_BASE_DIR="${BACKUP_DIR:-$APP_DIR/backups}"
BACKUP_NAME="${1:-marinesabres-da-$(date +%Y%m%d_%H%M%S)}"
BACKUP_DIR="$BACKUP_BASE_DIR/$BACKUP_NAME"
SERVICE_NAME="marinesabres-da"
KEEP_BACKUPS=10  # Number of backups to keep

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

# Create backup directory
create_backup_dir() {
    print_header "Creating Backup Directory"

    if [ ! -d "$BACKUP_BASE_DIR" ]; then
        mkdir -p "$BACKUP_BASE_DIR"
        print_success "Created backup base directory: $BACKUP_BASE_DIR"
    fi

    if [ -d "$BACKUP_DIR" ]; then
        print_warning "Backup directory already exists: $BACKUP_DIR"
        BACKUP_DIR="${BACKUP_DIR}_$(date +%s)"
        print_info "Using alternate name: $BACKUP_DIR"
    fi

    mkdir -p "$BACKUP_DIR"
    print_success "Created backup directory: $BACKUP_DIR"
}

# Backup application files
backup_application() {
    print_header "Backing Up Application Files"

    # Create app backup subdirectory
    mkdir -p "$BACKUP_DIR/app"

    # Backup critical files
    local files=(
        "app.py"
        "gunicorn.conf.py"
        "requirements.txt"
        ".env"
        ".env.example"
    )

    for file in "${files[@]}"; do
        if [ -f "$APP_DIR/$file" ]; then
            cp "$APP_DIR/$file" "$BACKUP_DIR/app/"
            print_success "Backed up: $file"
        fi
    done

    # Backup directories
    local dirs=(
        "config"
        "src"
        "static"
        "templates"
        "LOGO"
    )

    for dir in "${dirs[@]}"; do
        if [ -d "$APP_DIR/$dir" ]; then
            cp -r "$APP_DIR/$dir" "$BACKUP_DIR/app/"
            print_success "Backed up: $dir/"
        fi
    done
}

# Backup configuration files
backup_configuration() {
    print_header "Backing Up Configuration Files"

    mkdir -p "$BACKUP_DIR/config"

    # Backup systemd service file
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        sudo cp "/etc/systemd/system/$SERVICE_NAME.service" "$BACKUP_DIR/config/"
        sudo chown "$USER:$USER" "$BACKUP_DIR/config/$SERVICE_NAME.service"
        print_success "Backed up: systemd service file"
    else
        print_warning "Systemd service file not found"
    fi

    # Backup nginx configuration
    if [ -f "/etc/nginx/sites-available/default.d-da.conf" ]; then
        sudo cp "/etc/nginx/sites-available/default.d-da.conf" "$BACKUP_DIR/config/"
        sudo chown "$USER:$USER" "$BACKUP_DIR/config/default.d-da.conf"
        print_success "Backed up: nginx configuration"
    else
        print_warning "Nginx configuration file not found"
    fi

    # Backup deployment scripts
    if [ -f "$APP_DIR/deploy_to_da.sh" ]; then
        cp "$APP_DIR/deploy_to_da.sh" "$BACKUP_DIR/config/"
        print_success "Backed up: deployment script"
    fi

    if [ -f "$APP_DIR/marinesabres-da.service" ]; then
        cp "$APP_DIR/marinesabres-da.service" "$BACKUP_DIR/config/"
        print_success "Backed up: service template"
    fi

    if [ -f "$APP_DIR/nginx-da.conf" ]; then
        cp "$APP_DIR/nginx-da.conf" "$BACKUP_DIR/config/"
        print_success "Backed up: nginx template"
    fi
}

# Backup logs
backup_logs() {
    print_header "Backing Up Logs"

    mkdir -p "$BACKUP_DIR/logs"

    if [ -d "$APP_DIR/logs" ]; then
        # Only backup last 50MB of logs to save space
        for log_file in "$APP_DIR/logs"/*.log; do
            if [ -f "$log_file" ]; then
                filename=$(basename "$log_file")
                # Use tail to get last 50000 lines (approximately 50MB for typical logs)
                tail -n 50000 "$log_file" > "$BACKUP_DIR/logs/$filename"
                print_success "Backed up: logs/$filename (last 50k lines)"
            fi
        done
    else
        print_warning "Logs directory not found"
    fi
}

# Save service status
save_service_status() {
    print_header "Saving Service Status"

    mkdir -p "$BACKUP_DIR/status"

    # Service status
    sudo systemctl status "$SERVICE_NAME" --no-pager > "$BACKUP_DIR/status/service_status.txt" 2>&1 || true
    print_success "Saved: service status"

    # Service environment
    systemctl show "$SERVICE_NAME" -p Environment > "$BACKUP_DIR/status/service_environment.txt" 2>&1 || true
    print_success "Saved: service environment"

    # Worker processes
    ps aux | grep "[g]unicorn.*marinesabres-da" > "$BACKUP_DIR/status/worker_processes.txt" 2>&1 || echo "No workers found" > "$BACKUP_DIR/status/worker_processes.txt"
    print_success "Saved: worker processes"

    # Git commit info
    if [ -d "$APP_DIR/.git" ]; then
        cd "$APP_DIR"
        git log -1 --format="Commit: %H%nAuthor: %an <%ae>%nDate: %ad%nMessage: %s" > "$BACKUP_DIR/status/git_info.txt" 2>&1 || true
        git diff HEAD > "$BACKUP_DIR/status/git_uncommitted.diff" 2>&1 || true
        print_success "Saved: Git information"
    fi

    # Python dependencies
    "$APP_DIR/venv/bin/pip" list > "$BACKUP_DIR/status/pip_packages.txt" 2>&1 || true
    print_success "Saved: Python package list"
}

# Create backup manifest
create_manifest() {
    print_header "Creating Backup Manifest"

    local manifest="$BACKUP_DIR/MANIFEST.txt"

    cat > "$manifest" << EOF
MarineSABRES DA Tool - Backup Manifest
======================================

Backup Name: $BACKUP_NAME
Backup Date: $(date '+%Y-%m-%d %H:%M:%S')
Backup Path: $BACKUP_DIR

System Information:
-------------------
Hostname: $(hostname)
User: $(whoami)
OS: $(uname -a)

Application Information:
-----------------------
App Directory: $APP_DIR
Service Name: $SERVICE_NAME

Backup Contents:
----------------
EOF

    # List all backed up files
    find "$BACKUP_DIR" -type f -exec ls -lh {} \; | awk '{print $9, "(" $5 ")"}' >> "$manifest"

    # Calculate total backup size
    local backup_size=$(du -sh "$BACKUP_DIR" | awk '{print $1}')
    echo "" >> "$manifest"
    echo "Total Backup Size: $backup_size" >> "$manifest"

    print_success "Created backup manifest"
}

# Compress backup
compress_backup() {
    print_header "Compressing Backup"

    cd "$BACKUP_BASE_DIR"
    local archive_name="${BACKUP_NAME}.tar.gz"

    tar -czf "$archive_name" "$BACKUP_NAME"

    if [ -f "$archive_name" ]; then
        local archive_size=$(du -h "$archive_name" | awk '{print $1}')
        print_success "Created compressed backup: $archive_name ($archive_size)"

        # Remove uncompressed backup
        rm -rf "$BACKUP_NAME"
        print_info "Removed uncompressed backup directory"

        echo ""
        echo -e "${GREEN}Backup archive:${NC} $BACKUP_BASE_DIR/$archive_name"
    else
        print_error "Failed to create compressed backup"
        return 1
    fi
}

# Clean old backups
cleanup_old_backups() {
    print_header "Cleaning Up Old Backups"

    cd "$BACKUP_BASE_DIR"

    # Count existing backups
    local backup_count=$(ls -1 *.tar.gz 2>/dev/null | wc -l)

    if [ "$backup_count" -gt "$KEEP_BACKUPS" ]; then
        print_info "Found $backup_count backups, keeping only $KEEP_BACKUPS most recent"

        # Remove oldest backups
        ls -1t *.tar.gz | tail -n +$((KEEP_BACKUPS + 1)) | while read -r old_backup; do
            rm -f "$old_backup"
            print_success "Removed old backup: $old_backup"
        done
    else
        print_info "Found $backup_count backups (limit: $KEEP_BACKUPS)"
    fi
}

# List available backups
list_backups() {
    print_header "Available Backups"

    if [ -d "$BACKUP_BASE_DIR" ]; then
        echo ""
        echo -e "${BLUE}Recent backups:${NC}"
        ls -lth "$BACKUP_BASE_DIR"/*.tar.gz 2>/dev/null | head -10 | awk '{print $9, "(" $5 ", " $6, $7, $8 ")"}'
    else
        print_warning "No backups directory found"
    fi
}

# Main execution
main() {
    print_header "MarineSABRES DA Tool - Backup Creation"

    # Check if running from correct directory
    if [ ! -f "$APP_DIR/app.py" ]; then
        print_error "Application directory not found: $APP_DIR"
        exit 1
    fi

    print_info "Application: $APP_DIR"
    print_info "Backup Name: $BACKUP_NAME"

    # Create backup
    create_backup_dir
    backup_application
    backup_configuration
    backup_logs
    save_service_status
    create_manifest
    compress_backup
    cleanup_old_backups
    list_backups

    print_header "Backup Complete"
    print_success "Backup created successfully: ${BACKUP_NAME}.tar.gz"

    echo ""
    echo -e "${BLUE}To restore this backup:${NC}"
    echo "  ./scripts/rollback.sh $BACKUP_NAME"

    echo ""
    echo -e "${BLUE}To list all backups:${NC}"
    echo "  ls -lth $BACKUP_BASE_DIR/"
}

# Run main function
main "$@"
