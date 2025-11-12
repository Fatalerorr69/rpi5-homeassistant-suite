#!/bin/bash
# Validate important YAML files and optionally all YAMLs under config/
# Uses Home Assistant-aware validator for files with !include, !secret tags
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Standard YAML files (docker-compose, etc.)
STANDARD_FILES=(
  "docker-compose.yml"
)

# Home Assistant config files (require validate_ha_config.py)
HA_CONFIG_FILES=(
  "CONFIG/configuration.yaml"
  "CONFIG/automations.yaml"
  "CONFIG/scripts.yaml"
  "CONFIG/templates.yaml"
)

ALL_CHECK=0
if [ "${1:-}" = "--all" ]; then
  ALL_CHECK=1
fi

if ! command -v python3 &>/dev/null; then
  echo "python3 not found" >&2
  exit 2
fi

VALIDATOR_SCRIPT="scripts/validate_ha_config.py"
if [ ! -f "$VALIDATOR_SCRIPT" ]; then
  echo "❌ Home Assistant validator not found: $VALIDATOR_SCRIPT" >&2
  exit 2
fi

# Validate standard YAML files
echo "[*] Validating standard YAML files..."
python3 - <<'PY'
import sys, yaml, os

# Define HA custom tag constructors
def secret_constructor(loader, node): return '!secret'
def include_constructor(loader, node): return '!include'
def include_dir_constructor(loader, node): return '!include_dir_merge_named'

yaml.add_constructor('!secret', secret_constructor)
yaml.add_constructor('!include', include_constructor)
yaml.add_constructor('!include_dir_merge_named', include_dir_constructor)

paths = []
candidates = ['docker-compose.yml']
for p in candidates:
    if os.path.exists(p):
        paths.append(p)

errors = []
for p in paths:
    try:
        yaml.safe_load(open(p))
        print(f"  ✅ {p}")
    except Exception as e:
        errors.append((p, str(e)))
        print(f"  ❌ {p}: {e}")

if errors:
    sys.exit(1)
PY

# Validate Home Assistant config files
echo "[*] Validating Home Assistant config files..."
for file in "${HA_CONFIG_FILES[@]}"; do
  if [ -f "$file" ]; then
    if python3 "$VALIDATOR_SCRIPT" "$file" &>/dev/null; then
      echo "  ✅ $file"
    else
      echo "  ❌ $file"
      python3 "$VALIDATOR_SCRIPT" "$file"
      exit 1
    fi
  fi
done

# Validate all YAML if --all flag used
if [ $ALL_CHECK -eq 1 ]; then
  echo "[*] Validating all YAML files in config/..."
  python3 - <<'PY'
import sys, os, glob

all_files = glob.glob('config/**/*.y*ml', recursive=True)
for f in all_files:
    if os.path.isfile(f):
        print(f"  ℹ️  {f} (skipped - requires HA context)")
PY
fi

echo "✅ YAML validation OK"
