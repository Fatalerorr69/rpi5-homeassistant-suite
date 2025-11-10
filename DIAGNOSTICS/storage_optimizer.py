#!/usr/bin/env python3
"""
Skript pro optimalizaci úložišť podle doporučení
"""

import os
import subprocess
from pathlib import Path

def optimize_storage_layout():
    """Vytvoří optimální adresářovou strukturu"""
    
    print("🔄 Vytvářím optimální adresářovou strukturu...")
    
    # Definice optimální struktury
    structure = {
        '/mnt/nvme': [
            'hass_data',           # Recorder databáze
            'hass_media',          # Media soubory
            'hass_recordings',     # Nahrávky kamer
            'hass_tts',           # TTS cache
            'mariadb/data',       # MySQL data
            'mosquitto/data',     # MQTT data
            'backups/daily'       # Denní zálohy
        ],
        '/mnt/sdcard': [
            'backups/weekly',     # Týdenní zálohy
            'backups/monthly',    # Měsíční zálohy
            'logs/archive',       # Archivované logy
            'temp'                # Dočasné soubory
        ],
        '/mnt/hdd': [
            'backups/yearly',     # Roční zálohy
            'media_archive',      # Archiv médií
            'recordings_archive'  # Archiv nahrávek
        ]
    }
    
    # Vytvoření adresářů
    for base_path, directories in structure.items():
        if os.path.exists(base_path):
            for directory in directories:
                full_path = os.path.join(base_path, directory)
                os.makedirs(full_path, exist_ok=True)
                print(f"✅ Vytvořeno: {full_path}")
                
                # Nastavení správných oprávnění
                uid = os.getuid()
                gid = os.getgid()
                os.chown(full_path, uid, gid)
        else:
            print(f"⚠️  Základní cesta neexistuje: {base_path}")
    
    print("🎯 Optimální struktura vytvořena!")

def setup_auto_mount():
    """Nastaví automatické připojování disků"""
    
    fstab_entries = [
        "# Home Assistant optimal storage layout",
        "/dev/disk/by-id/nvme-SAMSUNG_MZVL2512HCJQ-00BL7_CXCS1R2NC0XXXX /mnt/nvme ext4 defaults,nofail 0 2",
        "/dev/disk/by-id/mmc-SD32G_0x97cdeae4 /mnt/sdcard ext4 defaults,nofail 0 2",
        "/dev/disk/by-id/usb-Samsung_SSD_860_EVO_500GB_S4AZNF0N123456X /mnt/hdd ext4 defaults,nofail 0 2"
    ]
    
    print("📝 Přidávám záznamy do /etc/fstab...")
    
    try:
        with open('/etc/fstab', 'a') as f:
            f.write('\n'.join(fstab_entries) + '\n')
        print("✅ Záznamy přidány do /etc/fstab")
    except PermissionError:
        print("❌ Nelze upravit /etc/fstab - spusťte skript jako root")

def generate_migration_commands():
    """Vygeneruje příkazy pro migraci dat"""
    
    commands = [
        "# Migrace recorder databáze na NVMe",
        "sudo systemctl stop home-assistant",
        "cp /config/home-assistant_v2.db /mnt/nvme/hass_data/",
        "sudo chown homeassistant:homeassistant /mnt/nvme/hass_data/home-assistant_v2.db",
        
        "# Migrace media souborů",
        "cp -r /config/media/* /mnt/nvme/hass_media/",
        
        "# Nastavení zálohování",
        "echo '0 2 * * * tar -czf /mnt/sdcard/backups/daily/ha_backup_$(date +%Y%m%d).tar.gz /config' | crontab -"
    ]
    
    print("🔄 PŘÍKAZY PRO MIGRACI DAT:")
    print("\n".join(commands))

if __name__ == "__main__":
    optimize_storage_layout()
    setup_auto_mount()
    generate_migration_commands()