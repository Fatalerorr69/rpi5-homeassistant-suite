#!/bin/bash
# Validate important YAML files and optionally all YAMLs under config/
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

FILES=(
  "docker-compose.yml"
  "CONFIG/configuration.yaml"
  "CONFIG/automation.yaml"
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

python3 - <<PY
import sys, yaml, os, glob
paths = []
prelist = ${ALL_CHECK}
if prelist:
    for p in glob.glob('config/**/*.y*ml', recursive=True):
        paths.append(p)
else:
    candidates = ${FILES}
    for p in candidates:
        if os.path.exists(p):
            paths.append(p)

errors = []
for p in paths:
    try:
        yaml.safe_load(open(p))
    except Exception as e:
        errors.append((p,str(e)))

if errors:
    print('YAML validation failed:')
    for p,e in errors:
        print(p, e)
    sys.exit(1)
else:
    print('✅ YAML validation OK')
    sys.exit(0)
PY
