# Grist Ubuntu Server Deployment Guide

Bu hujjat Grist'ni Ubuntu serverda ishga tushirish uchun to'liq qo'llanmadir.

## Tarkib

1. [Talablar](#talablar)
2. [Docker orqali o'rnatish](#docker-orqali-ornatish)
3. [Ubuntu Serverda to'liq o'rnatish](#ubuntu-serverda-toliq-ornatish)
4. [Nginx Reverse Proxy sozlash](#nginx-reverse-proxy-sozlash)
5. [SSL sertifikat sozlash (Let's Encrypt)](#ssl-sertifikat-sozlash)
6. [PostgreSQL va Redis bilan ishlash](#postgresql-va-redis-bilan-ishlash)
7. [Xavfsizlik sozlamalari](#xavfsizlik-sozlamalari)
8. [Backup va restore](#backup-va-restore)
9. [Monitoring va loglar](#monitoring-va-loglar)
10. [Muammolarni hal qilish](#muammolarni-hal-qilish)

---

## Talablar

### Minimal tizim talablari:
- Ubuntu 20.04 LTS yoki undan yuqori
- 2 GB RAM (4 GB tavsiya etiladi)
- 20 GB bo'sh disk maydoni
- Root yoki sudo huquqlari

### Kerakli dasturlar:
- Docker (20.10+)
- Docker Compose (2.0+)
- Nginx (reverse proxy uchun)
- Certbot (SSL sertifikatlar uchun)

---

## Docker orqali o'rnatish

### 1. Docker va Docker Compose o'rnatish

```bash
# Paketlar ro'yxatini yangilash
sudo apt update

# Kerakli paketlarni o'rnatish
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Docker rasmiy GPG kalitini qo'shish
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Docker repository qo'shish
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Paketlar ro'yxatini yangilash va Docker o'rnatish
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Docker xizmatini ishga tushirish
sudo systemctl enable docker
sudo systemctl start docker

# Foydalanuvchini docker guruhiga qo'shish (qayta kirish kerak)
sudo usermod -aG docker $USER

# Docker versiyasini tekshirish
docker --version
docker compose version
```

### 2. Oddiy Docker orqali ishga tushirish

```bash
# Grist image'ni yuklab olish
docker pull gristlabs/grist:latest

# Oddiy ishga tushirish (ma'lumotlar saqlanmaydi)
docker run -p 8484:8484 -it gristlabs/grist

# Ma'lumotlarni saqlash bilan ishga tushirish
mkdir -p ~/grist-persist
docker run -p 8484:8484 -v ~/grist-persist:/persist -it gristlabs/grist
```

Brauzerda `http://localhost:8484` yoki `http://server-ip:8484` manzilini oching.

### 3. Docker Compose orqali ishga tushirish

Loyiha ildizida `docker-compose.yml` fayli mavjud. Uni ishlatish:

```bash
# Docker Compose orqali ishga tushirish
docker compose up -d

# Loglarni ko'rish
docker compose logs -f

# To'xtatish
docker compose down
```

---

## Ubuntu Serverda to'liq o'rnatish

### 1. Loyiha katalogini yaratish

```bash
# Grist uchun katalog yaratish
sudo mkdir -p /opt/grist
cd /opt/grist

# Ma'lumotlar katalogini yaratish
sudo mkdir -p /opt/grist/persist
sudo chown -R $USER:$USER /opt/grist
```

### 2. Docker Compose konfiguratsiyasini yaratish

`/opt/grist/docker-compose.yml` faylini yarating:

```yaml
version: '3.8'

services:
  grist:
    image: gristlabs/grist:latest
    container_name: grist
    restart: unless-stopped
    volumes:
      - ./persist:/persist
    ports:
      - "127.0.0.1:8484:8484"  # Faqat localhost orqali kirish
    environment:
      # Asosiy sozlamalar
      - GRIST_DEFAULT_EMAIL=admin@example.com
      - GRIST_SESSION_SECRET=${GRIST_SESSION_SECRET:-change-me-to-random-string}
      
      # Ma'lumotlar bazasi (SQLite - oddiy uchun)
      - TYPEORM_DATABASE=/persist/home.sqlite3
      - TYPEORM_TYPE=sqlite
      
      # Xavfsizlik
      - GRIST_SANDBOX_FLAVOR=unsandboxed  # yoki gvisor agar qo'llab-quvvatlasa
      
      # Boshqa sozlamalar
      - GRIST_ORG_IN_PATH=true
      - GRIST_HOST=0.0.0.0
      - GRIST_SINGLE_PORT=true
      - GRIST_SERVE_SAME_ORIGIN=true
      - GRIST_DATA_DIR=/persist/docs
      - GRIST_INST_DIR=/persist
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8484/api/version"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

### 3. Environment faylini yaratish

`.env` faylini yarating:

```bash
cd /opt/grist
cat > .env << EOF
# Session secret (random string yarating)
GRIST_SESSION_SECRET=$(openssl rand -hex 32)

# Email
GRIST_DEFAULT_EMAIL=admin@example.com

# Domain (agar kerak bo'lsa)
GRIST_DOMAIN=yourdomain.com
EOF
```

### 4. Docker Compose faylini yangilash

`.env` faylidan o'qish uchun `docker-compose.yml` ni yangilang:

```yaml
version: '3.8'

services:
  grist:
    image: gristlabs/grist:latest
    container_name: grist
    restart: unless-stopped
    volumes:
      - ./persist:/persist
    ports:
      - "127.0.0.1:8484:8484"
    env_file:
      - .env
    environment:
      - TYPEORM_DATABASE=/persist/home.sqlite3
      - TYPEORM_TYPE=sqlite
      - GRIST_DATA_DIR=/persist/docs
      - GRIST_INST_DIR=/persist
      - GRIST_ORG_IN_PATH=true
      - GRIST_HOST=0.0.0.0
      - GRIST_SINGLE_PORT=true
      - GRIST_SERVE_SAME_ORIGIN=true
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8484/api/version"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### 5. Systemd service yaratish

`/etc/systemd/system/grist.service` faylini yarating:

```ini
[Unit]
Description=Grist Spreadsheet Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/grist
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0
User=root
Group=docker

[Install]
WantedBy=multi-user.target
```

Service'ni faollashtirish:

```bash
# Systemd daemon'ni qayta yuklash
sudo systemctl daemon-reload

# Service'ni faollashtirish
sudo systemctl enable grist.service

# Service'ni ishga tushirish
sudo systemctl start grist.service

# Holatni tekshirish
sudo systemctl status grist.service

# Loglarni ko'rish
sudo journalctl -u grist.service -f
```

---

## Nginx Reverse Proxy sozlash

### 1. Nginx o'rnatish

```bash
sudo apt update
sudo apt install -y nginx
```

### 2. Nginx konfiguratsiyasini yaratish

`/etc/nginx/sites-available/grist` faylini yarating:

```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;

    # Loglar
    access_log /var/log/nginx/grist-access.log;
    error_log /var/log/nginx/grist-error.log;

    # Katta fayllar uchun
    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:8484;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeout sozlamalari
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

### 3. Nginx konfiguratsiyasini faollashtirish

```bash
# Symlink yaratish
sudo ln -s /etc/nginx/sites-available/grist /etc/nginx/sites-enabled/

# Nginx konfiguratsiyasini tekshirish
sudo nginx -t

# Nginx'ni qayta ishga tushirish
sudo systemctl restart nginx

# Nginx'ni avtomatik ishga tushirish
sudo systemctl enable nginx
```

---

## SSL sertifikat sozlash (Let's Encrypt)

### 1. Certbot o'rnatish

```bash
sudo apt install -y certbot python3-certbot-nginx
```

### 2. SSL sertifikat olish

```bash
# Sertifikat olish va Nginx'ni avtomatik sozlash
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Yoki faqat sertifikat olish
sudo certbot certonly --nginx -d yourdomain.com -d www.yourdomain.com
```

### 3. Nginx konfiguratsiyasini SSL uchun yangilash

`/etc/nginx/sites-available/grist` faylini yangilang:

```nginx
# HTTP'dan HTTPS'ga redirect
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name yourdomain.com www.yourdomain.com;

    # SSL sertifikatlar
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    
    # SSL sozlamalari
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Loglar
    access_log /var/log/nginx/grist-access.log;
    error_log /var/log/nginx/grist-error.log;

    # Katta fayllar uchun
    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:8484;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeout sozlamalari
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

### 4. Avtomatik yangilanish

```bash
# Certbot avtomatik yangilanishini tekshirish
sudo certbot renew --dry-run

# Cron job qo'shish (har kuni tekshirish)
sudo crontab -e
# Quyidagini qo'shing:
# 0 0 * * * certbot renew --quiet --deploy-hook "systemctl reload nginx"
```

---

## PostgreSQL va Redis bilan ishlash

### 1. PostgreSQL va Redis bilan Docker Compose

`/opt/grist/docker-compose.yml` faylini yangilang:

```yaml
version: '3.8'

services:
  grist:
    image: gristlabs/grist:latest
    container_name: grist
    restart: unless-stopped
    volumes:
      - ./persist:/persist
    ports:
      - "127.0.0.1:8484:8484"
    env_file:
      - .env
    environment:
      # PostgreSQL sozlamalari
      - TYPEORM_TYPE=postgres
      - TYPEORM_HOST=grist-db
      - TYPEORM_PORT=5432
      - TYPEORM_DATABASE=grist
      - TYPEORM_USERNAME=grist
      - TYPEORM_PASSWORD=${POSTGRES_PASSWORD}
      
      # Redis sozlamalari
      - REDIS_URL=redis://grist-redis:6379
      
      # Boshqa sozlamalar
      - GRIST_DATA_DIR=/persist/docs
      - GRIST_INST_DIR=/persist
      - GRIST_ORG_IN_PATH=true
      - GRIST_HOST=0.0.0.0
      - GRIST_SINGLE_PORT=true
      - GRIST_SERVE_SAME_ORIGIN=true
    depends_on:
      - grist-db
      - grist-redis
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8484/api/version"]
      interval: 30s
      timeout: 10s
      retries: 3

  grist-db:
    image: postgres:15-alpine
    container_name: grist-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: grist
      POSTGRES_USER: grist
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - ./persist/postgres:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U grist"]
      interval: 10s
      timeout: 5s
      retries: 5

  grist-redis:
    image: redis:7-alpine
    container_name: grist-redis
    restart: unless-stopped
    volumes:
      - ./persist/redis:/data
    command: redis-server --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
```

`.env` faylini yangilang:

```bash
POSTGRES_PASSWORD=your-secure-password-here
```

### 2. Ma'lumotlar katalogini yaratish

```bash
mkdir -p /opt/grist/persist/postgres
mkdir -p /opt/grist/persist/redis
```

---

## Xavfsizlik sozlamalari

### 1. Firewall sozlash

```bash
# UFW o'rnatish va faollashtirish
sudo apt install -y ufw

# SSH'ni ruxsat berish (muhim!)
sudo ufw allow 22/tcp

# HTTP va HTTPS'ni ruxsat berish
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Firewall'ni faollashtirish
sudo ufw enable

# Holatni tekshirish
sudo ufw status
```

### 2. Fail2ban o'rnatish

```bash
# Fail2ban o'rnatish
sudo apt install -y fail2ban

# SSH uchun konfiguratsiya
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Fail2ban'ni qayta ishga tushirish
sudo systemctl restart fail2ban
sudo systemctl enable fail2ban
```

### 3. Grist xavfsizlik sozlamalari

`.env` fayliga qo'shing:

```bash
# Xavfsizlik
GRIST_SESSION_SECRET=$(openssl rand -hex 32)
GRIST_FORCE_LOGIN=true  # Anonim kirishni o'chirish
GRIST_ANON_PLAYGROUND=false  # Anonim o'yin maydonini o'chirish

# Webhook xavfsizligi
ALLOWED_WEBHOOK_DOMAINS=webhook.site,zapier.com  # Faqat ruxsat berilgan domenlar
```

### 4. Authentication sozlash

OIDC yoki SAML orqali authentication sozlash uchun qo'shimcha o'zgaruvchilar:

```bash
# OIDC uchun
GRIST_OIDC_SP_HOST=https://yourdomain.com
GRIST_OIDC_IDP_ISSUER=https://your-idp.com
GRIST_OIDC_IDP_CLIENT_ID=your-client-id
GRIST_OIDC_IDP_CLIENT_SECRET=your-client-secret
```

---

## Backup va restore

### 1. Backup skripti yaratish

`/opt/grist/backup.sh` faylini yarating:

```bash
#!/bin/bash

BACKUP_DIR="/opt/grist/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/grist_backup_$DATE.tar.gz"

# Backup katalogini yaratish
mkdir -p $BACKUP_DIR

# Docker container'ni to'xtatish (ixtiyoriy)
# docker compose -f /opt/grist/docker-compose.yml stop grist

# Backup yaratish
tar -czf $BACKUP_FILE -C /opt/grist persist

# Eski backup'larni o'chirish (30 kundan eski)
find $BACKUP_DIR -name "grist_backup_*.tar.gz" -mtime +30 -delete

# Docker container'ni qayta ishga tushirish (agar to'xtatilgan bo'lsa)
# docker compose -f /opt/grist/docker-compose.yml start grist

echo "Backup yaratildi: $BACKUP_FILE"
```

Faylga bajarish huquqini berish:

```bash
chmod +x /opt/grist/backup.sh
```

### 2. Avtomatik backup (Cron)

```bash
# Cron job qo'shish
crontab -e

# Har kuni kechasi 2:00 da backup
0 2 * * * /opt/grist/backup.sh >> /opt/grist/backup.log 2>&1
```

### 3. Restore

```bash
# Backup faylini tanlash
BACKUP_FILE="/opt/grist/backups/grist_backup_YYYYMMDD_HHMMSS.tar.gz"

# Grist'ni to'xtatish
docker compose -f /opt/grist/docker-compose.yml down

# Eski ma'lumotlarni yedeklash
mv /opt/grist/persist /opt/grist/persist.old

# Backup'dan restore qilish
tar -xzf $BACKUP_FILE -C /opt/grist

# Grist'ni qayta ishga tushirish
docker compose -f /opt/grist/docker-compose.yml up -d
```

---

## Monitoring va loglar

### 1. Docker loglarini ko'rish

```bash
# Grist loglarini ko'rish
docker compose -f /opt/grist/docker-compose.yml logs -f grist

# Oxirgi 100 qator log
docker compose -f /opt/grist/docker-compose.yml logs --tail=100 grist
```

### 2. Systemd loglar

```bash
# Service loglarini ko'rish
sudo journalctl -u grist.service -f

# Oxirgi 100 qator
sudo journalctl -u grist.service -n 100
```

### 3. Disk maydonini kuzatish

```bash
# Disk ishlatilishini ko'rish
df -h

# Grist katalogining hajmini ko'rish
du -sh /opt/grist/persist
```

### 4. Monitoring skripti

`/opt/grist/monitor.sh` faylini yarating:

```bash
#!/bin/bash

# Grist container holatini tekshirish
if ! docker ps | grep -q grist; then
    echo "XATO: Grist container ishlamayapti!"
    # Email yuborish yoki boshqa ogohlantirish
fi

# Disk maydonini tekshirish
DISK_USAGE=$(df -h /opt/grist | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "OGOHLANTIRISH: Disk maydoni $DISK_USAGE% to'ldi!"
fi
```

---

## Muammolarni hal qilish

### 1. Container ishlamayapti

```bash
# Container holatini tekshirish
docker ps -a | grep grist

# Loglarni ko'rish
docker compose -f /opt/grist/docker-compose.yml logs grist

# Container'ni qayta ishga tushirish
docker compose -f /opt/grist/docker-compose.yml restart grist
```

### 2. Port band

```bash
# 8484 portni kim ishlatayotganini tekshirish
sudo netstat -tulpn | grep 8484
# yoki
sudo lsof -i :8484

# Agar kerak bo'lsa, process'ni to'xtatish
sudo kill -9 <PID>
```

### 3. Ma'lumotlar yo'qolgan

```bash
# Backup'dan restore qilish (yuqoridagi qismga qarang)
# Yoki
# Persist katalogini tekshirish
ls -la /opt/grist/persist
```

### 4. Nginx xatolari

```bash
# Nginx konfiguratsiyasini tekshirish
sudo nginx -t

# Nginx loglarini ko'rish
sudo tail -f /var/log/nginx/grist-error.log
```

### 5. Database muammolari

```bash
# PostgreSQL container'ni tekshirish
docker compose -f /opt/grist/docker-compose.yml logs grist-db

# SQLite faylini tekshirish (agar SQLite ishlatilsa)
sqlite3 /opt/grist/persist/home.sqlite3 ".tables"
```

---

## Foydali buyruqlar

```bash
# Grist'ni ishga tushirish
sudo systemctl start grist

# Grist'ni to'xtatish
sudo systemctl stop grist

# Grist'ni qayta ishga tushirish
sudo systemctl restart grist

# Grist holatini ko'rish
sudo systemctl status grist

# Docker Compose orqali
docker compose -f /opt/grist/docker-compose.yml up -d
docker compose -f /opt/grist/docker-compose.yml down
docker compose -f /opt/grist/docker-compose.yml restart

# Image'ni yangilash
docker pull gristlabs/grist:latest
docker compose -f /opt/grist/docker-compose.yml up -d --force-recreate
```

---

## Qo'shimcha resurslar

- [Grist rasmiy hujjatlari](https://support.getgrist.com/)
- [Self-Managed Grist qo'llanmasi](https://support.getgrist.com/self-managed/)
- [Docker hujjatlari](https://docs.docker.com/)
- [Nginx hujjatlari](https://nginx.org/en/docs/)

---

## Yordam

Agar muammo yuzaga kelsa:
1. Loglarni tekshiring
2. [Grist GitHub Issues](https://github.com/gristlabs/grist-core/issues) da qidiring
3. [Grist Community Forum](https://community.getgrist.com/) da so'rang

