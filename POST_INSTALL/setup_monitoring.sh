#!/bin/bash
# Setup basic monitoring and health checks
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HEALTH_CHECK_DIR="/usr/local/bin"

echo "=== Monitoring Setup ==="
echo ""
echo "Vyberte si monitoring možnosti:"
echo "1) Health checks (systemd timers)"
echo "2) Alerting (email/webhook na chyby)"
echo "3) Dashboard (web status page)"
echo "4) Všechno"
read -p "Vyberte [1-4]: " choice

setup_health_checks() {
    echo "Nastavuji health checks..."
    
    # Vytvoření health check skriptu
    cat | sudo tee "$HEALTH_CHECK_DIR/ha-health-check" <<'EOF'
#!/bin/bash
set -euo pipefail

REPO_ROOT="$(pwd)"
FAIL=0

# Check Docker
if ! docker ps &>/dev/null; then
    echo "ERROR: Docker není spuštěn"
    FAIL=1
fi

# Check Home Assistant
if ! curl -s http://localhost:8123 &>/dev/null; then
    echo "ERROR: Home Assistant nereaguje na port 8123"
    FAIL=1
fi

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "WARNING: Disk je $DISK_USAGE% plný"
    FAIL=1
fi

# Check config sync
if [ ! -f "$REPO_ROOT/config/configuration.yaml" ]; then
    echo "ERROR: Config nemá configuration.yaml"
    FAIL=1
fi

if [ $FAIL -eq 0 ]; then
    echo "OK: Všechny checks prošly"
    exit 0
else
    exit 1
fi
EOF
    
    sudo chmod +x "$HEALTH_CHECK_DIR/ha-health-check"
    
    # Systemd service
    cat | sudo tee /etc/systemd/system/ha-health-check.service <<EOF
[Unit]
Description=Home Assistant Suite Health Check
After=network.target

[Service]
Type=oneshot
ExecStart=$HEALTH_CHECK_DIR/ha-health-check
StandardOutput=journal
StandardError=journal
User=root
EOF

    # Systemd timer (každou hodinu)
    cat | sudo tee /etc/systemd/system/ha-health-check.timer <<EOF
[Unit]
Description=Home Assistant Suite Health Check Timer
Requires=ha-health-check.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=1h

[Install]
WantedBy=timers.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable ha-health-check.timer
    sudo systemctl start ha-health-check.timer
    
    echo "✅ Health checks nastaveny (každou hodinu)"
}

setup_alerting() {
    echo "Nastavuji alerting..."
    echo "Zadejte email pro alerty (nebo nechte prázdné pro přeskočení):"
    read -p "Email: " email
    
    if [ -z "$email" ]; then
        echo "⚠️ Email alerting přeskočen"
        return
    fi
    
    cat | sudo tee /usr/local/bin/ha-alert <<EOF
#!/bin/bash
SUBJECT="HA Suite Alert: \$1"
MESSAGE="\$2"
echo "\$MESSAGE" | mail -s "\$SUBJECT" "$email"
EOF
    
    sudo chmod +x /usr/local/bin/ha-alert
    echo "✅ Alerting nastaven na: $email"
}

setup_dashboard() {
    echo "Nastavuji status dashboard..."
    
    cat > "$REPO_ROOT/STATUS.md" <<'EOF'
# Home Assistant Suite - Status Dashboard

Vygenerováno automaticky.

## Služby

```
docker-compose ps
```

## Disk

```
df -h /
```

## Logy

```
docker-compose logs --tail 50
```

## Konfigurace

```
ls -la config/
```
EOF

    echo "✅ Dashboard vytvořen: STATUS.md"
}

case "$choice" in
    1) setup_health_checks ;;
    2) setup_alerting ;;
    3) setup_dashboard ;;
    4)
        setup_health_checks
        setup_alerting
        setup_dashboard
        echo ""
        echo "✅ Monitoring setup dokončen"
        ;;
    *)
        echo "Neplatná volba"
        exit 1
        ;;
esac

echo ""
echo "Monitoring:"
echo "- Kontrola: systemctl status ha-health-check.timer"
echo "- Logy: journalctl -u ha-health-check -f"
