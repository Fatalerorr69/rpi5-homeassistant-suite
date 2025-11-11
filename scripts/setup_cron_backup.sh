#!/bin/bash
# Cron helper: setup automated config backups
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRON_JOB="0 */12 * * * cd $REPO_ROOT && ./scripts/backup_config.sh >> /tmp/ha_backup.log 2>&1"

usage() {
    cat <<EOF
Usage: $0 [install|remove|status]
  install    Add backup job to crontab (every 12 hours)
  remove     Remove backup job from crontab
  status     Show if job is in crontab
EOF
    exit 1
}

if [ $# -lt 1 ]; then usage; fi

case "$1" in
    install)
        echo "Installing cron job..."
        (crontab -l 2>/dev/null | grep -v "ha_backup" || true; echo "$CRON_JOB") | crontab -
        echo "✅ Backup job installed. Check: crontab -l"
        ;;
    remove)
        echo "Removing cron job..."
        crontab -l 2>/dev/null | grep -v "ha_backup" | crontab - || true
        echo "✅ Backup job removed"
        ;;
    status)
        if crontab -l 2>/dev/null | grep -q "ha_backup"; then
            echo "✅ Backup job is installed"
            echo "Current cron entry:"
            crontab -l | grep "ha_backup"
        else
            echo "❌ Backup job not found in crontab"
        fi
        ;;
    *)
        usage
        ;;
esac
