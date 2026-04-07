# Todo-BE EC2 Deployment Guide

Complete guide for deploying Todo-BE API on an EC2 instance with PM2, Nginx, and Let's Encrypt SSL.

---

## 📋 Pre-Deployment Checklist

### 1. **EC2 Instance Setup** ✓ Do this first
- [ ] Launch Ubuntu 20.04+ LTS instance (t2.micro or larger)
- [ ] Configure security group to allow:
  - Port **22** (SSH) - restricted to your IP
  - Port **80** (HTTP) - open to 0.0.0.0/0
  - Port **443** (HTTPS) - open to 0.0.0.0/0
- [ ] Assign/create Elastic IP (optional but recommended)
- [ ] SSH into instance: `ssh -i your-key.pem ubuntu@your-ec2-public-ip`

### 2. **Domain & DNS Configuration** ✓ Do this before running deploy script
- [ ] Create DNS A record: `api.taskflow.arjun10.tech` → EC2 Elastic IP
- [ ] Verify DNS resolves: `nslookup api.taskflow.arjun10.tech`
- [ ] Wait ~5-15 minutes for DNS propagation

### 3. **Environment File Preparation** ✓ Critical - must exist before deploy
Create `.env` file locally with:
```bash
# Database Configuration
MONGO_URI="mongodb+srv://username:password@cluster.mongodb.net/todo-db?retryWrites=true&w=majority"

# JWT Configuration (use strong random key)
JWT_SECRET="your-super-secret-key-at-least-32-characters-long"

# Server Configuration
PORT=3000
NODE_ENV=production

# CORS Configuration (Vercel frontend)
CORS_ORIGIN="https://taskflowwww.vercel.app"
```

**⚠️ Important:** 
- Generate `JWT_SECRET` securely: `openssl rand -base64 32`
- DO NOT commit `.env` to git
- Replace MongoDB connection string with your Atlas URI

### 4. **GitHub SSH Key** (Optional, for automated deployments)
```bash
# Generate SSH key on EC2
ssh-keygen -t ed25519 -C "your-email@example.com"

# Add public key to GitHub:
# Settings → Deploy keys → Add new key → paste output of:
cat ~/.ssh/id_ed25519.pub
```

---

## 🚀 Deployment Steps

### Step 1: Connect to EC2 Instance
```bash
ssh -i your-key.pem ubuntu@your-ec2-ip
sudo su -  # Switch to root (required for deploy script)
```

### Step 2: Prepare Environment File
```bash
cd /opt/todo-api  # Directory deploy script creates
cat > .env << 'EOF'
MONGO_URI="mongodb+srv://..."
JWT_SECRET="your-secret-key"
PORT=3000
NODE_ENV=production
CORS_ORIGIN="https://taskflowwww.vercel.app"
EOF

chmod 600 .env  # Restrict permissions
```

Or transfer pre-prepared `.env` from local machine:
```bash
# From your local machine:
scp -i your-key.pem .env ubuntu@your-ec2-ip:~/

# Then on EC2:
sudo mkdir -p /opt/todo-api
sudo cp ~/.env /opt/todo-api/.env
sudo chown -R ubuntu:ubuntu /opt/todo-api
```

### Step 3: Clone Repository & Prepare Deploy Script
```bash
cd /tmp
git clone https://github.com/Arjun101105/Todo-BE.git
cd Todo-BE
chmod +x deploy.sh
```

### Step 4: Run Deployment Script
```bash
sudo bash deploy.sh
```

**What the script does (automatically):**
- ✅ Updates system packages
- ✅ Installs Node.js 18.x
- ✅ Installs PM2 globally
- ✅ Clones repository to `/opt/todo-api`
- ✅ Installs npm dependencies
- ✅ Creates PM2 ecosystem configuration (clustering mode)
- ✅ Starts app with PM2
- ✅ Configures Nginx as reverse proxy
- ✅ Provisions Let's Encrypt SSL certificate
- ✅ Sets up auto-renewal for SSL
- ✅ Runs verification checks

**Deployment time:** ~5-10 minutes depending on internet speed

### Step 5: Verify Deployment
```bash
# Check PM2 status
pm2 status
pm2 logs todo-api

# Check Nginx
systemctl status nginx

# Test health endpoint (local)
curl http://localhost:3000/health

# Test via domain (after DNS propagation)
curl https://api.taskflow.arjun10.tech/health
```

---

## 🔍 Post-Deployment Verification

### Test API Endpoints

**1. Health Check**
```bash
curl https://api.taskflow.arjun10.tech/health
```
Expected response:
```json
{
  "status": "UP",
  "timestamp": "2026-04-07T10:30:45.123Z",
  "uptime": 124.56,
  "environment": "production"
}
```

**2. User Signup**
```bash
curl -X POST https://api.taskflow.arjun10.tech/user/signup \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "SecurePass123!"
  }'
```

**3. User Signin**
```bash
curl -X POST https://api.taskflow.arjun10.tech/user/signin \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "SecurePass123!"
  }'
```

### Verify CORS Configuration
```bash
curl -H "Origin: https://taskflowwww.vercel.app" \
  -v https://api.taskflow.arjun10.tech/health
```
Response should include:
```
Access-Control-Allow-Origin: https://taskflowwww.vercel.app
```

### Verify SSL Certificate
```bash
# Check certificate details
certbot certificates

# Test SSL strength
openssl s_client -connect api.taskflow.arjun10.tech:443

# Check expiry date
echo | openssl s_client -servername api.taskflow.arjun10.tech -connect api.taskflow.arjun10.tech:443 2>/dev/null | openssl x509 -noout -dates
```

### Check MongoDB Connection
```bash
# SSH into EC2 and check logs
pm2 logs todo-api | grep -i mongo

# Or make a request and watch logs
curl https://api.taskflow.arjun10.tech/user/signin -d "{}" 2>/dev/null &
pm2 logs todo-api
```

---

## 📊 Monitoring & Logs

### View Application Logs
```bash
# Real-time logs
pm2 logs todo-api

# Last 100 lines
pm2 logs todo-api --lines 100

# Specific instance (if clustering)
pm2 logs todo-api:0
pm2 logs todo-api:1
```

### View Nginx Logs
```bash
# Access log
tail -f /var/log/nginx/access.log

# Error log
tail -f /var/log/nginx/error.log

# Filter for specific domain
tail -f /var/log/nginx/access.log | grep api.taskflow
```

### Monitor System Resources
```bash
# PM2 monitoring dashboard
pm2 monit

# System resources
free -h
df -h
top
```

### Check PM2 Processes
```bash
# List all processes
pm2 list

# Detailed info on app
pm2 info todo-api

# Save current state (for recovery after reboot)
pm2 save
pm2 startup
```

---

## 🔄 Maintenance & Updates

### Update Application Code
```bash
cd /opt/todo-api

# Pull latest changes
git pull origin master

# Reinstall dependencies (if package.json changed)
npm install --production

# Graceful reload (zero-downtime)
pm2 reload todo-api

# Or restart if needed
pm2 restart todo-api

# Verify health
curl https://api.taskflow.arjun10.tech/health
```

### Update Environment Variables
```bash
# Edit .env
sudo nano /opt/todo-api/.env

# Restart app
pm2 restart todo-api
```

### Restart Services
```bash
# Restart app
pm2 restart todo-api

# Restart Nginx
systemctl reload nginx

# Restart all
pm2 restart all
systemctl reload nginx
```

### View Certificate Renewal Status
```bash
# Check renewal dates
certbot certificates

# Test renewal process (dry-run)
certbot renew --dry-run

# Force renewal (if needed)
certbot renew --force-renewal
```

---

## 🔐 Security Considerations

### 1. **Keep Systems Updated**
```bash
# Weekly system updates
apt-get update && apt-get upgrade -y
```

### 2. **Firewall Configuration**
```bash
# Check current security group in AWS Console
# Ensure:
# - SSH (22) is restricted to your IP only
# - HTTP (80) is open (for Let's Encrypt renewal)
# - HTTPS (443) is open to all
```

### 3. **Monitor SSL Certificate**
```bash
# Automatic renewal runs daily
# But you can check:
certbot certificates

# Renewal will happen automatically 30 days before expiry
```

### 4. **Backup Environment Variables**
```bash
# Store .env securely (NOT in git)
# Consider using AWS Secrets Manager or Vault for production
```

### 5. **API Authentication**
- Ensure `JWT_SECRET` is strong (30+ characters, random)
- Use strong passwords in MongoDB Atlas
- Consider rate limiting (already configured in Nginx)
- Enable CORS only for your Vercel domain

---

## ❌ Troubleshooting

### Issue: App Not Starting
```bash
# Check PM2 logs
pm2 logs todo-api

# Check for errors
pm2 monit

# Manually test Node.js
cd /opt/todo-api && node index.js
```

### Issue: Nginx Won't Start
```bash
# Check config syntax
nginx -t

# View error log
tail -f /var/log/nginx/error.log

# Test connection locally
systemctl status nginx
```

### Issue: SSL Certificate Not Working
```bash
# Check cert status
certbot certificates

# Verify domain DNS
nslookup api.taskflow.arjun10.tech

# Check Nginx config
cat /etc/nginx/sites-enabled/todo-api
```

### Issue: MongoDB Connection Failed
```bash
# Check .env has MONGO_URI
cat /opt/todo-api/.env

# Test MongoDB URI manually
node -e "require('mongoose').connect(process.env.MONGO_URI, {useNewUrlParser: true}).then(() => console.log('Connected!')).catch(e => console.error(e))"

# Check network access in MongoDB Atlas
# - IP Whitelist must include EC2 IP or 0.0.0.0/0
```

### Issue: CORS Errors
```bash
# Check CORS_ORIGIN in .env
cat /opt/todo-api/.env | grep CORS

# Should match Vercel frontend URL
# Current: https://taskflowwww.vercel.app

# Verify Nginx headers
curl -I https://api.taskflow.arjun10.tech
```

### Issue: High Memory/CPU Usage
```bash
# Check which process is consuming resources
top
pm2 monit

# Check logs for loops/errors
pm2 logs todo-api

# Restart app
pm2 restart todo-api

# If issue persists, check for memory leaks
pm2 info todo-api
```

---

## 📞 Useful Commands Reference

```bash
# PM2
pm2 list                    # List all processes
pm2 status                  # Status of all processes
pm2 logs app-name          # View logs
pm2 monit                  # Monitor dashboard
pm2 restart app-name       # Restart app
pm2 stop app-name          # Stop app
pm2 delete app-name        # Remove app
pm2 save                   # Save current state
pm2 startup                # Enable auto-start

# Nginx
systemctl start nginx       # Start Nginx
systemctl stop nginx        # Stop Nginx
systemctl restart nginx     # Restart Nginx
systemctl reload nginx      # Reload (no connection drop)
systemctl status nginx      # Check status
nginx -t                   # Test config

# SSL Certificate
certbot certificates       # List certificates
certbot renew             # Renew certificates
certbot renew --dry-run   # Test renewal
certbot delete --cert-name domain # Delete cert

# System
cd /opt/todo-api          # Project directory
tail -f /var/log/syslog   # System logs
free -h                   # Memory usage
df -h                     # Disk usage
```

---

## 🎯 Next Steps

1. ✅ Run deployment script
2. ✅ Verify all endpoints working
3. ✅ Test from Vercel frontend (https://taskflowwww.vercel.app)
4. ✅ Set up monitoring/alerts (optional)
5. ✅ Create backup of .env file (offline storage)
6. ✅ Document any custom environment variables
7. ✅ Schedule regular review of logs and updates

---

## 📝 Deployment Checklist

- [ ] EC2 instance running (Ubuntu 20.04+)
- [ ] Security groups configured (22, 80, 443)
- [ ] DNS record created and resolving
- [ ] .env file prepared with all variables
- [ ] Deploy script executed successfully
- [ ] Health endpoint responding (http://localhost:3000/health)
- [ ] HTTPS working (https://api.taskflow.arjun10.tech/health)
- [ ] PM2 showing "online" status
- [ ] Nginx configured and running
- [ ] SSL certificate issued by Let's Encrypt
- [ ] Auto-renewal cron job active
- [ ] Tested API endpoints (signup/signin)
- [ ] CORS verified for Vercel frontend
- [ ] MongoDB connection working
- [ ] Logs accessible and clean
- [ ] Post-reboot verification complete

---

**Last Updated:** April 7, 2026  
**Questions?** Check logs first: `pm2 logs todo-api`
