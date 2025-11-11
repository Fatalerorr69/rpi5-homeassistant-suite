# Projektová struktura - RPi5 Home Assistant Suite

## 🏗️ Architektura

Projekt je strukturován do více vrstev pro automatizaci, nasazení a správu Home Assistant na Raspberry Pi 5.

### Dvoustupňový Model

```
1. SYSTÉMOVÁ VRSTVA    → install.sh / setup_master.sh (apt, Docker, OS-agent)
2. DOCKER VRSTVA       → docker-compose.yml (Home Assistant, Mosquitto, Zigbee2MQTT, Node-RED, Portainer)
3. AUTOMATIZACE        → scripts/ (sync, validate, backup, storage, mount)
4. POST-INSTALL        → POST_INSTALL/ (file explorer, maintenance, monitoring)
5. CI/CD VRSTVA        → .github/workflows/ (YAML validace, linting, nasazení)
6. INFRASTRUCTURE      → ansible/ (plná automatizovaná instalace)
```

## 📁 Struktura Adresářů

```
rpi5-homeassistant-suite/
│
├── 📝 SETUP & MAIN SCRIPTS
│   ├── install.sh                      # Systémové závislosti, Docker, PyYAML
│   ├── setup_master.sh                 # Hlavní menu (instalace, diagnostika, repair)
│   ├── docker-compose.yml              # Orchestrace služeb (HA, MQTT, Zigbee, Node-RED, Portainer)
│   ├── docker-compose-homeassistant.yml # HA specifická konfigurace
│   ├── PROJECT_STRUCTURE.md            # Původní struktura (legacy)
│   ├── PROJECT_STRUCTURE_v2.md         # Nová struktura (toto)
│   ├── README.md                       # Hlavní dokumentace
│   └── CHANGELOG.md                    # Historie verzí
│
├── 🔐 .github/
│   ├── copilot-instructions.md         # Instrukce pro AI kodovací agenty
│   ├── PULL_REQUEST_TEMPLATE.md        # Šablona pro PR s guidance
│   └── workflows/
│       ├── validate-yaml.yml           # CI: YAML kontrola na PR/push
│       ├── lint.yml                    # CI: ShellCheck + Markdown lint
│       ├── deploy.yml                  # CD: SSH nasazení na RPi5 (requires RPI_SSH_KEY secret)
│       └── python-publish.yml          # Legacy Python publish
│
├── 🔄 CONFIG/ (ZDROJ)
│   ├── configuration.yaml              # Hlavní HA konfigurace
│   ├── automations.yaml                # Automatizace
│   ├── scripts.yaml                    # YAML skripty
│   ├── templates.yaml                  # Template definice
│   ├── ui-lovelace.yaml                # Lovelace UI konfigurace
│   ├── secrets.yaml                    # Tajemství (git ignored)
│   ├── docker-compose-homeassistant.yml # HA docker specifika
│   └── [další YAML konfigurace]
│
├── 📂 config/ (RUNTIME - AUTO-SYNCED)
│   ├── [synchronizováno z CONFIG/ skrz sync_config.sh]
│   ├── [Docker mountuje tuto složku jako HA /config]
│   └── [NIKDY NEUPRAVUJ RUČNĚ - vždy skrz CONFIG/]
│
├── 🔧 scripts/
│   ├── sync_config.sh                  # Sync CONFIG/ → config/ + YAML validace
│   │                                   # Flags: --dry-run, --force, --validate
│   ├── validate_yaml.sh                # YAML validace (Config/ nebo all s --all)
│   ├── backup_config.sh                # Záloha config/ → backups/ s rotací
│   ├── setup_cron_backup.sh            # Instalace cron jobu pro auto-backup (12h)
│   ├── storage_analyzer.sh             # Analýza disk utilizace, zjištění velkých souborů
│   ├── mount_storage.sh                # USB/NAS připojení (list, mount, auto-mount)
│   └── autocommit.sh                   # Auto-sync → validate → commit → push workflow
│
├── 🚀 POST_INSTALL/
│   ├── post_install_setup_menu.sh      # HLAVNÍ MENU - Všechny post-install kroky (DOPORUČENO)
│   ├── post_install_addons.sh          # Příprava HA addons runtime
│   ├── setup_file_explorer.sh          # File browser: Samba, SFTP, HTTP web manager
│   ├── setup_maintenance.sh            # Log rotation, disk cleanup, Docker optimization
│   ├── setup_monitoring.sh             # Health checks, alerting, status dashboard
│   ├── setup_nas.sh                    # NAS setup (legacy)
│   ├── setup_storage.sh                # Storage helpers (legacy)
│   ├── setup_vmspace.sh                # VM space setup (legacy)
│   ├── setup_gaming_services.sh        # Minecraft, TeamSpeak servery
│   └── install_addons.sh               # Instalace HA addons
│
├── 🧪 tests/
│   └── test_scripts.sh                 # Unit testy pro sync, validate, backup, storage scripts
│
├── 📚 docs/
│   ├── DEVELOPER_GUIDE.md              # Průvodce pro vývojáře (Contributing)
│   ├── TROUBLESHOOTING.md              # Řešení běžných problémů
│   ├── STORAGE_GUIDE.md                # Komplexní správa disk, backup, NAS
│   ├── DEPLOYMENT_GUIDE.md             # GitHub Actions + Ansible setup guide
│   └── [další dokumentace]
│
├── 🤖 ansible/
│   ├── playbook.yml                    # Plné infrastruktury-jako-kód nasazení
│   │                                   # Coverage: Packages, Docker, repo, configs, services, backups
│   ├── inventory.ini                   # Host konfigurace (template - přizpůsobit IP/hostname)
│   └── README.md                       # Ansible setup a usage guide
│
├── 🖥️ HARDWARE/
│   ├── one_step_fullsuite_starkos_mhs35_interactive.sh
│   ├── one_step_fullsuite_starkos_mhs35_interactive_auto.sh
│   └── [hardware-specifické skripty]
│
├── 📦 INSTALLATION/
│   ├── auto_install.sh
│   ├── create_ha_full_suite.sh
│   ├── install_ha_complete.sh
│   ├── install_ha_docker_complete.sh
│   ├── one_step_ha_full_suite.sh
│   ├── quick_fix_docker_compose.sh
│   └── [instalační skripty]
│
├── 🔍 DIAGNOSTICS/
│   ├── health_dashboard.sh             # Systém health check dashboard
│   ├── quick_scan.sh                   # Rychlá diagnostika
│   ├── quick_entities.sh               # Kontrola HA entit
│   ├── device_structure_scan.py        # Struktura zařízení scan (Python)
│   ├── repair_homeassistant.py         # HA repair nástroj (Python)
│   ├── storage_analyzer.py             # Storage análisis (Python)
│   ├── storage_optimizer.py            # Storage optimizer (Python)
│   └── [diagnostické nástroje]
│
├── 💾 STORAGE/
│   └── auto_mount_setup.sh             # Automatické připojování úložiště
│
├── 📋 TEMPLATES/
│   ├── docker-compose.yml.tmpl         # Docker Compose šablona
│   ├── ha_supervised.conf              # HA Supervised konfigurace
│   ├── smb_nas_example.conf            # SMB/NAS šablona
│   ├── vm_example.qemu                 # QEMU VM šablona
│   └── package_examples/
│       ├── energy_monitoring.yaml      # Energy monitoring balíček
│       ├── gaming_pc.yaml              # Gaming PC balíček
│       ├── nas_storage.yaml            # NAS storage balíček
│       └── security_cameras.yaml       # Security cameras balíček
│
└── 🗂️ backups/
    ├── config-backup-*.tar.gz          # Automatické zálohy (rotace)
    └── [Vytvořeno skrz backup_config.sh]
```

## 🔄 Workflow: Instalace a Nasazení

### 1. Počáteční Instalace

```bash
# Klonování repo
git clone https://github.com/Fatalerorr69/rpi5-homeassistant-suite.git
cd rpi5-homeassistant-suite

# Instalace systémových závislostí
./install.sh install

# Hlavní instalace (menu)
./setup_master.sh
# Vyberte: 1 = Instalace Home Assistant (Docker)
```

### 2. Po Instalaci Setup

```bash
# Všechny post-install kroky (DOPORUČENO)
./POST_INSTALL/post_install_setup_menu.sh
# Vyberte: 7 (Všechny)
```

### 3. Config Management

```bash
# Náhled změn
./scripts/sync_config.sh --dry-run

# Nasazení s validací
./scripts/sync_config.sh --force --validate

# Restart služby
docker-compose restart homeassistant
```

### 4. Automatizované Zálohování

```bash
# Instalace cron jobu (automatické zálohování každých 12h)
./scripts/setup_cron_backup.sh install

# Ruční záloha
./scripts/backup_config.sh

# Obnovení z zálohy
tar -xzf backups/config-backup-*.tar.gz -C config/
```

### 5. GitHub Actions Nasazení

```
.github/workflows/deploy.yml
├── Validuje YAML (validate_yaml.yml)
├── SSH do RPi
├── Git pull
├── Sync CONFIG → config/
├── Docker-compose restart
└── Health check
```

**Nastavení:**
1. Generuj SSH klíč: `ssh-keygen -t ed25519 -f ha_deploy_key`
2. Přidej privátní klíč jako GitHub secret `RPI_SSH_KEY`
3. Přidej veřejný klíč do `~/.ssh/authorized_keys` na RPi

### 6. Ansible Nasazení

```bash
# Přizpůsobit inventory
nano ansible/inventory.ini

# Spuštění playbooku
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml -u pi

# Dry-run (bez změn)
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml -u pi --check
```

## 🧪 Testing & Validation

```bash
# Unit testy
./tests/test_scripts.sh

# Syntaxová kontrola
bash -n setup_master.sh install.sh scripts/*.sh POST_INSTALL/*.sh

# YAML validace
./scripts/validate_yaml.sh --all

# GitHub Actions lokálně (act - optional)
# act -j validate  # Spustit validate-yaml.yml workflow
```

## 🔑 Klíčové Soubory a Jejich Role

| Soubor | Účel |
|--------|------|
| `install.sh` | Systémové závislosti (apt, Docker, PyYAML) |
| `setup_master.sh` | Menu pro instalaci, diagnostiku, repair |
| `docker-compose.yml` | Orchestrace služeb |
| `CONFIG/` | Zdrojové konfigurace (edituj zde) |
| `config/` | Runtime konfigurace (auto-synced) |
| `scripts/sync_config.sh` | Synchronizace s validací |
| `POST_INSTALL/post_install_setup_menu.sh` | Post-install setup menu |
| `.github/workflows/deploy.yml` | CI/CD nasazení |
| `ansible/playbook.yml` | Infrastructure-as-Code instalace |
| `docs/DEPLOYMENT_GUIDE.md` | GitHub Actions + Ansible guide |
| `docs/STORAGE_GUIDE.md` | Storage management guide |

## 🎯 Best Practices

1. **CONFIG Management**
   - VŽDY edituj `CONFIG/` ne `config/`
   - Spusť `./scripts/sync_config.sh --dry-run` před nasazením
   - Spusť s `--force --validate` pro nasazení

2. **Zálohování**
   - Povoluj automatické zálohování: `./scripts/setup_cron_backup.sh install`
   - Ověřuj zálohy pravidelně: `ls -lh backups/`
   - Testuj obnovení z záloh v dev prostředí

3. **Testování**
   - Vždy spusť: `bash -n script.sh` před commitnutím
   - Spusť `./tests/test_scripts.sh` pro unit testy
   - Ověřuj s `--dry-run` před `--force`

4. **Documentation**
   - Aktualizuj `CHANGELOG.md` pro nové funkce
   - Přidej do `README.md` nebo `docs/`
   - Aktualizuj `PROJECT_STRUCTURE_v2.md` pro nové adresáře

## 🚀 Rychlý Start (Shrnutí)

```bash
# 1. Klonuj a instaluj
git clone https://github.com/Fatalerorr69/rpi5-homeassistant-suite.git
cd rpi5-homeassistant-suite
./install.sh install && ./setup_master.sh

# 2. Post-install
./POST_INSTALL/post_install_setup_menu.sh

# 3. Autocommit workflow (developer)
echo "Changed something in CONFIG/" && ./scripts/autocommit.sh "Updated config"

# 4. Health check
./DIAGNOSTICS/health_dashboard.sh
```

## 📞 Support & Docs

- **Instalace**: `README.md`
- **Vývojáři**: `docs/DEVELOPER_GUIDE.md`
- **Problémy**: `docs/TROUBLESHOOTING.md`
- **Storage**: `docs/STORAGE_GUIDE.md`
- **Nasazení**: `docs/DEPLOYMENT_GUIDE.md`
- **Ansible**: `ansible/README.md`
- **Změny**: `CHANGELOG.md`
