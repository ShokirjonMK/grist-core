# Grist Deployment Files

Bu katalogda Grist'ni Ubuntu serverda ishga tushirish uchun kerakli konfiguratsiya fayllari mavjud.

## Fayllar

- `docker-compose.prod.yml` - Oddiy production konfiguratsiyasi (SQLite)
- `docker-compose.prod-postgres.yml` - PostgreSQL va Redis bilan production konfiguratsiyasi
- `grist.service` - Systemd service fayli
- `nginx-grist.conf` - Nginx reverse proxy konfiguratsiyasi
- `backup.sh` - Backup skripti
- `monitor.sh` - Monitoring skripti
- `.env.example` - Environment o'zgaruvchilari namunasi

## O'rnatish

### 1. Fayllarni ko'chirish

```bash
# Grist katalogini yaratish
sudo mkdir -p /opt/grist
cd /opt/grist

# Konfiguratsiya fayllarini ko'chirish
sudo cp deployment/docker-compose.prod.yml docker-compose.yml
sudo cp deployment/.env.example .env

# .env faylini tahrirlash
sudo nano .env
```

### 2. Environment o'zgaruvchilarini sozlash

`.env` faylini ochib, kerakli qiymatlarni o'zgartiring:

```bash
# Session secret yaratish
GRIST_SESSION_SECRET=$(openssl rand -hex 32)

# Email va boshqa sozlamalarni o'zgartiring
```

### 3. Systemd service o'rnatish

```bash
# Service faylini ko'chirish
sudo cp deployment/grist.service /etc/systemd/system/

# Systemd daemon'ni qayta yuklash
sudo systemctl daemon-reload

# Service'ni faollashtirish
sudo systemctl enable grist.service

# Service'ni ishga tushirish
sudo systemctl start grist.service
```

### 4. Nginx sozlash

```bash
# Nginx konfiguratsiyasini ko'chirish
sudo cp deployment/nginx-grist.conf /etc/nginx/sites-available/grist

# Domain nomini o'zgartirish
sudo nano /etc/nginx/sites-available/grist
# yourdomain.com ni o'z domain nomingiz bilan almashtiring

# Symlink yaratish
sudo ln -s /etc/nginx/sites-available/grist /etc/nginx/sites-enabled/

# Nginx konfiguratsiyasini tekshirish
sudo nginx -t

# Nginx'ni qayta ishga tushirish
sudo systemctl restart nginx
```

### 5. SSL sertifikat olish

```bash
# Certbot o'rnatish
sudo apt install -y certbot python3-certbot-nginx

# Sertifikat olish
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

### 6. Backup skriptini sozlash

```bash
# Skriptga bajarish huquqini berish
sudo chmod +x deployment/backup.sh

# Cron job qo'shish
crontab -e
# Quyidagini qo'shing:
# 0 2 * * * /opt/grist/deployment/backup.sh
```

## PostgreSQL va Redis bilan ishlash

Agar PostgreSQL va Redis ishlatmoqchi bo'lsangiz:

```bash
# PostgreSQL versiyasini ko'chirish
sudo cp deployment/docker-compose.prod-postgres.yml docker-compose.yml

# .env faylida POSTGRES_PASSWORD ni sozlang
sudo nano .env

# Service'ni qayta ishga tushirish
sudo systemctl restart grist.service
```

## Foydali buyruqlar

```bash
# Service holatini ko'rish
sudo systemctl status grist.service

# Loglarni ko'rish
sudo journalctl -u grist.service -f

# Docker loglarini ko'rish
docker compose -f /opt/grist/docker-compose.yml logs -f

# Backup yaratish
/opt/grist/deployment/backup.sh

# Monitoring
/opt/grist/deployment/monitor.sh
```

## Qo'shimcha ma'lumot

Batafsil qo'llanma uchun asosiy `DEPLOYMENT.md` faylini ko'ring.

