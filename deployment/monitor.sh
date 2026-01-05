#!/bin/bash

# Grist Monitoring Script
# Bu skript Grist xizmatining holatini tekshiradi

COMPOSE_FILE="/opt/grist/docker-compose.yml"
LOG_FILE="/opt/grist/monitor.log"

# Log funksiyasi
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Grist container holatini tekshirish
if ! docker ps | grep -q grist; then
    log "XATO: Grist container ishlamayapti!"
    # Bu yerda email yuborish yoki boshqa ogohlantirish qo'shishingiz mumkin
    exit 1
fi

# Disk maydonini tekshirish
DISK_USAGE=$(df -h /opt/grist | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    log "OGOHLANTIRISH: Disk maydoni ${DISK_USAGE}% to'ldi!"
fi

# Container health check
if docker inspect grist | grep -q '"Health": {[^}]*"Status": "unhealthy"'; then
    log "OGOHLANTIRISH: Grist container sog'liqsiz holatda!"
fi

log "Monitoring tekshiruvi yakunlandi - hammasi yaxshi."

