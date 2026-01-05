# Grist Ubuntu Server - Tezkor Boshlash

Bu qo'llanma Grist'ni Ubuntu serverda tezda ishga tushirish uchun minimal qadamlar.

## 1. Docker o'rnatish

```bash
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
```

**Muhim:** Qayta kirish yoki `newgrp docker` buyrug'ini ishlating.

## 2. Grist'ni ishga tushirish

```bash
# Katalog yaratish
sudo mkdir -p /opt/grist
cd /opt/grist

# Oddiy ishga tushirish (ma'lumotlar saqlanadi)
docker run -d \
  --name grist \
  --restart unless-stopped \
  -p 8484:8484 \
  -v $(pwd)/persist:/persist \
  gristlabs/grist:latest
```

## 3. Tekshirish

Brauzerda oching: `http://your-server-ip:8484`

## 4. Nginx va SSL sozlash (ixtiyoriy)

Agar domain nomi va SSL kerak bo'lsa:

```bash
# Nginx o'rnatish
sudo apt install -y nginx

# Konfiguratsiya yaratish
sudo nano /etc/nginx/sites-available/grist
```

Quyidagi konfiguratsiyani qo'ying:

```nginx
server {
    listen 80;
    server_name yourdomain.com;
    
    location / {
        proxy_pass http://127.0.0.1:8484;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
# Faollashtirish
sudo ln -s /etc/nginx/sites-available/grist /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# SSL sertifikat
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

## Foydali buyruqlar

```bash
# Container'ni ko'rish
docker ps | grep grist

# Loglarni ko'rish
docker logs -f grist

# To'xtatish
docker stop grist

# Qayta ishga tushirish
docker start grist

# O'chirish
docker stop grist
docker rm grist
```

## Keyingi qadamlar

To'liq production sozlash uchun [DEPLOYMENT.md](../DEPLOYMENT.md) faylini ko'ring.

