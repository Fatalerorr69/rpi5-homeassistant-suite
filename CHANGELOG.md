# Changelog

Všechny příznačné změny v tomto projektu jsou zdokumentovány v tomto souboru.

## [2.4.3] - 2025-11-12

### Nové Funkce v 2.4.3 (setup_master.sh v2.3)

- **Detekce Home Assistant instalace**
  - Automatická detekce typu: systemd, Docker, Supervised
  - Zjišťování aktuální verze a konfigurace
  - Status reporting

- **Detekce OS varianty**
  - Rozpoznání: Ubuntu, Debian, Armbian
  - Kompatibilita s RPi5 a dalšími SBC
  - Version reporting

- **Správa Disků a Úložiště**
  - `list_available_disks()` — Výpis dostupných jednotek
  - `format_disk()` — Formátování s volbou filesystému (ext4/btrfs/xfs)
  - `mount_disk()` — Připojení s trvalým zápase do `/etc/fstab`
  - `expand_partition()` — Rozšíření partition pro RPi5
  - `backup_before_format()` — Automatický backup Docker volumes

- **Migrace Home Assistant**
  - `migrate_ha_installation()` — Migrování mezi instalacemi
  - Podpora: systemd ↔ Docker ↔ Supervised
  - Bezpečný přesun s backupem
  - Zachování konfigurace

- **Interaktivní Menu pro OS (8 voleb)**
  - Detekce instalace
  - Detekce OS
  - Výpis disků
  - Formátování
  - Připojení disku
  - Rozšíření partition
  - Migrace instalace
  - Zpět na hlavní menu

- **Aktualizované Hlavní Menu (14 voleb)**
  - Přidán oddíl "💾 OS A ÚLOŽIŠTĚ"
  - Volba 9: Správa OS a migrace
  - Volba 10: Backup konfigurace

### Bezpečnostní Prvky v 2.4.3

- Potvrzení před formátováním ("ano" ke schválení)
- Kontrola, zda je disk připojen
- Bezpečnost: Backup před jakoukoliv změnou
- Validace zařízení (`test -b /dev/sdX`)
- UUID-based mount pro spolehlivost

### Technické Detaily v 2.4.3

- 1327 řádků setup_master.sh (zvýšení z 986)
- Nové funkce: 7× detekce/správy
- Submenu: `os_management_menu()` s 8 volbami
- Integrace s `lsblk`, `blkid`, `mount`, `fstab`
- Docker volume backup přes `docker run` + tar
- Systemd integration pro automatické mount

### Kompatibilita v 2.4.3

- ✅ Ubuntu 22.04+ (Jammy, Noble)
- ✅ Debian 12+ (Bookworm)
- ✅ Armbian (všechny verze na RPi5)
- ✅ Raspberry Pi 5 (primary target)
- ✅ Raspberry Pi 4, 3 (tested)
- ✅ x86_64 (VM/počítač)

---

## [2.4.2] - 2025-11-12

### Setup_master.sh v2.2 v 2.4.2

- **setup_master.sh v2.2** — Komplexní vylepšení robustnosti a automatických oprav
  - ✨ Přidán `set -euo pipefail` + graceful error handling
  - 🎨 Barvené logování (6 úrovní: info, success, warn, error, debug) s ANSI kódy
  - 📋 Strukturované logování do `~/.ha_suite_install/` s rotací starých logů (max 10)
  - 🔧 **Auto-opravy funkcí `auto_fix_issues()`:**
    - Oprávnění skriptů (`chmod +x *.sh`)
    - Přidání uživatele do Docker group
    - Přidání uživatele do dialout group (Zigbee USB)
    - Vytváření `config/` adresáře při chybě
    - Vytváření `~/.ssh` s správnými právy
  - 🔄 Retry logika pro Docker a síťové operace (3 pokusy, 5s delay)
  - 🏥 **Health check funkcí `health_check()`:**
    - Ověření Home Assistant (8123)
    - Ověření Mosquitto MQTT (1883)
    - Ověření Node-RED (1880)
    - Status reporting
  - 🪤 Trap a cleanup funkce pro korektní ukončení
  - 📊 **Nové menu s 12 volbami** (rozšířeno z 11)
  - 🔍 **Interaktivní diagnostika s 8 volbami**
  - 📖 Obsáhlá help (`./setup_master.sh --help`)
  - 🎯 Od 189 → 986 řádků kvalitního kódu s komentáři

---

## [2.4.1] - 2025-11-12

### Nové Komponenty v 2.4.1

- **README.md** — Přidána sekce "Užitečné Python snippety"
  - Příklad: Stažení HACS z GitHub Releases s využitím `requests` + `zipfile`
- **scripts/validate_yaml.sh** — Vylepšená YAML validace
- **.github/copilot-instructions.md** — Komplexní aktualizace AI instrukcí

### Install.sh v2.1 v 2.4.1

- **install.sh v2.1** — Komplexní vylepšení robustnosti a univerzality
  - ✨ Přidán `set -euo pipefail` pro korektní error handling
  - 🔍 Detekce OS (Ubuntu, Debian, Armbian) přes `/etc/os-release`
  - 🎨 Barvené výstupy + strukturované logování
  - 🔄 Retry logika pro selhavší instalace (3 pokusy, 5s delay)
  - 🏗️ Detekce CPU architektury (aarch64, armv7l, x86_64)
  - ⏱️ Timeout pro wget/curl (30s)
  - 🚀 Volby: `--skip-docker`, `--skip-compose`, `--skip-agent`, `--dry-run`, `--retry N`
  - 📋 Logování do `~/.homeassistant_install/install_TIMESTAMP.log`
  - 💾 Od 175 do 525 řádků kvalitního kódu s komentáři

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

---

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

---

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

---

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

---

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
