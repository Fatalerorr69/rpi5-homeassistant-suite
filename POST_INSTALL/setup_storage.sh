#!/usr/bin/env bash
set -euo pipefail

echo "🗄️ Konfigurace NAS úložiště..."
read -p "Zvol typ NAS (1=Samba/CIFS, 2=NFS): " type
read -p "Zadej IP NAS serveru: " NAS_IP
read -p "Zadej sdílenou složku: " NAS_SHARE

if [ "$type" = "1" ]; then
    sudo apt install -y cifs-utils
    sudo mount -t cifs //$NAS_IP/$NAS_SHARE /mnt/nas -o username=guest,password=
elif [ "$type" = "2" ]; then
    sudo apt install -y nfs-common
    sudo mount -t nfs $NAS_IP:/$NAS_SHARE /mnt/nas
else
    echo "❌ Neznámý typ NAS, přeskočeno"
fi

echo "✅ NAS připojeno do /mnt/nas"
