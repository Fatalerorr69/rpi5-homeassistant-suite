#!/bin/bash
# fix_docker_dns_and_compose.sh
# Automatická oprava DNS pro Docker + prodloužení timeoutu + spuštění docker compose
# Autor: Starko, 2025

set -euo pipefail
IFS=$'\n\t'

# -------------------------- Nastavení DNS --------------------------
echo "✅ Nastavuji DNS pro hostitele i Docker..."

# Hostitelský DNS
sudo bash -c 'echo "nameserver 1.1.1.1" > /etc/resolv.conf'
sudo bash -c 'echo "nameserver 8.8.8.8" >> /etc/resolv.conf'

# Docker DNS
sudo mkdir -p /etc/docker
echo '{ "dns": ["1.1.1.1", "8.8.8.8"] }' | sudo tee /etc/docker/daemon.json >/dev/null

# Restart NetworkManager (pokud je)
sudo systemctl restart NetworkManager || sudo systemctl restart networking
# Restart Docker
sudo systemctl restart docker

# -------------------------- Prodloužení timeoutů --------------------------
export DOCKER_CLIENT_TIMEOUT=300
export COMPOSE_HTTP_TIMEOUT=300
echo "✅ Prodloužené timeouty nastaveny (300s)"

# -------------------------- Kontrola připojení --------------------------
echo "ℹ️ Kontrola konektivity..."
ping -c3 google.com >/dev/null && echo "🌐 Internet OK" || echo "❌ Internet nefunguje!"
ping -c3 registry-1.docker.io >/dev/null && echo "🌐 Docker registry OK" || echo "❌ Docker registry nelze dosáhnout!"

# -------------------------- Docker Compose --------------------------
echo "🚀 Spouštím docker compose..."
cd ~/rpi5-homeassistant-suite || { echo "❌ Složka ~/rpi5-homeassistant-suite nenalezena!"; exit 1; }

docker compose down || true
docker compose pull --ignore-pull-failures
docker compose up -d

echo "✅ Docker compose spuštěn"
