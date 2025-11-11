#!/bin/bash
# Analyze disk usage and storage
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Storage Analysis ==="
echo ""

echo "1. Celkové využití disku:"
df -h /

echo ""
echo "2. Využití domovského adresáře:"
du -sh ~

echo ""
echo "3. Využití Home Assistant config:"
[ -d "$REPO_ROOT/config" ] && du -sh "$REPO_ROOT/config" || echo "config/ nebyl nalezen"

echo ""
echo "4. Zálohování:"
[ -d "$REPO_ROOT/backups" ] && du -sh "$REPO_ROOT/backups" || echo "backups/ nebyl nalezen"

echo ""
echo "5. Docker volumes:"
docker system df 2>/dev/null || echo "Docker není dostupný"

echo ""
echo "6. Největší soubory v config/:"
if [ -d "$REPO_ROOT/config" ]; then
    find "$REPO_ROOT/config" -type f -exec du -h {} + | sort -rh | head -10
else
    echo "config/ nebyl nalezen"
fi

echo ""
echo "7. Disk inodes:"
df -i /

echo ""
echo "Doporučení:"
if df / | awk 'NR==2 {print $5}' | sed 's/%//' | awk '{if ($1 > 80) exit 0; exit 1}'; then
    echo "⚠️ POZOR: Disk je více než 80% plný!"
    echo "Spusťte optimalizaci: docker system prune -f"
    echo "Nebo: ./scripts/backup_config.sh --keep 3"
else
    echo "✅ Disk má dostatek místa"
fi
