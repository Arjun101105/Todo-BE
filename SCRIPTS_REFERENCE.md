# Todo-BE Deployment Scripts - Quick Reference

Complete automated deployment for Todo-BE API on EC2 with PM2, Nginx, and Let's Encrypt SSL.

---

## 📦 What's Included

| File | Purpose | When to Use |
|------|---------|-----------|
| **deploy.sh** | Main deployment script | Initial setup on EC2 (one-time) |
| **update.sh** | Zero-downtime code updates | After git push with new code |
| **health-check.sh** | Verify deployment health | Daily monitoring or troubleshooting |
| **DEPLOYMENT.md** | Complete deployment guide | Reference documentation |
| **ecosystem.config.js** | PM2 configuration (auto-generated) | Created by deploy.sh, customize if needed |
| **.env.sample** | Environment template | Copy to .env and fill values |

---

## 🚀 Quick Start

### Prerequisites
- Ubuntu 20.04+ LTS EC2 instance
- Domain pointing to EC2 IP (api.taskflow.arjun10.tech)
- .env file with MongoDB URI and JWT secret

### Step 1: SSH into EC2
```bash
ssh -i your-key.pem ubuntu@your-ec2-ip
sudo su -  # Become root
```

### Step 2: Prepare Environment
```bash
# Transfer .env file OR create it
scp -i your-key.pem .env ubuntu@your-ec2-ip:~/
sudo mkdir -p /opt/todo-api
sudo cp ~/.env /opt/todo-api/.env
```

### Step 3: Run Deployment
```bash
cd /tmp
git clone https://github.com/Arjun101105/Todo-BE.git
cd Todo-BE
chmod +x deploy.sh update.sh health-check.sh
sudo bash deploy.sh
```

**Time:** ~5-10 minutes, then auto-start on reboot

### Step 4: Verify
```bash
curl https://api.taskflow.arjun10.tech/health
```

---

## 🛠️ Scripts in Detail

### deploy.sh (Initial Setup)
**What it does:**
- Installs Node.js 18+, PM2, Nginx, Certbot
- Clones your repository
- Configures PM2 with clustering (auto-scale to CPU cores)
- Sets up Nginx reverse proxy (port 80/443)
- Provisions SSL certificate from Let's Encrypt
- Configures auto-renewal for SSL
- Sets up auto-start on EC2 reboot

**Usage:**
```bash
sudo bash deploy.sh
```

**Output:** 
- App running at `https://api.taskflow.arjun10.tech`
- PM2 managing process (auto-restart on crash)
- Info displayed with next steps

---

### update.sh (Code Updates)
**What it does:**
- Pulls latest code from GitHub
- Installs npm dependencies
- Gracefully reloads app in PM2 (zero-downtime)
- Verifies health endpoint
- Creates timestamped backups

**Usage:**
```bash
sudo bash update.sh
```

**When to use:**
After pushing code changes to GitHub
- No downtime for users
- Previous version remains if rollback needed
- Takes ~30 seconds

---

### health-check.sh (Monitoring)
**What it does:**
- DNS resolution check
- SSL certificate validation (expiry, cipher strength)
- API health endpoint test
- Response time measurement
- CORS header verification
- Security headers audit
- PM2/Nginx status (if run locally on EC2)

**Usage:**
```bash
# On EC2
bash health-check.sh

# From local machine
DOMAIN=api.taskflow.arjun10.tech bash health-check.sh
```

**Output:** Color-coded pass/fail report with recommendations

---

### .env.sample → .env
**Template with all required variables:**
```bash
# Database
MONGO_URI="mongodb+srv://user:pass@cluster.mongodb.net/todo-db"

# JWT (use: openssl rand -base64 32)
JWT_SECRET="your-secret-key-min-32-chars"

# Server
PORT=3000
NODE_ENV=production

# CORS (allow Vercel frontend)
CORS_ORIGIN="https://taskflowwww.vercel.app"
```

**Setup:**
```bash
cp .env.sample .env
# Edit .env with real values
chmod 600 .env  # Restrict permissions
```

---

## 📊 Architecture

```
Client Browser (Vercel Frontend)
    ↓ HTTPS
api.taskflow.arjun10.tech:443
    ↓
Nginx (SSL termination, reverse proxy)
    ↓ HTTP
localhost:3000
    ↓
PM2 Process Manager (clustering, auto-restart)
    ├─ Node.js Instance 1
    ├─ Node.js Instance 2
    ├─ Node.js Instance 3  (auto-scaled to CPU cores)
    └─ Node.js Instance N
    ↓
MongoDB Atlas (Connection pooling)
```

---

## 🔄 Common Workflows

### Deploy New Version
```bash
# On local machine
git push origin master

# On EC2
sudo bash update.sh
```

### Monitor Application
```bash
pm2 logs todo-api           # Real-time logs
pm2 monit                   # Dashboard
pm2 status                  # Process status
```

### Check Health
```bash
bash health-check.sh        # Automated report
curl https://api.taskflow.arjun10.tech/health  # Manual
```

### View Nginx Logs
```bash
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

### View SSL Certificate
```bash
certbot certificates
openssl s_client -connect api.taskflow.arjun10.tech:443
```

### Restart Application
```bash
pm2 restart todo-api
```

---

## ⚠️ Important Considerations

### SSL Certificate
- **Auto-renewed:** Certbot renews 30 days before expiry
- **Manual check:** `certbot certificates`
- **Force renewal:** `certbot renew --force-renewal`

### PM2 Clustering
- **Instances:** One per CPU core (auto-detected)
- **Load balancing:** Built-in circular robin
- **Memory:** Each instance ~50-100MB
- **Restart:** Auto-restarts if instance crashes

### Database
- Uses MongoDB Atlas (cloud-managed)
- No backups needed (Atlas handles this)
- Ensure IP whitelist includes EC2 IP

### Security
- HTTPS enforced (HTTP redirects to HTTPS)
- Security headers included (HSTS, X-Frame-Options, etc.)
- Rate limiting in Nginx (100 req/s)
- CORS restricted to Vercel frontend
- JWT authentication on all API endpoints

---

## 🐛 Troubleshooting

### App Won't Start
```bash
pm2 logs todo-api           # Check logs
pm2 monit                   # Monitor processes
cd /opt/todo-api && node index.js  # Test manually
```

### SSL Certificate Issues
```bash
certbot certificates        # Check certs
certbot renew --dry-run    # Test renewal
tail -f /var/log/nginx/error.log  # Search errors
```

### CORS Errors
Verify in `/opt/todo-api/.env`:
```bash
CORS_ORIGIN="https://taskflowwww.vercel.app"
```
Then restart: `pm2 restart todo-api`

### MongoDB Connection Failed
Check `.env` has valid `MONGO_URI`
Verify in MongoDB Atlas → Network Access → IP Whitelist includes EC2 IP

### High CPU/Memory
```bash
top                         # Check system usage
pm2 monit                   # Check per-process
pm2 logs todo-api          # Look for errors/loops
```

---

## 📋 Deployment Checklist

- [ ] EC2 instance ready (Ubuntu 20.04+)
- [ ] Security groups configured (22, 80, 443)
- [ ] Domain DNS record pointing to EC2
- [ ] .env file prepared with all variables
- [ ] deploy.sh run successfully
- [ ] Health endpoint responding
- [ ] SSL certificate issued
- [ ] API tested from Vercel frontend
- [ ] Logs clean (no errors)
- [ ] Reboot test passed (auto-start verified)

---

## 🔐 Security Best Practices

1. **Keep Scripts Secure**
   ```bash
   chmod 700 deploy.sh update.sh health-check.sh
   ```

2. **Protect .env File**
   ```bash
   chmod 600 /opt/todo-api/.env
   ```

3. **Restrict SSH Access**
   - Security group: SSH (22) only from your IP
   - Use SSH keys, not passwords
   - Consider using Bastion host for production

4. **Update System Weekly**
   ```bash
   apt-get update && apt-get upgrade -y
   ```

5. **Monitor Logs**
   - Check PM2 logs for errors
   - Review Nginx access/error logs
   - Set up log rotation (PM2 does this automatically)

---

## 📞 Support & Commands

| Task | Command |
|------|---------|
| View app status | `pm2 status` |
| View logs | `pm2 logs todo-api` |
| Restart app | `pm2 restart todo-api` |
| Stop app | `pm2 stop todo-api` |
| Nginx status | `systemctl status nginx` |
| Check SSL | `certbot certificates` |
| Test API | `curl https://api.taskflow.arjun10.tech/health` |
| Update code | `sudo bash update.sh` |
| Health check | `bash health-check.sh` |

---

## 🎓 Learning Resources

- **PM2 Docs:** https://pm2.keymetrics.io/
- **Nginx Documentation:** https://nginx.org/en/docs/
- **Let's Encrypt:** https://letsencrypt.org/
- **MongoDB Atlas:** https://www.mongodb.com/cloud/atlas
- **Express.js:** https://expressjs.com/

---

**Version:** 1.0  
**Last Updated:** April 7, 2026  
**Repository:** Arjun101105/Todo-BE
