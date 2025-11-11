# RPi5 Home Assistant Suite

Kompletní sada nástrojů pro instalaci a správu Home Assistant na Raspberry Pi 5 s podporou MHS35 TFT displeje.

## 🚀 Rychlý start

```bash
# Stažení repozitáře
git clone https://github.com/Fatalerorr69/rpi5-homeassistant-suite.git
cd rpi5-homeassistant-suite

# Spuštění hlavního instalačního skriptu
./setup_master.sh

📁 Struktura projektu
Viz PROJECT_STRUCTURE.md

# RPi5 Home Assistant Suite

Kompletní sada nástrojů pro instalaci a správu Home Assistant na Raspberry Pi 5 s podporou MHS35 TFT displeje.

## � Rychlý start

```bash
# Stažení repozitáře
git clone https://github.com/Fatalerorr69/rpi5-homeassistant-suite.git
cd rpi5-homeassistant-suite

# Spuštění hlavního instalačního skriptu
./setup_master.sh
```

📁 Struktura projektu
Viz `PROJECT_STRUCTURE.md`

## �🛠️ Funkce
- Kompletní instalace Home Assistant
- Podpora MHS35 TFT displeje
- Optimalizace úložišť
- Diagnostické nástroje
- Herní servery (Minecraft, TeamSpeak)
- Konfigurační šablony

## Automatizace a pomocné skripty

- `./scripts/sync_config.sh` — synchronizuje `CONFIG/` → `config/` (použijte `--dry-run` pro náhled; `--force --validate` pro nasazení a validaci YAML).
- `./scripts/validate_yaml.sh` — validuje důležité YAML soubory nebo všechny v `config/` (`--all`).
- `./scripts/backup_config.sh` — vytvoří zálohu `config/` do `backups/`.
- `POST_INSTALL/post_install_addons.sh` — připraví runtime složky a zkopíruje ukázkové package konfigurace.

Doporučený postup po změně konfigurace:
1) `./scripts/sync_config.sh --dry-run`
2) `./scripts/sync_config.sh --force --validate`
3) `docker-compose restart homeassistant`

## 📄 Licence
MIT
