#!/bin/bash
# Setup maintenance tasks (log rotation, cleanup, optimization)
set -euo pipefail

echo "=== Maintenance Setup ==="
echo ""
echo "Vyberte si údržbové úkoly:"
echo "1) Nastavit log rotation"
echo "2) Nastavit čištění temp souborů"
echo "3) Nastavit optimalizaci Docker"
echo "4) Všechno (doporučeno)"
read -p "Vyberte [1-4]: " choice

setup_logrotate() {
    echo "Nastavuji log rotation..."
    
    cat | sudo tee /etc/logrotate.d/homeassistant-suite <<EOF
/home/*/ha_suite_install.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
}

/tmp/ha_backup.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
}
EOF
    
    echo "✅ Log rotation nastavena"
}

setup_cleanup() {
    echo "Nastavuji čištění temp souborů..."
    
    cat | sudo tee /etc/cron.weekly/ha-cleanup <<'EOF'
#!/bin/bash
# Cleanup temp files and old logs
find /tmp -type f -name "*.tmp" -mtime +7 -delete
find /tmp -type f -name "ha_*" -mtime +30 -delete
find ~/.cache -type f -mtime +30 -delete 2>/dev/null || true

# Cleanup old Docker logs
docker system prune -f --filter "until=168h" 2>/dev/null || true

echo "Cleanup completed at $(date)" >> /var/log/ha-maintenance.log
EOF
    
    sudo chmod +x /etc/cron.weekly/ha-cleanup
    echo "✅ Cleanup skript nainstalován"
}

setup_docker_optimization() {
    echo "Nastavuji Docker optimalizaci..."
    
    cat | sudo tee /etc/cron.weekly/docker-optimize <<'EOF'
#!/bin/bash
# Docker cleanup
docker system prune -f
docker volume prune -f
docker image prune -a -f --filter "until=720h"

echo "Docker optimization at $(date)" >> /var/log/docker-maintenance.log
EOF
    
    sudo chmod +x /etc/cron.weekly/docker-optimize
    echo "✅ Docker optimization nainstalován"
}

case "$choice" in
    1) setup_logrotate ;;
    2) setup_cleanup ;;
    3) setup_docker_optimization ;;
    4)
        setup_logrotate
        setup_cleanup
        setup_docker_optimization
        echo ""
        echo "✅ Všechna údržbová nastavení dokončena"
        ;;
    *)
        echo "Neplatná volba"
        exit 1
        ;;
esac

echo ""
echo "Údržba:"
echo "- Kontrolujte logy: tail -f /var/log/ha-maintenance.log"
echo "- Ruční čištění: docker system prune -a"
echo "- Kontrola disku: ./scripts/storage_analyzer.sh"
