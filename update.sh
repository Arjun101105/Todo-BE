#!/bin/bash

###############################################################################
# Todo-BE Update/Redeploy Script
# Purpose: Zero-downtime updates after code changes
# Usage: bash update.sh
# Note: Run from EC2 instance as root
###############################################################################

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

APP_PATH="/opt/todo-api"
APP_NAME="todo-api"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root. Use: sudo bash update.sh"
    fi
}

update_code() {
    log_info "Updating code from repository..."
    cd "$APP_PATH"
    
    # Stash any local changes
    git stash 2>/dev/null || true
    
    # Pull latest
    git pull origin master || log_error "Failed to pull from repository"
    
    log_success "Code updated successfully"
}

update_dependencies() {
    log_info "Updating npm dependencies..."
    cd "$APP_PATH"
    
    npm install --production || log_error "Failed to install dependencies"
    
    log_success "Dependencies updated"
}

reload_app() {
    log_info "Reloading application with PM2 (zero-downtime)..."
    
    # Graceful reload - maintains connections during restart
    pm2 reload "$APP_NAME" || log_error "Failed to reload application"
    
    sleep 2
    
    log_success "Application reloaded successfully"
}

verify_health() {
    log_info "Verifying application health..."
    
    sleep 1
    
    # Check local health endpoint
    if curl -s http://localhost:3000/health | grep -q "UP" 2>/dev/null; then
        log_success "Application health check passed"
    else
        log_warning "Health check failed - checking PM2 status anyway"
    fi
}

show_status() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}            UPDATE COMPLETED SUCCESSFULLY                ${BLUE}║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}"
    pm2 status | grep "$APP_NAME" >&2 || true
    echo -e "${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} LATEST CHANGES:"
    cd "$APP_PATH"
    git log -1 --oneline || true
    echo -e "${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} VIEW LOGS: pm2 logs $APP_NAME"
    echo -e "${BLUE}║${NC}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

main() {
    log_info "Starting update process..."
    echo ""
    
    check_root
    
    # Backup current version
    log_info "Creating backup of current state..."
    cp -r "$APP_PATH" "${APP_PATH}.backup.$(date +%s)" 2>/dev/null || true
    
    # Update process
    update_code
    update_dependencies
    reload_app
    verify_health
    
    show_status
    
    log_success "Update completed successfully!"
}

main "$@"
