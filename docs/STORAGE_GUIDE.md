# Průvodce správou úložiště

Kompletní průvodce pro správu disku, zálohování a připojení externího úložiště.

## Analýza Current Disk Usage

Zjistěte, co zabírá místo:

```bash
./scripts/storage_analyzer.sh
```

Výstup ukazuje:
- Celkové využití disku
- Home Assistant config velikost
- Zálohování
- Docker volumes
- Největší soubory

## Disk Management

### Čištění a optimalizace

**Automaticky:**

```bash
docker system prune -f              # Smazat nepoužívané Docker artefakty
docker volume prune -f              # Smazat nepoužívané volumes
```

**Manuálně:**

```bash
find config/ -name "*.tmp" -delete   # Odstranit temp soubory
./scripts/backup_config.sh --keep 3  # Ponechat jen 3 poslední zálohování
```

### Monitorování disku

Nastavit weekly cleanup:

```bash
./POST_INSTALL/setup_maintenance.sh
# Vyberte: 2 (Čištění temp souborů) nebo 4 (Všechno)
```

Kontrola disku v reálném čase:

```bash
watch -n 1 'df -h / && echo "---" && du -sh config/ backups/'
```

## Zálohování

### Ruční záloha

```bash
./scripts/backup_config.sh              # Jednorázová záloha
./scripts/backup_config.sh --keep 10    # Ponechat 10 záloh
```

### Automatické zálohování (Cron)

```bash
./scripts/setup_cron_backup.sh install
./scripts/setup_cron_backup.sh status
```

Zálohování běží každých **12 hodin** automaticky.

### Obnovení ze zálohy

```bash
# Najít starší zálohování
ls -lh backups/

# Obnovit
tar -xzf backups/config-backup-20251111T120000.tar.gz -C config/
```

### Cloud backup (volitelné)

Synchronizace do S3/B2:

```bash
# Instalace rclone
curl https://rclone.org/install.sh | sudo bash

# Konfigurace
rclone config

# Sync
rclone sync backups/ remote:ha-backups/
```

## Externí úložiště

### USB disk

**Připojit USB disk:**

```bash
./scripts/mount_storage.sh list       # Vypsat dostupná zařízení
./scripts/mount_storage.sh mount      # Interaktivní připojení
```

**Trvalé připojení (přes fstab):**

```bash
./scripts/mount_storage.sh auto-mount
```

### NAS (Network Attached Storage)

**Připojit NAS přes SMB:**

```bash
sudo apt-get install -y cifs-utils

# Ručně
sudo mount -t cifs //nas-ip/share /mnt/nas -o username=user,password=pass

# V fstab
//nas-ip/share  /mnt/nas  cifs  username=user,password=pass,uid=1000,gid=1000  0  0
```

**Připojit NAS přes NFS:**

```bash
sudo apt-get install -y nfs-common

# Ručně
sudo mount -t nfs nas-ip:/export/ha /mnt/nas

# V fstab
nas-ip:/export/ha  /mnt/nas  nfs  defaults  0  0
```

### Přesun konfigurace na externí disk

```bash
# Zatím Docker
docker-compose stop

# Zkopírovat config na externí disk
cp -a config/ /mnt/storage/ha-config-backup/

# Upravit docker-compose.yml
# Změnit:   ./config:/config
# Na:       /mnt/storage/ha-config:/config

docker-compose up -d
```

## Samba (Network Share)

Sdílení souborů na síti:

```bash
./POST_INSTALL/setup_file_explorer.sh
# Vyberte: 1 (Samba)
```

**Připojení z Windows:**

```
\\<ip-adresa>\homeassistant-config
```

**Připojení z Linux/Mac:**

```bash
mount_smbfs //user@<ip-adresa>/homeassistant-config /mnt/ha-config
```

## SFTP (SSH File Transfer)

Přenos souborů přes SSH:

```bash
# Z místního počítače
sftp -r user@<pi-ip>:/home/user/config ./backup/

# Nahrát zpět
sftp -r ./config/* user@<pi-ip>:/home/user/config/
```

## Web File Manager

Přístup k souborům webovým rozhraním:

```bash
./POST_INSTALL/setup_file_explorer.sh
# Vyberte: 4 (Web UI)

# Spusťte
cd config/ && python3 -m http.server 8888

# Přístup
http://<pi-ip>:8888
```

## Docker Volume Management

### Backup volumes

```bash
# Zjistit volumes
docker volume ls

# Backup volume
docker run --rm -v ha_config:/data -v $(pwd)/backups:/backup \
  alpine tar czf /backup/volume-$(date +%s).tar.gz -C /data .
```

### Cleanup volumes

```bash
docker volume prune       # Odstranit nepoužívané
docker volume rm <name>   # Smazat konkrétní
```

## Disk Quotas (volitelné)

Omezit využití disk kvót:

```bash
# Instalace
sudo apt-get install -y quota quotatool

# Nastavit kvótu pro uživatele
sudo setquota -u $(whoami) 10G 12G 0 0 /

# Kontrola
sudo quota -u $(whoami)
```

## Best Practices

### ✅ Doporučení

1. **Minimálně 2 kopie** — Jedna v `backups/`, jedna na externím disku
2. **Měsíční off-site backup** — Pravidelně stahujte zálohování mimo zařízení
3. **Monitorování disku** — Běží health check každou hodinu (pokud nastaveno)
4. **Logování** — Aktivní cleanup a rotation (`setup_maintenance.sh`)
5. **Testování obnovy** — Jednou za čtvrt roku zkuste obnovit ze zálohy

### ❌ Běžné chyby

- Všechny zálohování na **jednom disku** (riziko selhání)
- Nikdy **nezálohovat config** během běhu Home Assistant
- Zapomínat na **stará zálohování** (zabírají místo)
- Nenastavit **cron backup** (pouze ruční = zapomínáte)

## Troubleshooting

### Disk je plný

```bash
# Zjistit co zabírá místo
du -sh /* | sort -rh

# Cleanup
docker system prune -a -f
./scripts/backup_config.sh --keep 3
```

### NAS/USB se automaticky odpojil

```bash
# Zkontrolovat fstab
cat /etc/fstab

# Znovu připojit
sudo mount -a

# Kontrola
mount | grep ha-
```

### Záloha je velká

```bash
# Zkomprimovat lépe
tar -cf - config/ | bzip2 > backup.tar.bz2

# Inkrementální záloha
tar -czf backup-$(date +%Y%m%d).tar.gz -N config/
```

## Reference

- Bash disk commands: `df`, `du`, `lsblk`, `mount`
- Docker cleanup: `docker system prune`, `docker volume prune`
- NAS: SMB, NFS, CIFS
- Remote: rclone, rsync, restic
