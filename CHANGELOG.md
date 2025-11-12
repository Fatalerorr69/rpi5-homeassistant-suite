# Changelog

Všechny příznačné změny v tomto projektu jsou zdokumentovány v tomto souboru.

## [2.4.1] - 2025-11-12

### Nové Funkce v 2.4.1

- **README.md** — Přidána sekce "Užitečné Python snippety"
  - Příklad: Stažení HACS z GitHub Releases s využitím `requests` + `zipfile`
  - Dokumentace zavislostí a best practices
- **scripts/validate_yaml.sh** — Vylepšená YAML validace
  - Oddělení standard YAML (docker-compose.yml) od Home Assistant config files
  - Přímá integrace s `validate_ha_config.py` pro custom tagy (!include, !secret)
  - Jasná diagnostika chyb
- **.github/copilot-instructions.md** — Komplexní aktualizace AI instrukcí
  - Strukturovaná architektura (Big Picture)
  - Praktické workflow pro vývojáře
  - Tabulka klíčových skriptů s příklady
  - Konvence pro bash, YAML, dokumentaci
  - Kritické detaily a pasti (CONFIG/ vs config/, PyYAML tagy, oprávnění)

### Refaktoring v 2.4.1

- **install.sh v2.1** — Komplexní vylepšení robustnosti a univerzality
  - ✨ Přidán `set -euo pipefail` pro korektní error handling (s graceful fallbackem pro dev kontejnery)
  - 🔍 Detekce OS (Ubuntu, Debian, Armbian) přes `/etc/os-release`
  - 🎨 Barvené výstupy (RED/GREEN/YELLOW/BLUE) + strukturované logování
  - 🔄 Retry logika pro selhavší instalace (default: 3 pokusy, 5s delay)
  - 🏗️ Detekce CPU architektury (aarch64, armv7l, x86_64) pro os-agent
  - ⏱️ Timeout pro wget/curl (30s) proti vyřazení procesů
  - 🚀 Volby: `--skip-docker`, `--skip-compose`, `--skip-agent`, `--dry-run`, `--retry N`
  - 📋 Logování do `~/.homeassistant_install/install_TIMESTAMP.log`
  - 🛡️ Kontrola sudo s fallbackem pro dev kontejnery (bez sudo)
  - 🎯 Lepší error zprávy a diagnostika
  - 📖 Obsáhlá help (`./install.sh help`)
  - 🔗 Integrace s detect_os(), command_exists(), run_with_retry()
  - 💾 Od 175 do 525 řádků kvalitního kódu s komentáři

### Technické Detaily

- `install.sh` nyní importuje `sudo` jen když je dostupný a potřebný
- Jednotlivé balíčky se instalují s možností preskočit na chybu
- os-agent detekuje správnou verzi pro ARM/ARM64/x86_64 automaticky
- Log obsahuje metadata: timestamp, user, arch, script version
- Dry-run mód (`--dry-run`) simuluje bez skutečných změn

---

## [2.4.0-final] - 2025-11-12

### Nové Funkce v 2.4.0-final

- Home Assistant YAML Validátor — `scripts/validate_ha_config.py` pro správnou validaci YAML s podporou custom tagů
  - Rozpoznává !include, !secret, !include_dir_merge_named, !include_dir_merge_list, atd.
  - Ověřuje konfiguraci v Home Assistant kontextu
  - Integrován do merge_configs.sh
- Configuration Management Guide — `docs/CONFIGURATION_MANAGEMENT.md` s kompletní dokumentací
  - Vysvětlení CONFIG/ vs config/ adresářů
  - YAML workflow a best practices
  - Troubleshooting YAML chyb
  - Příklady balíčků a automatizací

### Opravy v 2.4.0-final

- **install.sh** — opravena instalace balíčků s graceful error handling
  - Zběh z hardcodeovaného apt-get s dlouhým seznamem
  - Jednotlivá instalace každého balíčku s možností preskočit chybějící
  - Odstraněn `libtiff5` (neexistuje v Debian Bookworm pro RPi5)
  - Přidány alternativy: `libopenjp2-7-dev`, `libturbojpeg0-dev`
- **configuration.yaml** — správná struktura YAML
  - Přesunuta `homeassistant:` na začátek souboru
  - Opraveny duplikátní pole
  - MQTT broker nyní používá 'mosquitto' (Docker network DNS)
  - Všechny custom tagy se nyní validují správně
- **merge_configs.sh** — aktualizován pro nový validátor
  - Používá `validate_ha_config.py` místo generic yaml.safe_load()
  - Správně rozpoznává Home Assistant YAML syntax

### Vylepšení v 2.4.0-final

- README.md — přidán odkaz na nový Configuration Management Guide
- Dokumentace — kompletní popis workflow konfigurace a synchronizace

## [2.3.0] - 2025-11-12

### Nové Funkce v 2.3.0

- System Check Skript — `scripts/system_check.sh` pro kontrolu integrity systémových souborů
  - Validace Bash skriptů (syntaxe)
  - Validace YAML souborů
  - Validace Markdown dokumentace
  - Kontrola struktury adresářů
  - Kontrola kritických souborů
  - Kontrola oprávnění skriptů
  - Analýza velikostí souborů
  - Generování reportu
- Výběr Verzí Instalace — Menu pro výběr z 9 variant instalace (HA Supervised, Docker, Hardware, atd.)
- System Check Guide — `docs/SYSTEM_CHECK_GUIDE.md` s detailní dokumentací
- Integrace do setup_master.sh — Menu volby 9-10 pro kontrolu souborů a výběr verze

### Vylepšení v 2.3.0

- setup_master.sh — rozšířeno menu z 9 na 11 voleb
- README.md — přidán `scripts/system_check.sh` do dokumentace
- Automatická oprava oprávnění skriptů při detekci chyby

## [2.2.0] - 2025-11-12

### Nové Funkce v 2.2.0

- GitHub Actions nasazení — `.github/workflows/deploy.yml` pro automatické nasazení na RPi5 přes SSH
- Ansible playbook — `ansible/playbook.yml` pro plnou infrastrukturu-jako-kód instalaci
- Ansible inventory — `ansible/inventory.ini` šablona s dokumentací
- Autocommit skript — `scripts/autocommit.sh` pro automatizaci sync → validate → commit → push
- Deployment guide — `docs/DEPLOYMENT_GUIDE.md` pro GitHub Actions a Ansible setup
- Ansible průvodce — `ansible/README.md` pro detailní Ansible instruktáž

### Vylepšení v 2.2.0

- README.md — nový oddíl "Automatizované nasazení" s GitHub Actions, Ansible a autocommit workflow
- Post-install menu — kompletní integraci s file explorer, maintenance, monitoring a storage setupem

## [2.1.0] - 2025-11-11

### Nové Funkce v 2.1.0

- Post-install menu — `POST_INSTALL/post_install_setup_menu.sh` s všemi post-instalačními kroky
- File explorer — `POST_INSTALL/setup_file_explorer.sh` (Samba, SFTP, HTTP)
- Maintenance — `POST_INSTALL/setup_maintenance.sh` (log rotation, cleanup, Docker optimization)
- Monitoring — `POST_INSTALL/setup_monitoring.sh` (health checks, alerting, dashboard)
- Storage analyzer — `scripts/storage_analyzer.sh` pro analýzu disk utilizace
- Mount script — `scripts/mount_storage.sh` pro USB/NAS připojení
- Storage guide — `docs/STORAGE_GUIDE.md` pro komplexní správu úložiště
- Konfigurace synchronizace — `scripts/sync_config.sh` s možnostmi `--dry-run`, `--force`, `--validate`
- YAML validace v CI — `.github/workflows/validate-yaml.yml` spouští kontrolu na PR a push
- Zálohování configu — `scripts/backup_config.sh` s rotací záloh (výchozí 7 záloh)
- Unit testy — `tests/test_scripts.sh` pro všechny automatizační skripty
- Cron helper — `scripts/setup_cron_backup.sh` pro automatizované zálohování každých 12 hodin
- PR šablona — `.github/PULL_REQUEST_TEMPLATE.md` vede autory k validaci a dokumentaci
- Vývojář průvodce — `docs/DEVELOPER_GUIDE.md` pro přispěvatele
- Troubleshooting — `docs/TROUBLESHOOTING.md` pro běžné problémy
- AI instrukce — `.github/copilot-instructions.md` pro kodovací agenty

### Vylepšení v 2.1.0

- setup_master.sh — přidány funkce `ensure_pyyaml()` a `sync_configs()` s automatickou instalací PyYAML
- install.sh — automatická instalace PyYAML během dependency setup
- README.md — rozšířené sekce pro post-install, storage, backup a testování

### Opravy v 2.1.0

- Zajištěna dostupnost PyYAML pro YAML validaci
- Opraveny Markdown linting problémy v dokumentaci

## [2.0.0] - 2025-11-10

### Nové Funkce v 2.0.0

- Kompletní instalační sada pro Home Assistant na RPi5
- Podpora MHS35 TFT displeje
- Docker Compose konfigurace pro Home Assistant, Mosquitto, Zigbee2MQTT, Node-RED, Portainer
- Diagnostické skripty a health dashboard

### Vlastnosti

- Home Assistant Supervised instalace
- MQTT broker (Mosquitto)
- Zigbee integraci
- Optimalizace úložiště
- Gaming servery support (Minecraft, TeamSpeak)
