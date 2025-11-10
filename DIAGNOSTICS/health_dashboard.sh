#!/bin/bash
# Komplexní health dashboard pro celý systém

echo "🏥 HEALTH DASHBOARD - $(date)"
echo "================================="

# Systémové informace
echo "=== SYSTÉM ==="
echo "🖥️  CPU: $(cat /sys/class/thermal/thermal_zone0/temp | awk '{printf "%.1f°C", $1/1000}')"
echo "💾 RAM: $(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
echo "📦 Disk: $(df -h / | awk 'NR==2{print $5}')"

# Docker služby
echo -e "\n=== DOCKER SLUŽBY ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}"

# Home Assistant
echo -e "\n=== HOME ASSISTANT ==="
if curl -s http://localhost:8123 > /dev/null; then
    echo "✅ Home Assistant běží"
else
    echo "❌ Home Assistant nedostupný"
fi

# Úložiště
echo -e "\n=== ÚLOŽIŠTĚ ==="
df -h /mnt/* 2>/dev/null | grep -v "tmpfs"
