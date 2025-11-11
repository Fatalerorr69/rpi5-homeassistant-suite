#!/bin/bash
# Post-install helper: create config subdirs, copy example packages, and remind next steps
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config"
TEMPLATES_DIR="$REPO_ROOT/TEMPLATES/package_examples"

echo "Preparing runtime config structure under $CONFIG_DIR"
mkdir -p "$CONFIG_DIR/packages" "$CONFIG_DIR/zigbee2mqtt" "$CONFIG_DIR/mosquitto" "$CONFIG_DIR/node-red" "$CONFIG_DIR/portainer"

if [ -d "$TEMPLATES_DIR" ]; then
  echo "Copying example package templates to $CONFIG_DIR/packages"
  cp -a "$TEMPLATES_DIR/"* "$CONFIG_DIR/packages/" || true
else
  echo "No template package_examples found in $TEMPLATES_DIR"
fi

echo "Setting basic permissions (dialout for Zigbee, docker group for socket access)"
sudo usermod -aG dialout $(whoami) || true

echo "Post-install tasks done. Next steps:\n - run: ./scripts/sync_config.sh --force --validate\n - start services: docker-compose up -d\n - if using supervised installer follow setup_master.sh options"
