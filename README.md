# 🚀 Todo-BE EC2 Deployment - Complete Setup

Automated production-grade deployment for Todo-BE API on AWS EC2 with PM2, Nginx, and Let's Encrypt SSL.

---

## ✅ What's Been Done

### 1. **Code Improvements** 
Your application is now production-ready:
- ✅ PORT configurable via environment (`process.env.PORT`)
- ✅ CORS origin configurable via environment (`process.env.CORS_ORIGIN`)
- ✅ Added `/health` endpoint for monitoring and load balancer checks
- ✅ Updated `.env.sample` with all configuration variables

### 2. **Automated Deployment Scripts**
Three powerful bash scripts ready to use:

| Script | Purpose | Time |
|--------|---------|------|
| **deploy.sh** | Complete EC2 setup (Node.js, PM2, Nginx, SSL) | ~5-10 min |
| **update.sh** | Zero-downtime code updates | ~30 sec |
| **health-check.sh** | Verify deployment health | ~10 sec |

### 3. **Complete Documentation**
- **DEPLOYMENT.md** - Full deployment guide (500+ lines)
- **SCRIPTS_REFERENCE.md** - Quick reference for all scripts
- All scripts include inline documentation

---

## 🎯 What You Get

### **Production Infrastructure**
- ✅ Node.js 18.x runtime with PM2 process management
- ✅ Clustering across all CPU cores (auto load-balancing)
- ✅ Nginx reverse proxy on ports 80/443
- ✅ Let's Encrypt SSL certificate (auto-renewal)
- ✅ Auto-restart on EC2 reboot
- ✅ Auto-restart on application crash

### **Security**
- ✅ HTTPS enforced (HTTP redirects to HTTPS)
- ✅ Security headers (HSTS, X-Frame-Options, XSS protection)
- ✅ Rate limiting (100 req/s, 200 burst)
- ✅ CORS restricted to your Vercel frontend
- ✅ JWT authentication on all API endpoints

### **Monitoring**
- ✅ Health endpoint for monitoring
- ✅ Detailed logging with rotation
- ✅ Real-time health check script
- ✅ PM2 dashboard accessible (`pm2 monit`)

---

## 🚀 Quick Start (4 Steps)

### Step 1: Launch EC2 Instance
```bash
# 1. Go to AWS EC2 Console
# 2. Launch Ubuntu 20.04+ LTS instance (t2.micro or larger)
# 3. Configure Security Group:
#    - SSH (22): Your IP only
#    - HTTP (80): 0.0.0.0/0
#    - HTTPS (443): 0.0.0.0/0
# 4. Assign Elastic IP (optional but recommended)
```

### Step 2: Configure Domain
```bash
# Add DNS A record for your domain:
# api.taskflow.arjun10.tech → <EC2 Elastic IP>

# Verify DNS resolves:
nslookup api.taskflow.arjun10.tech
```

### Step 3: Prepare Environment File
```bash
# Create .env with your MongoDB URI and JWT secret:
MONGO_URI="mongodb+srv://..."
JWT_SECRET="your-secret-key-min-32-chars"
PORT=3000
NODE_ENV=production
CORS_ORIGIN="https://taskflowwww.vercel.app"

# Transfer to EC2:
scp -i your-key.pem .env ubuntu@your-ec2-ip:~/
```

### Step 4: Run Deployment Script
```bash
# SSH into EC2
ssh -i your-key.pem ubuntu@your-ec2-ip
sudo su -

# Download and run
cd /tmp
git clone https://github.com/Arjun101105/Todo-BE.git
cd Todo-BE
sudo bash deploy.sh
```

**That's it!** Your API is now live at `https://api.taskflow.arjun10.tech`

---

## 📋 Verification Checklist

After deployment, verify everything works:

```bash
# 1. Check health endpoint
curl https://api.taskflow.arjun10.tech/health

# 2. Test from Vercel frontend
# Open https://taskflowwww.vercel.app
# Try signup/signin

# 3. View PM2 status
pm2 status
pm2 logs todo-api

# 4. Check SSL certificate
certbot certificates

# 5. Monitor resources
pm2 monit
```

---

## 🔄 Common Tasks

### Deploy New Code
```bash
# Push to GitHub
git push origin master

# On EC2
sudo bash update.sh
```

### Check Application Health
```bash
# From local machine or EC2
bash health-check.sh
```

### View Logs
```bash
# Real-time logs
pm2 logs todo-api

# Nginx logs
tail -f /var/log/nginx/access.log
```

### Restart Application
```bash
pm2 restart todo-api
```

---

## 📊 Architecture

```
┌─────────────────────────┐
│   Vercel Frontend       │
│ taskflowwww.vercel.app  │
└────────────┬────────────┘
             │ HTTPS requests
             ↓
┌──────────────────────────────────────────┐
│       api.taskflow.arjun10.tech           │
│          (EC2 Instance)                   │
├──────────────────────────────────────────┤
│  Nginx (SSL termination + reverse proxy)  │
│  Port 80 → 443, Rate limiting, Headers   │
└────────────┬─────────────────────────────┘
             │ HTTP localhost:3000
             ↓
┌──────────────────────────────────────────┐
│  PM2 Process Manager (Clustering)        │
│  ├─ Node.js Instance 1                   │
│  ├─ Node.js Instance 2                   │
│  ├─ Node.js Instance 3 (auto-scaled)     │
│  └─ Node.js Instance N                   │
└────────────┬─────────────────────────────┘
             │ Query/Insert/Update
             ↓
┌──────────────────────────────────────────┐
│   MongoDB Atlas (Cloud-managed)          │
│   Connection pooling + Backups           │
└──────────────────────────────────────────┘
```

---

## 🔐 Security Highlights

✅ **SSL/TLS:**
- Let's Encrypt certificates (free, auto-renewed)
- TLS 1.2+ enforced, weak ciphers disabled
- HSTS header forces HTTPS for all future requests

✅ **Application:**
- JWT-based authentication on all endpoints
- Bcrypt password hashing with salt
- Input validation and error handling

✅ **Network:**
- Security groups restrict network access
- CORS limited to Vercel frontend only
- Rate limiting prevents abuse

✅ **Infrastructure:**
- PM2 monitors and restarts crashed processes
- Nginx health checks on upstream
- Logs separated and rotated automatically

---

## 📚 Documentation Files

| File | Purpose | For Whom |
|------|---------|----------|
| **README.md** | This file - overview | Everyone |
| **DEPLOYMENT.md** | Detailed guide | DevOps/Setup Engineers |
| **SCRIPTS_REFERENCE.md** | Script reference | System Administrators |
| **.env.sample** | Configuration template | Everyone |

---

## 🆘 Troubleshooting

### API Not Responding
```bash
# 1. Check if running
pm2 status

# 2. View logs
pm2 logs todo-api

# 3. Test locally
curl http://localhost:3000/health

# 4. Check Nginx
systemctl status nginx
```

### SSL Certificate Issues
```bash
# View certificates
certbot certificates

# Test renewal
certbot renew --dry-run

# View details
openssl s_client -connect api.taskflow.arjun10.tech:443
```

### MongoDB Connection Failed
```bash
# Verify .env
cat /opt/todo-api/.env | grep MONGO_URI

# Check MongoDB Atlas:
# - Network Access → IP Whitelist includes EC2 IP
# - User exists with correct password
```

For more: See **DEPLOYMENT.md** → Troubleshooting section

---

## 🎯 Best Practices Going Forward

1. **Weekly Updates**
   ```bash
   apt-get update && apt-get upgrade -y
   ```

2. **Monitor Logs**
   ```bash
   # Daily check
   pm2 logs todo-api | tail -50
   tail -50 /var/log/nginx/error.log
   ```

3. **Test Health**
   ```bash
   # Weekly health check
   bash health-check.sh
   ```

4. **Backup .env**
   - Store in secure location (not git)
   - Consider AWS Secrets Manager for production

5. **Review Certificate**
   ```bash
   # Monthly
   certbot certificates
   ```

---

## 🚀 Next Steps

1. ✅ Read **DEPLOYMENT.md** for pre-deployment checklist
2. ✅ Launch EC2 instance and configure security groups
3. ✅ Create DNS record for your domain
4. ✅ Prepare `.env` file with MongoDB URI + JWT secret
5. ✅ SSH into EC2 and run `sudo bash deploy.sh`
6. ✅ Verify with health check: `curl https://api.taskflow.arjun10.tech/health`
7. ✅ Test from Vercel frontend
8. ✅ **Production is live!**

---

## 📞 Commands Cheat Sheet

```bash
# Application
pm2 status                    # Check status
pm2 logs todo-api            # View logs
pm2 restart todo-api         # Restart
pm2 monit                    # Dashboard

# System
systemctl status nginx       # Nginx status
systemctl restart nginx      # Restart Nginx
certbot certificates         # SSL status

# Updates
sudo bash update.sh          # Update code + restart
apt-get update && apt-get upgrade -y  # System update

# Health Check
bash health-check.sh         # Automated health check
curl https://api.taskflow.arjun10.tech/health  # Manual
```

---

## 📖 File Structure

```
Todo-BE/
├── deploy.sh                    ← Run this for initial setup
├── update.sh                    ← Run this for code updates
├── health-check.sh              ← Run this to verify deployment
├── DEPLOYMENT.md                ← Full deployment guide
├── SCRIPTS_REFERENCE.md         ← Script details
├── README.md                    ← This file
├── .env.sample                  ← Configuration template
├── index.js                     ← ✅ Updated (PORT, CORS, /health)
├── package.json
├── db/
│   └── db.js
├── middleware/
│   └── auth.js
└── routes/
    ├── user.js
    ├── todo.js
    └── tag.js
```

---

## ✨ Key Features

| Feature | Benefit |
|---------|---------|
| **PM2 Clustering** | Auto load-balancing across CPU cores |
| **Auto-restart** | Keeps app online even if it crashes |
| **Nginx Reverse Proxy** | Handles SSL, compression, security headers |
| **Let's Encrypt SSL** | Free HTTPS certificates, auto-renewed |
| **Health Endpoint** | For monitoring and load balancer checks |
| **Security Headers** | HSTS, X-Frame-Options, XSS protection |
| **Rate Limiting** | Prevents abuse (100 req/s default) |
| **Log Rotation** | Keeps disk space clean |
| **Zero-downtime Updates** | Deploy without interrupting users |
| **Auto-startup** | Survives EC2 reboot |

---

## 🎓 Learning Resources

- [PM2 Documentation](https://pm2.keymetrics.io/#/docs)
- [Nginx Best Practices](https://nginx.org/en/docs/)
- [Let's Encrypt](https://letsencrypt.org/)
- [MongoDB Atlas](https://www.mongodb.com/cloud/atlas)
- [Express.js Production](https://expressjs.com/en/advanced/best-practice-performance.html)

---

**Version:** 1.0  
**Date:** April 7, 2026  
**Repository:** Arjun101105/Todo-BE  
**Status:** ✅ Ready for Production Deployment

Questions? Check **DEPLOYMENT.md** or **SCRIPTS_REFERENCE.md** for detailed documentation.
