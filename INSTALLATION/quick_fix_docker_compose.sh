#!/bin/bash
# quick_fix_docker_compose.sh

echo "Oprava Docker Compose..."

# Instalace docker-compose-plugin
sudo apt update
sudo apt install -y docker-compose-plugin

# Kontrola
if docker compose version &> /dev/null; then
    echo "✅ docker compose funguje"
    COMPOSE_CMD="docker compose"
elif docker-compose version &> /dev/null; then
    echo "✅ docker-compose funguje" 
    COMPOSE_CMD="docker-compose"
else
    echo "Instalace docker-compose přes pip..."
    sudo apt install -y python3-pip
    sudo pip3 install docker-compose
    COMPOSE_CMD="docker-compose"
fi

# Spuštění služeb
cd /home/starko/docker-compose
$COMPOSE_CMD up -d

echo "Služby by měly být spuštěny"
docker ps
