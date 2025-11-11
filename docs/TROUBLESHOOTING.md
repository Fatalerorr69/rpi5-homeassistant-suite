# Troubleshooting průvodce

Běžné problémy a jejich řešení.

## Problémy s instalací

### Chyba: "Skript musí být spuštěn z adresáře s docker-compose.yml"

**Řešení:** Ujistěte se, že jste v kořenovém adresáři repozitáře:

```bash
cd /path/to/rpi5-homeassistant-suite
./setup_master.sh
```

### Chyba: "Nelze nainstalovat PyYAML"

**Řešení:** Nainstalujte PyYAML ručně:

```bash
sudo apt-get update
sudo apt-get install -y python3-yaml
```

Nebo přes pip:

```bash
sudo pip3 install pyyaml
```

### Chyba: "Sudo heslo vyžadováno"

**Řešení:** Skripty mají přístup k sudo bez hesla (nastaveno během `install.sh`). Pokud problém přetrvává:

```bash
sudo visudo
# Přidejte: username ALL=(ALL) NOPASSWD: ALL
```

## Problémy s konfigurací

### Chyba: "YAML validation failed"

**Řešení:** Zkontrolujte formátování v `CONFIG/`:

```bash
python3 << PY
import yaml
try:
    yaml.safe_load(open('CONFIG/configuration.yaml'))
    print("OK")
except Exception as e:
    print(f"Error: {e}")
PY
```

Běžné problémy v YAML:
- Špatný indent (použijte mezery, ne taby)
- Chybějící přesune řádku
- Chybný formát seznamu

### Chyba: "config/ je prázdný"

**Řešení:** Synchronizujte CONFIG/:

```bash
./scripts/sync_config.sh --force --validate
```

Zkontrolujte, že `config/` je vytvořen a má soubory:

```bash
ls -la config/
```

## Problémy s Docker službami

### Home Assistant neběží

**Řešení:** Zkontrolujte logy:

```bash
docker logs homeassistant
```

Spusťte služby znovu:

```bash
docker-compose down
docker-compose up -d
```

Diagnostika:

```bash
docker ps
docker-compose ps
```

### Mosquitto nespustitelný

**Řešení:** Ujistěte se, že konfigurace je správná:

```bash
ls -la config/mosquitto/
```

Zkontrolujte opravnění:

```bash
sudo chown -R 1883:1883 config/mosquitto/
```

Restartujte:

```bash
docker-compose restart mosquitto
```

### Zigbee2MQTT se nemůže připojit k zařízení

**Řešení:** Zkontrolujte device mapping a oprávnění:

```bash
# Seznámit se se zařízením
ls -la /dev/ttyUSB*
```

Ujistěte se, že jste v `dialout` skupině:

```bash
groups $(whoami)
# Měl by zahrnovat: dialout
```

Pokud ne:

```bash
sudo usermod -aG dialout $(whoami)
# Odhlašte se a přihlašte znovu
```

Zkontrolujte v `docker-compose.yml`:

```yaml
zigbee2mqtt:
  devices:
    - /dev/ttyUSB0:/dev/ttyUSB0
```

## Problémy s výkonem

### Disk je plný

**Řešení:** Běžte optimalizaci:

```bash
./setup_master.sh
# Vyberte možnost 7: Optimalizace úložišť
```

Nebo ručně:

```bash
docker system prune -f
./scripts/backup_config.sh --keep 3
```

Zkontrolujte velikost:

```bash
du -sh config/
docker system df
```

### Vysoké využití RAM

**Řešení:** Restartujte služby:

```bash
docker-compose restart
```

Zkontrolujte, co spotřebovává RAM:

```bash
docker stats
free -h
```

## Problémy s oprávněními

### Chyba: "Permission denied" při spuštění skriptu

**Řešení:** Nastavte oprávnění:

```bash
chmod +x setup_master.sh install.sh
chmod +x scripts/*.sh
chmod +x POST_INSTALL/*.sh
```

### Docker příkaz selhává

**Řešení:** Přidejte se do docker skupiny:

```bash
sudo usermod -aG docker $(whoami)
# Odhlašte se a přihlašte znovu
newgrp docker
```

## Problémy se síťovým připojením

### Nelze přistoupit na `homeassistant.local`

**Řešení:** Zkontrolujte IP adresu:

```bash
hostname -I
```

Přistupte přes IP adresu:

```bash
http://<IP_ADRESA>:8123
```

Zkontrolujte, zda je Home Assistant spuštěn:

```bash
curl http://localhost:8123
docker logs homeassistant
```

## Problémy se zálohováním

### Zálohy se negenerují

**Řešení:** Zkontrolujte, zda je cron job nainstalován:

```bash
./scripts/setup_cron_backup.sh status
```

Instalace:

```bash
./scripts/setup_cron_backup.sh install
crontab -l
```

Zkontrolujte logy:

```bash
tail /tmp/ha_backup.log
```

### Příliš mnoho starých záloh

**Řešení:** Nastavte nižší počet záloh:

```bash
./scripts/backup_config.sh --keep 5
```

## Běžné chyby při aktualizaci

### Chyba: "Merge conflict v docker-compose.yml"

**Řešení:**

1. Vyřešte konflikt v `docker-compose.yml`
2. Spusťte: `./scripts/sync_config.sh --validate`
3. Testujte: `docker-compose config`

### Chyba: "config/ byl přepsán, ale měl by se zálohovat"

**Řešení:** Vždy zálohujte před sync:

```bash
./scripts/backup_config.sh
./scripts/sync_config.sh --force
```

## Kde hledat pomoc

- **Logy:**
  ```bash
  tail -f /home/$(whoami)/ha_suite_install.log
  ```

- **Docker logy:**
  ```bash
  docker-compose logs -f
  ```

- **Systémové logy:**
  ```bash
  sudo journalctl -u homeassistant -f
  ```

- **Diagnostika:**
  ```bash
  ./setup_master.sh
  # Vyberte: 5 (Diagnostika)
  ```

## Kontakt a support

Pokud problém trvá, zkuste:
1. Spusťte `setup_master.sh` → 5 (Diagnostika)
2. Sberu logu a vytvorite Issue na GitHub
3. Připojte logy, docker-compose ps output, a kroky k reprodukci
