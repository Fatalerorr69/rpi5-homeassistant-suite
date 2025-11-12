# RPi5 Home Assistant Suite

Kompletní sada nástrojů pro instalaci a správu Home Assistant na Raspberry Pi 5 s podporou MHS35 TFT displeje.

## 🚀 Rychlý start

```bash
# Stažení repozitáře
git clone https://github.com/Fatalerorr69/rpi5-homeassistant-suite.git
cd rpi5-homeassistant-suite

# Instalace závislostí
./install.sh install

# Hlavní instalace
./setup_master.sh

# Post-install setup
./POST_INSTALL/post_install_setup_menu.sh
```

## 📁 Struktura projektu

Viz `PROJECT_STRUCTURE.md`

## 🛠️ Funkce

- Kompletní instalace Home Assistant
- Podpora MHS35 TFT displeje
- Optimalizace úložišť
- Diagnostické nástroje
- Herní servery (Minecraft, TeamSpeak)
- Konfigurační šablony

## 🤖 Automatizace a pomocné skripty

### Konfigurace a validace

- `./scripts/sync_config.sh` — synchronizuje `CONFIG/` → `config/` (použijte `--dry-run` pro náhled; `--force --validate` pro nasazení a validaci YAML).
- `./scripts/validate_yaml.sh` — validuje důležité YAML soubory nebo všechny v `config/` (`--all`).
- `./scripts/system_check.sh` — kontrola integrity systémových souborů, detekce verzí, generování reportu.

### Zálohování a úložiště

- `./scripts/backup_config.sh` — vytvoří zálohu `config/` do `backups/` s rotací.
- `./scripts/setup_cron_backup.sh` — nastaví automatické zálohování každých 12 hodin.
- `./scripts/storage_analyzer.sh` — analýza disk utilizace, zjištění velkých souborů.
- `./scripts/mount_storage.sh` — připojení externího úložiště (USB, NAS).

### Post-install setup

- `./POST_INSTALL/post_install_setup_menu.sh` — hlavní menu pro post-install (DOPORUČENO).
- `./POST_INSTALL/setup_file_explorer.sh` — nastavení Samby, SFTP, web file browseru.
- `./POST_INSTALL/setup_maintenance.sh` — automatické čištění, log rotation, Docker optimization.
- `./POST_INSTALL/setup_monitoring.sh` — health checks, alerting, status dashboard.

### Doporučený postup po změně konfigurace

```bash
# Náhled změn
./scripts/sync_config.sh --dry-run

# Nasazení s validací
./scripts/sync_config.sh --force --validate

# Restart služby
docker-compose restart homeassistant
```

### Post-install po nové instalaci

```bash
# Všechny kroky (DOPORUČENO)
./POST_INSTALL/post_install_setup_menu.sh
# Vyberte: 7 (Všechny kroky)

# Nebo jednotlivě
./scripts/storage_analyzer.sh                    # Zjištění disk stavu
./POST_INSTALL/setup_file_explorer.sh            # Nastavit file manager
./POST_INSTALL/setup_maintenance.sh              # Údržbové úkoly
./scripts/setup_cron_backup.sh install           # Automatické zálohování
./POST_INSTALL/setup_monitoring.sh               # Health checks
```

## 📚 Dokumentace

- `docs/CONFIGURATION_MANAGEMENT.md` — **Správa konfigurace** (CONFIG/ vs config/, YAML validace, synchronizace)
- `docs/DEVELOPER_GUIDE.md` — Průvodce pro vývojáře
- `docs/TROUBLESHOOTING.md` — Řešení běžných problémů
- `docs/STORAGE_GUIDE.md` — Správa disk, zálohování, externí úložiště
- `CHANGELOG.md` — Historie verzí a změn

### Užitečné Python snippety

**Stažení HACS (Home Assistant Community Store) releaseu:**

```python
import requests
import io
import zipfile

# Stažení nejnovějšího HACS z GitHub Releases
hacs_url = "https://github.com/hacs/integration/releases/latest/download/hacs.zip"
response = requests.get(hacs_url, timeout=30)
response.raise_for_status()

# Práce s obsahem (v paměti bez ukládání)
zip_bytes = io.BytesIO(response.content)
with zipfile.ZipFile(zip_bytes) as z:
    z.extractall(path="/tmp/hacs_extracted")  # Rozbalení
```

**Závislosti:** `requests` (`pip install requests`)  
**Poznámka:** Pokud rozbalujete do `config/`, synchronizujte přes `./scripts/sync_config.sh` z `CONFIG/` — viz `docs/CONFIGURATION_MANAGEMENT.md`.

## 🚀 Automatizované nasazení

### GitHub Actions (CI/CD)

Automatické validaci YAML, lintelování a nasazení na RPi5 prostřednictvím GitHub Actions.

**Nastavení:**

1. Vygenerujte SSH klíč: `ssh-keygen -t ed25519 -f ha_deploy_key -C "github-actions"`
2. Přidejte privátní klíč jako GitHub secret `RPI_SSH_KEY` v Settings → Secrets
3. Přidejte veřejný klíč do `~/.ssh/authorized_keys` na RPi

**Workflow:**

- **validate-yaml.yml** — Automatická YAML validace na každý PR/push
- **lint.yml** — ShellCheck a Markdown lint
- **deploy.yml** — SSH nasazení na RPi5 (push na `main` nebo ruční trigger)

Viz `docs/DEPLOYMENT_GUIDE.md` pro detaily.

### Ansible (Infrastructure as Code)

Plná automatizovaná instalace RPi5 přes Ansible playbook.

**Nastavení:**

```bash
# Upraveníte inventory se IP adresou RPi
nano ansible/inventory.ini

# Spuštění playbooku
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml -u pi

# Dry-run (bez změn)
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml -u pi --check
```

Playbook provádí: aktualizace balíků, instalace Dockeru, klonování repo, konfigurace, spuštění služeb, post-install setup.

Viz `ansible/README.md` pro podrobný průvodce.

### Autocommit (Developer Workflow)

Automatizuje synchronizaci, validaci a commit konfiguračních změn.

```bash
./scripts/autocommit.sh "Popis změny"
# → Syncs CONFIG/ → config/
# → Validuje YAML
# → Commituje s časovým razítkem
# → Pushuje na GitHub
# → Deploy.yml se automaticky spustí (pokud je nastaveno)
```

## 🧪 Testování

```bash
# Unit testy
./tests/test_scripts.sh

# Syntaxová kontrola
bash -n setup_master.sh install.sh scripts/*.sh POST_INSTALL/*.sh

# YAML validace
./scripts/validate_yaml.sh --all
```

## 🔧 Konfigurace

Všechny konfigurace jsou ve složce `CONFIG/`:

```bash
CONFIG/
├── configuration.yaml     # Hlavní HA config
├── automations.yaml       # Automatizace
├── scripts.yaml           # Skripty
├── templates.yaml         # Templaty
└── ui-lovelace.yaml       # UI konfigurace
```

Upravte zdrojové soubory a spusťte synchronizaci:

```bash
./scripts/sync_config.sh --force --validate
```

## 🐳 Docker služby

```bash
# Spustit
docker-compose up -d

# Kontrola
docker-compose ps

# Logy
docker-compose logs -f

# Restart
docker-compose restart homeassistant
```

Služby: Home Assistant, Mosquitto (MQTT), Zigbee2MQTT, Node-RED, Portainer

## 💾 Úložiště

Analýza disk:

```bash
./scripts/storage_analyzer.sh
```

Přesun na externí disk:

```bash
./scripts/mount_storage.sh list        # Vypsat dostupná zařízení
./scripts/mount_storage.sh mount       # Interaktivní připojení
./scripts/mount_storage.sh auto-mount  # Trvalé připojení
```

Viz `docs/STORAGE_GUIDE.md` pro úplný průvodce.

## 🔒 Zálohování

Automatické zálohování (každých 12 hodin):

```bash
./scripts/setup_cron_backup.sh install
```

Ruční záloha:

```bash
./scripts/backup_config.sh
./scripts/backup_config.sh --keep 14  # Ponechat 14 záloh
```

Obnovení:

```bash
tar -xzf backups/config-backup-*.tar.gz -C config/
```

## 📄 Licence

MIT

