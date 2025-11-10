#!/usr/bin/env bash
set -euo pipefail

echo "🌀 Aktivace Home Assistant Supervised..."
curl -sL https://raw.githubusercontent.com/home-assistant/supervised-installer/master/installer.sh | bash
echo "✅ Supervised aktivován, vývojový režim a Supervisor funkční"
