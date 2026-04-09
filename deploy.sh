#!/bin/bash

###############################################################################
# Todo-BE EC2 Deployment Script
# Purpose: Automated setup of Node.js API with PM2, Nginx, and Let's Encrypt SSL
# Usage: bash deploy.sh
# Requirements: Fresh Ubuntu 20.04+ LTS instance with .env file pre-staged
###############################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="${REPO_URL:-https://github.com/Arjun101105/Todo-BE.git}"
APP_PATH="/opt/todo-api"
APP_NAME="todo-api"
DOMAIN="api.taskflow.arjun10.tech"
NODE_VERSION="18"
GITHUB_USER="${GITHUB_USER:-}"  # Optional: for SSH key deployment

###############################################################################
# Utility Functions
###############################################################################

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
        log_error "This script must be run as root. Use: sudo bash deploy.sh"
    fi
}

check_prerequisite() {
    # Check if .env exists at expected location
    if [[ -f "$APP_PATH/.env" ]]; then
        log_success ".env file found at $APP_PATH/.env"
        return 0
    fi
    
    local env_file=""
    
    # Check if .env exists in current working directory
    if [[ -f ".env" ]]; then
        env_file=".env"
        log_info ".env found in current directory"
    fi
    
    # Check if .env exists in /tmp (sometimes copied there)
    if [[ -z "$env_file" ]] && [[ -f "/tmp/.env" ]]; then
        env_file="/tmp/.env"
        log_info ".env found in /tmp directory"
    fi
    
    # Check if .env exists in /root home
    if [[ -z "$env_file" ]] && [[ -f "/root/.env" ]]; then
        env_file="/root/.env"
        log_info ".env found in /root home directory"
    fi
    
    # If we found the file, copy it to app directory
    if [[ -n "$env_file" ]]; then
        log_info "Copying .env from $env_file to $APP_PATH/.env"
        cp "$env_file" "$APP_PATH/.env"
        chown root:root "$APP_PATH/.env"
        chmod 600 "$APP_PATH/.env"
        log_success ".env successfully copied to $APP_PATH/.env"
        return 0
    fi
    
    # .env not found anywhere
    log_error ".env file not found in any of: current dir, /tmp, /root - create .env and try again"
}

###############################################################################
# Phase 1: System Dependencies
###############################################################################

install_system_dependencies() {
    log_info "Installing system dependencies..."
    apt-get update
    apt-get upgrade -y
    
    # Install required packages
    apt-get install -y \
        curl \
        wget \
        git \
        build-essential \
        python3 \
        certbot \
        python3-certbot-nginx \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        nginx
    
    log_success "System dependencies installed"
}

install_nodejs() {
    log_info "Installing Node.js ${NODE_VERSION}.x..."
    
    # Remove old Node.js if exists
    apt-get remove -y nodejs npm 2>/dev/null || true
    
    # Add NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
    
    # Install Node.js
    apt-get install -y nodejs
    
    # Verify installation
    NODE_INSTALLED=$(node --version)
    log_success "Node.js installed: $NODE_INSTALLED"
}

install_pm2_global() {
    log_info "Installing PM2 globally..."
    npm install -g pm2@latest
    
    # Enable PM2 startup hook
    pm2 startup systemd -u root --hp /root >/dev/null 2>&1 || true
    
    log_success "PM2 installed and configured for startup"
}

###############################################################################
# Phase 2: Project Setup
###############################################################################

setup_project_directory() {
    log_info "Setting up project directory..."
    
    if [[ ! -d "$APP_PATH" ]]; then
        log_info "Cloning repository to $APP_PATH..."
        git clone "$REPO_URL" "$APP_PATH"
    else
        log_info "Updating existing repository at $APP_PATH..."
        cd "$APP_PATH"
        git pull origin master
    fi
    
    cd "$APP_PATH"
    log_success "Project directory ready at $APP_PATH"
}

install_project_dependencies() {
    log_info "Installing project dependencies..."
    cd "$APP_PATH"
    
    npm install --production
    
    log_success "Project dependencies installed"
}

validate_environment() {
    log_info "Validating environment configuration..."
    
    # Check required env vars
    if ! grep -q "MONGO_URI=" "$APP_PATH/.env"; then
        log_error "MONGO_URI not found in .env file"
    fi
    
    if ! grep -q "JWT_SECRET=" "$APP_PATH/.env"; then
        log_error "JWT_SECRET not found in .env file"
    fi
    
    # Set default values if not present
    if ! grep -q "NODE_ENV=" "$APP_PATH/.env"; then
        echo "NODE_ENV=production" >> "$APP_PATH/.env"
    else
        sed -i 's/NODE_ENV=.*/NODE_ENV=production/' "$APP_PATH/.env"
    fi
    
    if ! grep -q "PORT=" "$APP_PATH/.env"; then
        echo "PORT=3000" >> "$APP_PATH/.env"
    fi
    
    if ! grep -q "CORS_ORIGIN=" "$APP_PATH/.env"; then
        echo "CORS_ORIGIN=https://taskflowwww.vercel.app" >> "$APP_PATH/.env"
    fi
    
    log_success "Environment configuration validated"
}

###############################################################################
# Phase 3: PM2 Configuration
###############################################################################

create_pm2_ecosystem() {
    log_info "Creating PM2 ecosystem configuration..."
    
    cat > "$APP_PATH/ecosystem.config.js" << 'EOF'
module.exports = {
  apps: [
    {
      name: 'todo-api',
      script: './index.js',
      cwd: '/opt/todo-api',
      instances: 'max',              // Use all CPU cores for clustering
      exec_mode: 'cluster',          // Clustering mode for load balancing
      env: {
        NODE_ENV: 'production',
        PORT: 3000
      },
      merge_logs: true,              // Merge logs from all instances
      error_file: '/var/log/pm2/error.log',
      out_file: '/var/log/pm2/output.log',
      log_file: '/var/log/pm2/combined.log',
      time: true,                    // Timestamp in logs
      watch: false,                  // Don't watch for changes in production
      max_memory_restart: '500M',    // Restart if exceeds 500MB
      autorestart: true,
      max_restarts: 10,
      min_uptime: '10s',
      listen_timeout: 3000,
      kill_timeout: 5000,
      ignore_watch: ['node_modules', '.git', 'logs'],
      env_production: {
        NODE_ENV: 'production'
      }
    }
  ]
};
EOF
    
    log_success "PM2 ecosystem configuration created"
}

start_pm2() {
    log_info "Starting application with PM2..."
    
    cd "$APP_PATH"
    
    # Stop any existing instances
    pm2 delete "$APP_NAME" 2>/dev/null || true
    sleep 1
    
    # Start with ecosystem file
    pm2 start ecosystem.config.js --env production
    
    # Save PM2 state
    pm2 save
    
    # Wait for app to be ready
    sleep 3
    
    # Check status
    if pm2 list | grep -q "$APP_NAME"; then
        log_success "Application started with PM2"
        pm2 status
    else
        log_error "Failed to start application with PM2"
    fi
}

###############################################################################
# Phase 4: Nginx Configuration
###############################################################################

create_rate_limiting_config() {
    log_info "Creating rate limiting configuration..."
    
    mkdir -p /etc/nginx/conf.d
    
    cat > "/etc/nginx/conf.d/rate-limiting.conf" << 'EOF'
# Rate limiting zone (defined at http level, usable in server blocks)
limit_req_zone $binary_remote_addr zone=api_rate:10m rate=100r/s;
EOF
    
    log_success "Rate limiting configuration created"
}



create_nginx_config() {
    log_info "Creating production HTTPS Nginx configuration..."
    
    cat > "/etc/nginx/sites-available/todo-api" << 'EOF'
# Upstream for PM2 clustering
upstream todo_api_upstream {
    least_conn;
    server 127.0.0.1:3000;
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name api.taskflow.arjun10.tech;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS server block
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name api.taskflow.arjun10.tech;
    
    # SSL certificates (will be updated by certbot)
    ssl_certificate /etc/letsencrypt/live/api.taskflow.arjun10.tech/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.taskflow.arjun10.tech/privkey.pem;
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # HSTS - Force HTTPS for 1 year
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css text/xml text/javascript 
               application/x-javascript application/xml+rss 
               application/json application/javascript;
    gzip_min_length 1000;
    
    # Rate limiting (zone defined in /etc/nginx/conf.d/rate-limiting.conf)
    limit_req zone=api_rate burst=200 nodelay;
    
    # Timeouts
    client_body_timeout 30s;
    client_header_timeout 30s;
    keepalive_timeout 65s;
    send_timeout 30s;
    
    # Reverse proxy to Node.js app
    location / {
        proxy_pass http://todo_api_upstream;
        proxy_http_version 1.1;
        
        # Headers
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # Buffering
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        proxy_pass http://todo_api_upstream;
        proxy_set_header Host $host;
    }
    
    # Deny access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    location ~ ~$ {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF
    
    log_success "Nginx configuration created"
}

enable_nginx_site() {
    log_info "Enabling Nginx site..."
    
    # Create symlink
    ln -sf /etc/nginx/sites-available/todo-api /etc/nginx/sites-enabled/todo-api
    
    # Remove default site if exists
    rm -f /etc/nginx/sites-enabled/default
    
    # Test Nginx configuration
    if nginx -t; then
        # Use restart instead of reload since Nginx may have been stopped during cert setup
        systemctl restart nginx
        log_success "Nginx configuration enabled and restarted"
    else
        log_error "Nginx configuration test failed. Please check /etc/nginx/sites-available/todo-api"
    fi
}

enable_nginx_service() {
    log_info "Enabling Nginx service..."
    systemctl enable nginx
    systemctl restart nginx
    log_success "Nginx service enabled and running"
}

###############################################################################
# Phase 5: SSL Certificate
###############################################################################

provision_ssl_certificate() {
    log_info "Provisioning Let's Encrypt SSL certificate for $DOMAIN..."
    
    # Step 1: Stop Nginx (required for --standalone mode)
    log_info "Step 1: Stopping Nginx for certificate provisioning..."
    systemctl stop nginx
    sleep 2
    
    # Step 2: Request certificate using standalone mode (proven reliable)
    log_info "Step 2: Requesting certificate from Let's Encrypt (standalone mode)..."
    certbot certonly --standalone \
        -d "$DOMAIN" \
        --email admin@arjun10.tech \
        --agree-tos \
        --non-interactive || log_error "Certificate provisioning failed - ensure domain DNS is properly configured"
    
    # Step 3: Verify certificate was created
    if [[ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
        log_error "SSL certificate not found after provisioning. Check DNS and try again."
    fi
    
    log_success "SSL certificate provisioned successfully"
    
    # Nginx will be restarted in the next phase
}

setup_ssl_auto_renewal() {
    log_info "Setting up automatic SSL certificate renewal..."
    
    # Create renewal hook for Nginx reload
    mkdir -p /etc/letsencrypt/renewal-hooks/post
    
    cat > "/etc/letsencrypt/renewal-hooks/post/nginx-reload.sh" << 'EOF'
#!/bin/bash
systemctl reload nginx
EOF
    
    chmod +x /etc/letsencrypt/renewal-hooks/post/nginx-reload.sh
    
    # Enable certbot timer
    systemctl enable certbot.timer
    systemctl start certbot.timer
    
    log_success "SSL auto-renewal configured (daily check via certbot.timer)"
}

###############################################################################
# Phase 6: Verification & Health Checks
###############################################################################

verify_installation() {
    log_info "Running installation verification..."
    
    # Check Node.js
    if command -v node &> /dev/null; then
        log_success "✓ Node.js $(node --version) installed"
    else
        log_error "Node.js not found"
    fi
    
    # Check PM2
    if pm2 list 2>/dev/null | grep -q "$APP_NAME"; then
        log_success "✓ PM2 application '$APP_NAME' is running"
    else
        log_warning "⚠ PM2 application might not be running"
    fi
    
    # Check Nginx
    if systemctl is-active --quiet nginx; then
        log_success "✓ Nginx is running"
    else
        log_error "Nginx is not running"
    fi
    
    # Check port 3000
    if netstat -tuln 2>/dev/null | grep -q :3000 || ss -tuln 2>/dev/null | grep -q :3000; then
        log_success "✓ Port 3000 is listening"
    else
        log_warning "⚠ Port 3000 might not be listening"
    fi
    
    # Check health endpoint (localhost)
    sleep 2
    if curl -s http://localhost:3000/health | grep -q "UP" 2>/dev/null; then
        log_success "✓ Health endpoint responding (http://localhost:3000/health)"
    else
        log_warning "⚠ Health endpoint not responding yet (app may still be starting)"
    fi
}

display_summary() {
    log_info "Deployment summary:"
    
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}            TODO-BE DEPLOYMENT COMPLETED                ${BLUE}║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC} Application Name:   $APP_NAME"
    echo -e "${BLUE}║${NC} Application Path:   $APP_PATH"
    echo -e "${BLUE}║${NC} Local Port:         3000 (Nginx → 80/443)"
    echo -e "${BLUE}║${NC} Domain:             https://$DOMAIN"
    echo -e "${BLUE}║${NC} PM2 Status:         $(pm2 list 2>/dev/null | grep -c "$APP_NAME") instance(s)"
    echo -e "${BLUE}║${NC} Nginx:              $(systemctl is-active nginx)"
    echo -e "${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} NEXT STEPS:"
    echo -e "${BLUE}║${NC} 1. Verify domain DNS: nslookup api.taskflow.arjun10.tech"
    echo -e "${BLUE}║${NC} 2. Test HTTPS: curl https://$DOMAIN/health"
    echo -e "${BLUE}║${NC} 3. Check logs: pm2 logs $APP_NAME"
    echo -e "${BLUE}║${NC} 4. Monitor: pm2 monit"
    echo -e "${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} USEFUL COMMANDS:"
    echo -e "${BLUE}║${NC} • View PM2 status:   pm2 status"
    echo -e "${BLUE}║${NC} • View logs:         pm2 logs $APP_NAME"
    echo -e "${BLUE}║${NC} • Restart app:       pm2 restart $APP_NAME"
    echo -e "${BLUE}║${NC} • Stop app:          pm2 stop $APP_NAME"
    echo -e "${BLUE}║${NC} • Nginx status:      systemctl status nginx"
    echo -e "${BLUE}║${NC} • SSL status:        certbot certificates"
    echo -e "${BLUE}║${NC}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

###############################################################################
# Main Execution
###############################################################################

main() {
    log_info "Starting Todo-BE deployment..."
    echo ""
    
    check_root
    
    # Phase 1: System Dependencies
    log_info "=== PHASE 1: System Dependencies ==="
    install_system_dependencies
    install_nodejs
    install_pm2_global
    echo ""
    
    # Phase 2: Project Setup
    log_info "=== PHASE 2: Project Setup ==="
    check_prerequisite
    setup_project_directory
    validate_environment
    install_project_dependencies
    echo ""
    
    # Phase 3: PM2 Configuration
    log_info "=== PHASE 3: PM2 Configuration ==="
    create_pm2_ecosystem
    start_pm2
    echo ""
    
    # Phase 4: Nginx Configuration (rate limiting only)
    log_info "=== PHASE 4: Nginx Configuration ==="
    create_rate_limiting_config
    echo ""
    
    # Phase 5: SSL Certificate (standalone mode - stops nginx temporarily)
    log_info "=== PHASE 5: SSL Certificate Setup ==="
    provision_ssl_certificate
    echo ""
    
    # Phase 6: Final Nginx Configuration (with HTTPS)
    log_info "=== PHASE 6: Applying Final HTTPS Configuration ==="
    create_nginx_config
    enable_nginx_site
    enable_nginx_service
    echo ""
    
    # Phase 7: SSL Auto-renewal
    log_info "=== PHASE 7: Setting up SSL Auto-renewal ==="
    setup_ssl_auto_renewal
    echo ""
    
    # Phase 6: Verification
    log_info "=== PHASE 6: Verification ==="
    verify_installation
    echo ""
    
    # Summary
    display_summary
    
    log_success "Deployment completed successfully!"
}

# Run main function
main "$@"
