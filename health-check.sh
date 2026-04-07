#!/bin/bash

###############################################################################
# Todo-BE Health Check & Monitoring Script
# Purpose: Verify deployment health and API availability
# Usage: bash health-check.sh
# Can be run from local machine or EC2 instance
###############################################################################

# Configuration
DOMAIN="${DOMAIN:-api.taskflow.arjun10.tech}"
FRONTENDS=(
    "https://taskflowwww.vercel.app"
)

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

log_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED_CHECKS++))
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED_CHECKS++))
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

###############################################################################
# DNS Checks
###############################################################################

check_dns_resolution() {
    echo ""
    echo -e "${BLUE}=== DNS Resolution ===${NC}"
    ((TOTAL_CHECKS++))
    
    if nslookup "$DOMAIN" > /dev/null 2>&1; then
        IP=$(dig +short "$DOMAIN" | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | head -1)
        log_pass "DNS resolves to: $IP"
    else
        log_fail "DNS resolution failed for $DOMAIN"
    fi
}

###############################################################################
# SSL/TLS Certificate Checks
###############################################################################

check_ssl_certificate() {
    echo ""
    echo -e "${BLUE}=== SSL/TLS Certificate ===${NC}"
    
    # Check certificate validity
    ((TOTAL_CHECKS++))
    CERT_DATA=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null)
    
    if [[ ! -z "$CERT_DATA" ]]; then
        log_pass "SSL certificate is valid"
        
        # Extract expiry date
        EXPIRY=$(echo "$CERT_DATA" | openssl x509 -noout -dates 2>/dev/null | grep "notAfter" | cut -d= -f2)
        log_info "Certificate expires: $EXPIRY"
        
        # Check days until expiry
        ((TOTAL_CHECKS++))
        EXPIRY_DATE=$(date -d "$EXPIRY" +%s)
        CURRENT_DATE=$(date +%s)
        DAYS_UNTIL_EXPIRY=$(( ($EXPIRY_DATE - $CURRENT_DATE) / 86400 ))
        
        if [[ $DAYS_UNTIL_EXPIRY -gt 30 ]]; then
            log_pass "Certificate will expire in $DAYS_UNTIL_EXPIRY days"
        elif [[ $DAYS_UNTIL_EXPIRY -gt 0 ]]; then
            log_warning "Certificate will expire in only $DAYS_UNTIL_EXPIRY days!"
        else
            log_fail "Certificate has expired!"
        fi
        
        # Check cipher strength
        ((TOTAL_CHECKS++))
        CIPHER=$(echo "$CERT_DATA" | grep "Cipher" | head -1)
        if [[ $CIPHER == *"AES"* ]]; then
            log_pass "Strong encryption cipher: $CIPHER"
        else
            log_warning "Cipher: $CIPHER"
        fi
    else
        log_fail "Could not retrieve SSL certificate"
    fi
}

###############################################################################
# API Health Checks
###############################################################################

check_health_endpoint() {
    echo ""
    echo -e "${BLUE}=== API Health ===${NC}"
    ((TOTAL_CHECKS++))
    
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/health")
    if [[ "$RESPONSE" == "200" ]]; then
        log_pass "Health endpoint responding (HTTP $RESPONSE)"
    else
        log_fail "Health endpoint returned HTTP $RESPONSE"
    fi
}

check_health_json() {
    echo ""
    ((TOTAL_CHECKS++))
    
    HEALTH=$(curl -s "https://$DOMAIN/health")
    if echo "$HEALTH" | grep -q '"status":"UP"'; then
        log_pass "API status is UP"
        
        # Extract details
        STATUS=$(echo "$HEALTH" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        UPTIME=$(echo "$HEALTH" | grep -o '"uptime":[0-9.]*' | cut -d':' -f2)
        ENV=$(echo "$HEALTH" | grep -o '"environment":"[^"]*"' | cut -d'"' -f4)
        
        log_info "Environment: $ENV, Uptime: ${UPTIME}s"
    else
        log_fail "Failed to parse health response"
    fi
}

check_authentication_endpoint() {
    echo ""
    ((TOTAL_CHECKS++))
    
    # Test signin endpoint (should respond with error, not server error)
    RESPONSE=$(curl -s -X POST "https://$DOMAIN/user/signin" \
        -H "Content-Type: application/json" \
        -d '{}' \
        -o /dev/null -w "%{http_code}")
    
    if [[ "$RESPONSE" =~ ^(400|401|422)$ ]]; then
        log_pass "Authentication endpoint accessible (HTTP $RESPONSE)"
    elif [[ "$RESPONSE" == "200" ]]; then
        log_pass "Authentication endpoint accessible (HTTP $RESPONSE)"
    elif [[ "$RESPONSE" =~ ^5 ]]; then
        log_fail "Authentication endpoint returned server error (HTTP $RESPONSE)"
    else
        log_warning "Authentication endpoint returned HTTP $RESPONSE"
    fi
}

###############################################################################
# Response Time Checks
###############################################################################

check_response_time() {
    echo ""
    echo -e "${BLUE}=== Response Time ===${NC}"
    ((TOTAL_CHECKS++))
    
    # Measure response time
    RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" "https://$DOMAIN/health")
    RESPONSE_MS=$(echo "$RESPONSE_TIME * 1000" | bc | cut -d'.' -f1)
    
    if [[ $RESPONSE_MS -lt 500 ]]; then
        log_pass "Response time: ${RESPONSE_MS}ms (excellent)"
    elif [[ $RESPONSE_MS -lt 1000 ]]; then
        log_pass "Response time: ${RESPONSE_MS}ms (good)"
    elif [[ $RESPONSE_MS -lt 2000 ]]; then
        log_warning "Response time: ${RESPONSE_MS}ms (acceptable)"
    else
        log_fail "Response time: ${RESPONSE_MS}ms (slow)"
    fi
}

###############################################################################
# CORS Configuration Checks
###############################################################################

check_cors_headers() {
    echo ""
    echo -e "${BLUE}=== CORS Configuration ===${NC}"
    
    for FRONTEND in "${FRONTENDS[@]}"; do
        ((TOTAL_CHECKS++))
        
        CORS=$(curl -s -I \
            -H "Origin: $FRONTEND" \
            "https://$DOMAIN/health" | grep -i "access-control-allow-origin" || true)
        
        if [[ $CORS == *"$FRONTEND"* ]]; then
            log_pass "CORS configured for: $FRONTEND"
        else
            log_warning "CORS not configured for frontend origin (may need update)"
        fi
    done
}

###############################################################################
# Security Headers Checks
###############################################################################

check_security_headers() {
    echo ""
    echo -e "${BLUE}=== Security Headers ===${NC}"
    
    HEADERS=$(curl -s -I "https://$DOMAIN/health")
    
    # HSTS
    ((TOTAL_CHECKS++))
    if echo "$HEADERS" | grep -qi "strict-transport-security"; then
        log_pass "HSTS header present"
    else
        log_fail "HSTS header missing"
    fi
    
    # X-Frame-Options
    ((TOTAL_CHECKS++))
    if echo "$HEADERS" | grep -qi "x-frame-options"; then
        log_pass "X-Frame-Options header present"
    else
        log_fail "X-Frame-Options header missing"
    fi
    
    # X-Content-Type-Options
    ((TOTAL_CHECKS++))
    if echo "$HEADERS" | grep -qi "x-content-type-options"; then
        log_pass "X-Content-Type-Options header present"
    else
        log_fail "X-Content-Type-Options header missing"
    fi
}

###############################################################################
# EC2 Instance Checks (requires SSH access)
###############################################################################

check_pm2_status() {
    echo ""
    echo -e "${BLUE}=== PM2 Process Status ===${NC}"
    
    if command -v pm2 &> /dev/null; then
        ((TOTAL_CHECKS++))
        if pm2 list 2>/dev/null | grep -q "todo-api.*online"; then
            log_pass "PM2 application is online"
            pm2 status 2>/dev/null | head -5 || true
        else
            log_warning "PM2 status unavailable (remote instance?) - use SSH to check"
        fi
    else
        log_info "PM2 not available locally (expected if running from local machine)"
    fi
}

check_nginx_status() {
    echo ""
    echo -e "${BLUE}=== Nginx Status ===${NC}"
    
    if command -v systemctl &> /dev/null; then
        ((TOTAL_CHECKS++))
        if systemctl is-active --quiet nginx; then
            log_pass "Nginx is running"
        else
            log_warning "Nginx status unavailable (remote instance?) - use SSH to check"
        fi
    else
        log_info "Nginx status unavailable (expected if running from local machine)"
    fi
}

###############################################################################
# Summary Report
###############################################################################

print_summary() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}           HEALTH CHECK REPORT - $(date '+%Y-%m-%d %H:%M:%S')        ${BLUE}║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC} Domain:        $DOMAIN"
    echo -e "${BLUE}║${NC} Total Checks:  $TOTAL_CHECKS"
    echo -e "${BLUE}║${NC} Passed:        ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "${BLUE}║${NC} Failed:        ${RED}$FAILED_CHECKS${NC}"
    echo -e "${BLUE}║${NC}"
    
    if [[ $FAILED_CHECKS -eq 0 ]]; then
        echo -e "${BLUE}║${NC} ${GREEN}Status: ALL SYSTEMS OPERATIONAL ✓${NC}"
    elif [[ $FAILED_CHECKS -le 2 ]]; then
        echo -e "${BLUE}║${NC} ${YELLOW}Status: OPERATIONAL WITH WARNINGS ⚠${NC}"
    else
        echo -e "${BLUE}║${NC} ${RED}Status: ISSUES DETECTED ✗${NC}"
    fi
    
    echo -e "${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} RECOMMENDATIONS:"
    
    if [[ $FAILED_CHECKS -eq 0 ]]; then
        echo -e "${BLUE}║${NC} ✓ Deployment is healthy and ready for use"
    else
        echo -e "${BLUE}║${NC} ⚠ Review failed checks and troubleshoot"
        echo -e "${BLUE}║${NC}   See DEPLOYMENT.md for troubleshooting guide"
    fi
    
    echo -e "${BLUE}║${NC}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

###############################################################################
# Main Execution
###############################################################################

main() {
    echo -e "${BLUE}Starting health check for $DOMAIN...${NC}\n"
    
    # DNS checks
    check_dns_resolution
    
    # SSL/TLS checks
    check_ssl_certificate
    
    # API checks
    check_health_endpoint
    check_health_json
    check_authentication_endpoint
    
    # Performance checks
    check_response_time
    
    # Security checks
    check_cors_headers
    check_security_headers
    
    # Instance checks
    check_pm2_status
    check_nginx_status
    
    # Print summary
    print_summary
    
    # Exit with appropriate code
    if [[ $FAILED_CHECKS -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
