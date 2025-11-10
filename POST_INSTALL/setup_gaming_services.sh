#!/bin/bash
# Nastavení herních služeb a serverů

echo "🎮 Nastavuji herní služby..."

# Minecraft server
mkdir -p ~/docker/gaming
cat > ~/docker/gaming/docker-compose.yml << 'DOCKEREOF'
version: '3.8'
services:
  minecraft:
    image: itzg/minecraft-server:latest
    ports:
      - "25565:25565"
    environment:
      EULA: "TRUE"
      TYPE: "PAPER"
    volumes:
      - ./minecraft_data:/data

  teamspeak:
    image: teamspeak:latest
    ports:
      - "9987:9987/udp"
      - "10011:10011"
      - "30033:30033"
    environment:
      TS3SERVER_LICENSE: accept
DOCKEREOF

echo "✅ Herní služby připraveny"
echo "Spusťte: cd ~/docker/gaming && docker-compose up -d"
