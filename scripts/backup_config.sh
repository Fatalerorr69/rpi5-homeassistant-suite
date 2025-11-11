#!/bin/bash
# Backup runtime `config/` directory with rotation
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config"
BACKUP_DIR="$REPO_ROOT/backups"
KEEP=7

usage(){
  cat <<EOF
Usage: $0 [--keep N]
  --keep N   Keep last N backups (default: $KEEP)
EOF
  exit 1
}

if [ "${1:-}" = "--help" ]; then usage; fi
if [ "${1:-}" = "--keep" ]; then KEEP="$2"; fi

if [ ! -d "$CONFIG_DIR" ]; then
  echo "No runtime config/ directory found at $CONFIG_DIR" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
TS=$(date +%Y%m%dT%H%M%S)
OUT="$BACKUP_DIR/config-backup-$TS.tar.gz"

echo "Creating backup $OUT"
tar -czf "$OUT" -C "$CONFIG_DIR" .

echo "Rotating backups, keeping last $KEEP"
ls -1t "$BACKUP_DIR"/config-backup-*.tar.gz 2>/dev/null | tail -n +$((KEEP+1)) | xargs -r rm -f

echo "Backup completed"

echo "To restore: tar -xzf $OUT -C /path/to/target/config"
