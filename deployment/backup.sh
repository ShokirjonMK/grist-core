#!/bin/bash

# Grist Backup Script
# Bu skript Grist ma'lumotlarini backup qiladi

set -e

BACKUP_DIR="/opt/grist/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/grist_backup_$DATE.tar.gz"
COMPOSE_FILE="/opt/grist/docker-compose.yml"
LOG_FILE="/opt/grist/backup.log"

# Log funksiyasi
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Backup katalogini yaratish
mkdir -p "$BACKUP_DIR"

log "Backup boshlandi..."

# Docker container'ni to'xtatish (ixtiyoriy - comment qiling agar kerak bo'lmasa)
# log "Grist container'ni to'xtatish..."
# docker compose -f "$COMPOSE_FILE" stop grist || true

# Backup yaratish
log "Backup yaratilmoqda: $BACKUP_FILE"
tar -czf "$BACKUP_FILE" -C /opt/grist persist

# Backup fayl hajmini tekshirish
if [ -f "$BACKUP_FILE" ]; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "Backup muvaffaqiyatli yaratildi: $BACKUP_FILE (Hajm: $SIZE)"
else
    log "XATO: Backup fayli yaratilmadi!"
    exit 1
fi

# Eski backup'larni o'chirish (30 kundan eski)
log "Eski backup'larni o'chirish (30 kundan eski)..."
find "$BACKUP_DIR" -name "grist_backup_*.tar.gz" -mtime +30 -delete

# Docker container'ni qayta ishga tushirish (agar to'xtatilgan bo'lsa)
# log "Grist container'ni qayta ishga tushirish..."
# docker compose -f "$COMPOSE_FILE" start grist || true

log "Backup yakunlandi."

