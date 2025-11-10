#!/bin/bash
# Automatické nastavení mount pointů pro optimalizované úložiště

echo "🗂️ Nastavuji automatické připojování úložišť..."

# Vytvoření adresářové struktury
sudo mkdir -p /mnt/{nvme,sdcard,hdd,usbssd}
sudo mkdir -p /mnt/nvme/{hass_data,media,recordings,tts_cache}
sudo mkdir -p /mnt/sdcard/{backups,logs_archive,temp}
sudo mkdir -p /mnt/hdd/{media_archive,long_term_backups}

# Přidání do fstab (příklad - UPRAVIT podle skutečných zařízení)
echo "# Home Assistant optimal storage" | sudo tee -a /etc/fstab
echo "/dev/sda1 /mnt/nvme ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
echo "/dev/sdb1 /mnt/sdcard ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

# Nastavení oprávnění
sudo chown -R starko:starko /mnt/{nvme,sdcard,hdd,usbssd}

echo "✅ Automatické mount pointy nastaveny"
