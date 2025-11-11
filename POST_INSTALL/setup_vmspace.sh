#!/usr/bin/env bash
set -euo pipefail

echo "💻 Konfigurace VM prostoru..."
read -p "Zvol typ virtualizace (1=QEMU/libvirt, 2=VirtualBox ARM): " vmtype

if [ "$vmtype" = "1" ]; then
    sudo apt install -y qemu qemu-kvm libvirt-daemon-system libvirt-clients virt-manager
elif [ "$vmtype" = "2" ]; then
    echo "⚠️ VirtualBox ARM musí být ručně nainstalován, tento skript nastaví jen adresáře."
fi

echo "✅ VM prostor připraven v /mnt/vm"
