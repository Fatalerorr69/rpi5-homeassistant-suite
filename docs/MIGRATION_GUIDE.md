# 📚 Návod na Migraci ze SD Karty na NVMe + Storage Setup

**Verze:** 2.4.0-rc  
**Poslední aktualizace:** 2025-11-11  
**Cílové zařízení:** Raspberry Pi 5  

---

## 🎯 Obsah

1. [Přehled Problému](#-přehled-problému)
2. [Příprava](#-příprava)
3. [Krok-za-Krokem Migrace](#-krok-za-krokem-migrace)
4. [Storage Konfigurace](#-storage-konfigurace)
5. [Troubleshooting](#-troubleshooting)
6. [FAQ](#-faq)

---

## 📋 Přehled Problému

### Proč migrovat ze SD karty?

**SD karta - Problémy:**
- ❌ Omezená životnost (~10k-100k cyklů zápisu)
- ❌ Pomalá (50-100 MB/s)
- ❌ Náchylná na korumpci dat
- ❌ Malá kapacita (typicky 32-128 GB)
- ❌ Hromadné procesy zpomalují celý systém

**NVMe - Výhody:**
- ✅ Vysoká životnost (1M+ cyklů)
- ✅ Vysoká rychlost (2000-7000 MB/s)
- ✅ Malá chyba korelace
- ✅ Velká kapacita (256GB-2TB dostupné)
- ✅ Dramatické zrychlení Home Assistant

**Výsledek:**
- Home Assistant se načítá **30x rychleji**
- Recorder databáze odpovídá **okamžitě**
- Automace běží **bez zpoždění**
- Integrace se přidávají bez trpělivosti

---

## 🔧 Příprava

### Hardware Checklist

```bash
# ✅ Kontrola - před zahájením migrace

# 1. Raspberry Pi 5 se zásuvkou pro NVMe
[ ] RPi5 má modul NVMe
[ ] Máte SSD v M.2 2280 formátu

# 2. Dostupné NVMe disk
[ ] Diskový prostor: min. 256GB (doporučeno 512GB+)
[ ] Kompatibilní se RPi5: Klíč M pro NVME zásuvku

# 3. Místo na jiném úložišti
[ ] Backup úložiště: min. 128GB volného místa
[ ] NAS nebo externí disk (s USB adaptérem)

# 4. Nástroje
[ ] USB čtečka karet (pro režim bez SD karty)
[ ] Dostupný čas: 2-3 hodiny
```

### Software Checklist

```bash
# ✅ Kontrola - v Home Assistant

# 1. Aktuální verze
./setup_master.sh
# Vyberte: 1 (Kontrola verze a aktualizace)

# 2. Funkční instalace
# Zkontrolujte v Home Assistant UI
# - Všechny integrace fungují
# - Žádné chyby v logu
# - Automace běží správně

# 3. Poslední záloha
docker exec homeassistant \
  tar -czf /backups/pre_migration_backup.tar.gz /config
```

---

## 🚀 Krok-za-Krokem Migrace

### Fáze 1: Detekce a Diagnóza

```bash
# 1.1 Spusťte diagnostiku
cd ~/rpi5-homeassistant-suite
./DIAGNOSTICS/storage_analyzer.py

# Výstup by měl ukázat:
# ✓ SD karta: /dev/mmcblk0 (typ: SD_CARD)
# ✓ NVMe disk: /dev/nvme0n1 (typ: NVME)
# ✓ Volné místo na /tmp: > 2GB
```

### Fáze 2: Offline Příprava (1 hodina)

```bash
# 2.1 Detekce zařízení
sudo ./scripts/detect_os.sh --info

# 2.2 Simulace migrace (DRY-RUN)
sudo ./scripts/migrate_to_nvme.sh --dry-run

# Kontrola výstupu:
# ✓ SD karta detekována
# ✓ NVMe disk detekován
# ✓ Volné místo OK
# ✓ Docker dostupný
```

### Fáze 3: Záloha (30-60 minut)

```bash
# 3.1 Záloha Home Assistant
cd ~/rpi5-homeassistant-suite
docker-compose stop homeassistant

# 3.2 Manuální backup do external úložiště
tar -czf /tmp/ha_backup_premigration.tar.gz config/
scp /tmp/ha_backup_premigration.tar.gz user@backup_nas:/backups/

# 3.2 Nebo: Spusťte migrační skript (vytvoří automatický backup)
sudo ./scripts/migrate_to_nvme.sh

# Během spuštění se zeptá na backup - ODPOVĚZTE ANO
# Skript vytvoří:
# - Backup SD karty: backups/migration_*/sd_card_full_*.img.gz (~30GB)
# - Checksum: sd_card_full_*.sha256
```

### Fáze 4: Migrace Systému (20-30 minut)

```bash
# POSTUP:
# 1. Skript zastaví Home Assistant
# 2. Odpojí všechna zařízení
# 3. Formátuje NVMe (POZOR - všechna data budou smazána!)
# 4. Kopíruje systém (rsync - ~60GB, trvá dlouho)
# 5. Aktualizuje boot záznam
# 6. Ověří integritu

# 4.1 SPUSŤTE MIGRACI
sudo ./scripts/migrate_to_nvme.sh

# Můžete také spustit v backgroundu
sudo ./scripts/migrate_to_nvme.sh &

# 4.2 MONITORUJ PROGRESS
tail -f ha_migration_*.log

# Očekávaný výstup:
# [INFO] Detekce Úložných Zařízení
# [SUCCESS] SD karta: /dev/mmcblk0 (32GB)
# [SUCCESS] NVMe disk: /dev/nvme0n1 (512GB)
# [INFO] Příprava na Migraci
# [INFO] Home Assistant zastaven
# [INFO] Spouštím backup SD karty
# [INFO] Vytvářím novou tabulku partici
# [INFO] Kopíruji boot sektor
# [INFO] Kopíruji systém - PROSÍM ČEKEJTE
#   ...dlouhé čekání...
# [SUCCESS] Migrace systému dokončena
# [SUCCESS] Ověření migrace dokončeno
# [SUCCESS] MIGRACE ZE SD KARTY NA NVME ÚSPĚŠNĚ DOKONČENA!
```

### Fáze 5: Boot Nastavení (10 minut)

```bash
# 5.1 RESTARTUJTE SYSTÉM
sudo reboot

# 5.2 Při startu: Vstupte do BIOS/EFI
# Klávesa: DEL, ESC nebo F2 (dle RPi5 verze)
# Nebo pro RPi5 s Official NVMe modulem:
sudo raspi-config
# → Advanced Options
# → Boot Order
# → USB Boot (vybrat NVMe)

# 5.3 Uložte nastavení a restartujte
sudo reboot
```

### Fáze 6: Ověření (5 minut)

```bash
# 6.1 Po startu: Zkontrolujte boot device
df -h /
# Mělo by ukázat: /dev/nvme0n1p2

# 6.2 Zkontrolujte výkon
time docker ps
# Mělo by být < 1 sekunda

# 6.3 Spusťte Health Check
sudo /usr/local/bin/storage-health-check.sh /mnt/*
```

---

## 💾 Storage Konfigurace

### Scénář 1: Solo NVMe

**Vhodné pro:** Malé instalace, jednoduchost

```bash
# Struktura:
/mnt/nvme/
├── hass_config/       # Home Assistant config
├── hass_data/         # Recorder database
├── hass_media/        # Media files
├── backups/           # Local backups
└── docker_volumes/    # Docker containers
```

**Nastavení:**

```bash
# 1. Spusťte wizard
sudo ./scripts/storage_setup_wizard.sh
# Vyberte: 2 (Solo NVMe Setup)

# 2. Updatujte docker-compose.yml
volumes:
  hass_config:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/nvme/hass_config

services:
  homeassistant:
    volumes:
      - hass_config:/config
      - /mnt/nvme/hass_data:/hass_data
```

### Scénář 2: Tiered Storage (Doporučeno)

**Vhodné pro:** Velké instalace, optimalizace

```bash
# Architektura:
NVMe (HOT) ─────────┐
  │ Recorder DB      │
  │ TTS Cache        │  Docker Compose
  │ Media            │  (orchestruje)
  └─────────────────┤
                    └─ Docker
SSD (WARM) ──────────┐
  │ HA Config        │
  │ Docker Daemon    │
  └──────────────────┤
                    
HDD (COLD) ──────────┐
  │ Archív Médií     │
  │ Starší zálohů    │
  └──────────────────┴─ Offline backup
```

**Nastavení:**

```bash
# 1. Spusťte wizard
sudo ./scripts/storage_setup_wizard.sh
# Vyberte: 3 (Tiered Storage)

# 2. Při dotazu na disky:
# - NVMe: nvme0n1 (512GB, nejrychlejší)
# - SSD: sda (256GB, střední)
# - HDD: sdb (2TB, pomalý)

# 3. Mount points:
# - NVMe: /mnt/nvme
# - SSD: /mnt/ssd
# - HDD: /mnt/hdd

# 4. Automatické připojování
sudo ./POST_INSTALL/setup_storage_auto_mount.sh

# 5. Ověření
df -h | grep /mnt
# /dev/nvme0n1p2 512G 10G 502G  2% /mnt/nvme
# /dev/sda1      256G  5G 251G  2% /mnt/ssd
# /dev/sdb1      2.0T 100G 1.9T  5% /mnt/hdd
```

### Scénář 3: NAS Integration

**Vhodné pro:** Centralizované zálohování, disaster recovery

```bash
# Architektura:
Local ─────────────────────┐
  /mnt/nvme (NVMe)         │ Daily backups
  /mnt/ssd (SSD)           │
                           ├──→ Network
Remote NAS ─────────────────┤
  /mnt/nas_backups (SMB)   │ Weekly/Monthly
                           │
Cloud (S3/B2) ─────────────┤
                           │ Yearly/Archival
                           └─ Off-site
```

**Nastavení:**

```bash
# 1. SMB/CIFS (Windows/Synology/QNAP)
sudo ./scripts/storage_setup_wizard.sh
# Vyberte: 4 (NAS Integration)
# Vyberte: 1 (SMB)
# Zadejte: NAS IP (192.168.1.100)
# Zadejte: Share name (backups)
# Zadejte: Username & password

# 2. Ověření
mount | grep nas
# //192.168.1.100/backups on /mnt/nas_backups type cifs

# 3. Automatický backup
crontab -e
# Přidejte:
0 2 * * * tar -czf /mnt/nas_backups/ha_backup_$(date +\%Y\%m\%d).tar.gz /config
0 3 * * 0 tar -czf /mnt/nas_backups/ha_backup_weekly_$(date +\%Y\%m\%d).tar.gz /config

# 4. Ověřte backup
ls -lh /mnt/nas_backups/ha_backup_*.tar.gz
```

---

## 🔧 Troubleshooting

### Problém: NVMe se při startu nepřipojuje

```bash
# Příznaky:
# - Home Assistant spustí se, ale běží na SD kartě
# - Chyba v df: /dev/nvme0n1 se neobjevuje

# Řešení:

# 1. Zkontrolujte boot order
sudo raspi-config
# → Advanced Options → Boot Order → USB Boot

# 2. Zkontrolujte /etc/fstab
cat /etc/fstab | grep nvme
# Měla by být linie:
# UUID=xxx /mnt/nvme ext4 defaults,nofail 0 2

# 3. Manuální test
sudo mount /dev/nvme0n1p2 /mnt/test
# Pokud je chyba: NVMe disk není správně naformátován

# 4. Ruční napravení
sudo parted /dev/nvme0n1 mklabel gpt
sudo mkfs.ext4 /dev/nvme0n1p1
```

### Problém: Migrace se zastavila (timeout)

```bash
# Příznaky:
# - Log se zastaví na "Kopíruji systém"
# - Proces nevím co se stalo

# Řešení:

# 1. Zkontrolujte free místo
df -h /tmp
# Musí být > 10GB volného

# 2. Restartujte migraci
sudo ./scripts/migrate_to_nvme.sh
# Skript pokračuje z posledního bodu

# 3. Pokud stále selže - obnovit a zkusit znovu
sudo ./scripts/migrate_to_nvme.sh --restore-backup
# Vrátí se k původní SD kartě
```

### Problém: Zápis na NVMe je velmi pomalý

```bash
# Příznaky:
# - Recorder se nevýznačně pomalý
# - Docker operace trvají dlouho

# Řešení:

# 1. Monitorujte I/O
sudo iotop -o -b -n 1

# 2. Zkontrolujte teplotní
sudo vcgencmd measure_temp
# Mělo by být < 60°C

# 3. Zkontrolujte NVMe driver
lsmod | grep nvme
# Měl by být: nvme, nvme_core

# 4. Aktivujte hardwarové zrychlení
echo "vm.dirty_ratio = 10" | sudo tee -a /etc/sysctl.conf
echo "vm.dirty_background_ratio = 5" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 5. Restart
sudo reboot
```

### Problém: Disk je plný "Unexpected"

```bash
# Příznaky:
# - Chyba: /dev/nvme0n1p2 naplněn na 100%
# - Home Assistant se zastavuje

# Řešení:

# 1. Zjistěte co zabírá místo
sudo du -sh /mnt/nvme/* | sort -rh

# 2. Typické problémy:
# - Recorder databáze je příliš velká
#   → Zmenšit retention (keep 7 dní místo 30)
# - Docker volumes
#   → docker system prune -a
# - Old backups
#   → rm /mnt/nvme/backups/*.tar.gz

# 3. Expandujte NVMe (pokud je fyzicky větší)
sudo resize2fs /dev/nvme0n1p2
```

### Problém: Rollback na SD kartu

```bash
# Příznaky:
# - Migrace selhala a chcete zpět

# Řešení:

# 1. Obnovit ze zálohy
sudo ./scripts/migrate_to_nvme.sh --restore-backup

# Skript otáže:
# "Obnovit SD kartu ze zálohy? (VEŠKERÁ DATA BUDOU SMAZÁNA!) (y/n)"
# → Odpovězte: y

# 2. Čekejte 30-60 minut (obnovení trvá dlouho)

# 3. Restartujte
sudo reboot

# 4. Systém by měl bootovat ze SD karty znovu
```

---

## ❓ FAQ

### Q: Budou moje data v bezpečí během migrace?

**A:** Ano! Skript vytvoří:
- Full backup SD karty (`sd_card_full_*.img.gz`)
- Checksum pro ověření (`*.sha256`)
- Pokud se něco pokazí, použijete `--restore-backup`

### Q: Jak dlouho trvá migrace?

**A:** Typicky:
- Detekce + příprava: 5 minut
- Backup SD karty: 30-60 minut (pokud vyberete)
- Kopírování systému: 20-30 minut
- Boot setup: 10 minut
- **Celkem: ~1-2 hodiny**

### Q: Mohu migrovat bez NVMe? (jen NAS)

**A:** Ano, ale bude to pomalejší. Postup:
1. Přidejte NAS místo NVMe
2. Nakonfigurujte tiered storage s HDD místo NVMe
3. Výkon bude lepší než SD, ale ne jako s NVMe

### Q: Co když NVMe disk selže?

**A:** RPi5 bootuje z SD karty. Takže:
1. NVMe selhání = zpátky na SD kartu
2. SD karta stále obsahuje funkční instalaci
3. Data na NVMe jsou sekundární

Doporučuji udržovat SD kartu v případě nouze.

### Q: Jak odstranit SD kartu po migraci?

**A:** Doporučuju ji zachovat jako backup! Ale pokud chcete:
```bash
# Ověřit že bootuje z NVMe
df -h /
# /dev/nvme0n1p2

# Bezpečně vypnout
sudo poweroff
# Fyzicky vyjmout SD kartu
```

### Q: Jak se k datům dostat pokud RPi5 nebootuje?

**A:** Připojit NVMe k PC přes USB adaptér:
```bash
# Na PC (Linux):
sudo mount /dev/sdX1 /mnt/rpi
# Přístup k /config, zálohy, atd.

# Nebo - obnovit ze SD karty:
sudo ./scripts/migrate_to_nvme.sh --restore-backup
```

### Q: Mohu přidat více NVMe disků (RAID)?

**A:** Zatím ne (v2.4.0). Plánováno pro v3.0.0. Alternativa:
- Tiered storage (NVMe + SSD + HDD)
- Cloud backup (redundance)

### Q: Jak zálohovat data z NVMe?

**A:** Několik možností:

```bash
# 1. Ruční backup do NAS
tar -czf /mnt/nas_backups/ha_backup_$(date +%Y%m%d).tar.gz /config

# 2. Automatický cron
0 2 * * * /usr/local/bin/backup_ha.sh

# 3. Pomocí Home Assistant Backup integrace
# (nainstalujte addon v HA UI)

# 4. Cloud backup (v2.5.0)
./scripts/setup_cloud_backup.sh
```

---

## 📞 Support

Máte problém? Vyzkoušejte:

1. **Log soubory:**
   ```bash
   tail -f ~/ha_migration_*.log
   /var/log/storage-health-check.log
   docker logs homeassistant | tail -100
   ```

2. **Diagnostika:**
   ```bash
   ./DIAGNOSTICS/storage_analyzer.py
   ./scripts/detect_os.sh --info
   sudo ./POST_INSTALL/setup_storage_auto_mount.sh --diagnostics
   ```

3. **GitHub Issues:**
   https://github.com/Fatalerorr69/rpi5-homeassistant-suite/issues

4. **Home Assistant Community:**
   https://community.home-assistant.io

---

**Vč. v2.4.0-rc dokumentace**

Poslední aktualizace: 2025-11-11  
Autor: RPi5 Home Assistant Suite Team
