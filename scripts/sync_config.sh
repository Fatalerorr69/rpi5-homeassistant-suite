#!/bin/bash
# Synchronize CONFIG/ -> config/ and optionally validate YAML files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$REPO_ROOT/CONFIG"
DST_DIR="$REPO_ROOT/config"

usage() {
  cat <<EOF
Usage: $0 [-n|--dry-run] [-f|--force] [-v|--validate]
  -n, --dry-run   Show what would be copied (rsync --dry-run)
  -f, --force     Overwrite without prompting
  -v, --validate  Validate YAML files after sync (requires python3 + PyYAML)
EOF
  exit 1
}

DRY_RUN=0
FORCE=0
VALIDATE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1; shift ;;
    -f|--force) FORCE=1; shift ;;
    -v|--validate) VALIDATE=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

if [ ! -d "$SRC_DIR" ]; then
  echo "Source CONFIG directory not found: $SRC_DIR" >&2
  exit 1
fi

mkdir -p "$DST_DIR"

RSYNC_OPTS=( -a --delete )
if [ "$DRY_RUN" -eq 1 ]; then
  RSYNC_OPTS+=( --dry-run --itemize-changes )
fi

if command -v rsync &>/dev/null; then
  echo "Syncing $SRC_DIR/ -> $DST_DIR/"
  rsync "${RSYNC_OPTS[@]}" "$SRC_DIR/" "$DST_DIR/"
else
  echo "rsync not found, falling back to cp -a"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: would copy files from $SRC_DIR to $DST_DIR"
  else
    if [ "$FORCE" -eq 1 ]; then
      rm -rf "$DST_DIR"/* || true
    fi
    cp -a "$SRC_DIR/." "$DST_DIR/"
  fi
fi

if [ "$VALIDATE" -eq 1 ]; then
  if ! command -v python3 &>/dev/null; then
    echo "Python3 not found, skipping validation" >&2
    exit 0
  fi
  python3 - <<PY
import sys, os, glob
try:
    import yaml
except Exception as e:
    print('PyYAML not available: %s' % e, file=sys.stderr)
    sys.exit(2)

errors = []
for root,_,files in os.walk('config'):
    for fn in files:
        if fn.endswith(('.yaml','.yml')):
            path = os.path.join(root,fn)
            try:
                yaml.safe_load(open(path))
            except Exception as e:
                errors.append((path,str(e)))

if errors:
    print('YAML validation errors:')
    for p,e in errors:
        print(p, e)
    sys.exit(1)
else:
    print('✅ YAML validation passed for all files under config/')
    sys.exit(0)
PY
fi

echo "Sync completed."
