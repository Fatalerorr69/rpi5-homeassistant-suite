## RPi5 Home Assistant Suite — instrukce pro AI kodovací agenty

Konkrétní pokyny pro produktivní práci v tomto projektu. Zaměřte se na architektura, pracovní postupy a konvence.

---

### 🏗️ Architektura — „Big Picture"

Repo orchestruje **dvoustupňový Docker deployment** Home Assistant na RPi5:

**Vrstva 1: Systémová instalace** (`install.sh` → `setup_master.sh`)
- Instalace APT balíčků (Python, Docker, systemd-resolved, dbus)
- Ověření PyYAML (pro validaci YAML)
- Setup Docker + docker-compose, přidání uživatele do `docker` skupiny
- Hardware-specific: `HARDWARE/mhs35_setup.sh` pro MHS35 displej

**Vrstva 2: Docker orchestrace** (`docker-compose.yml`)
- **homeassistant** — Primární služba, síťový mód `host`, mount `./config:/config`
- **mosquitto** — MQTT broker (1883 interní, 9001 WebSocket)
- **zigbee2mqtt** — Zigbee integrační most (`/dev/ttyUSB0`)
- **nodered** — Automatizace a flow (port 1880)
- **portainer** — Docker UI (port 9000)

**Config management — centrální workflow:**
```
CONFIG/ (version control, zdroj)
  ↓ [sync_config.sh --force --validate]
config/ (runtime, Docker mount)
  ↓ [docker-compose restart homeassistant]
Home Assistant proces
```

---

### 🔄 Praktické workflow — Co dělat

#### Po klonování: Instalace
```bash
./install.sh install                           # Systémové závislosti
./setup_master.sh                              # Menu: vyberte instalaci
./POST_INSTALL/post_install_setup_menu.sh      # Post-install (volitelné)
```

#### Po úpravě konfigurace
```bash
# 1. Editujte VŽDY CONFIG/, nikdy config/
nano CONFIG/configuration.yaml
nano CONFIG/automations.yaml

# 2. Náhled změn
./scripts/sync_config.sh --dry-run

# 3. Nasazení + YAML validace (PyYAML + Home Assistant custom tagy)
./scripts/sync_config.sh --force --validate

# 4. Restart Home Assistant
docker-compose restart homeassistant
```

#### Diagnostika a opravy
```bash
# Menu diagnostiky
./setup_master.sh                      # Volba: 5 = Diagnostika

# Nebo přímo
docker-compose logs -f homeassistant
docker-compose logs mosquitto
./DIAGNOSTICS/health_dashboard.sh
./DIAGNOSTICS/quick_scan.sh
```

---

### 📋 Klíčové skripty — Co existuje a jak se používá

| Script | Účel | Příklady |
|--------|------|----------|
| `scripts/sync_config.sh` | Synchronizace CONFIG/ → config/ s PyYAML validací | `--dry-run` (náhled), `--force --validate` (nasazení) |
| `scripts/validate_yaml.sh` | Validace všech YAML souborů v config/ | `--all` (všechny) |
| `scripts/validate_ha_config.py` | **HA-aware** YAML validace (rozpoznává !include, !secret) | `validate_ha_config.py config/configuration.yaml` |
| `scripts/backup_config.sh` | Záloha config/ do backups/ s rotací | `--keep 7` (zachovat 7 záloh) |
| `scripts/setup_cron_backup.sh` | Automatické zálohování každých 12h | `install` (nainstalovat), `remove` (odinstalovat) |
| `scripts/system_check.sh` | Kontrola integrity: bash syntaxe, YAML validace, oprávnění | Generuje report |
| `POST_INSTALL/setup_file_explorer.sh` | Samba, SFTP, web file browser | Interaktivní menu |
| `POST_INSTALL/setup_maintenance.sh` | Cron cleanup, log rotation, Docker optimization | — |

---

### ✅ Konvence a pravidla (nutné pro CI/CD)

**Bash skripty:**
- Začátek: `#!/bin/bash` + `set -euo pipefail` (exit na chybu, undefined vars, pipe failure)
- Logování: `log "zpráva"` nebo `echo "[$(date)] zpráva"`
- Syntax check: `bash -n script.sh` (před committem)
- Permissions: `chmod +x script.sh` (při přidání nového skriptu)
- Bez `root`: Skripty nikdy NEspouštějte jako root; `sudo` se volá interně

**YAML konfigurace:**
- Zdroj: `CONFIG/` (git tracked) — **VŽDY tu editujte**
- Runtime: `config/` (Docker mount) — **autosynchronizováno**
- Validace: `python3 -c "import yaml; yaml.safe_load(open('soubor.yaml'))"`
- Home Assistant custom tagy: `!include`, `!secret`, `!include_dir_merge_named` — validuje `validate_ha_config.py`

**Dokumentace:**
- Nová funkcionalita → přidejte zápis do `CHANGELOG.md` (formát viz existující)
- Nový skript/feature → dokumentace v `README.md` nebo `docs/*.md`
- Změny konfigurace → popis do PR: "Přidán MQTT broker pro Zigbee, viz CONFIG/configuration.yaml"

**CI/CD pipeline:**
- `.github/workflows/validate-yaml.yml` — Validace YAML na PR/push (automaticky)
- `.github/workflows/lint.yml` — ShellCheck + Markdown lint + Bash syntax check
- `tests/test_scripts.sh` — Lokální unit testy pro sync, backup, validate

---

### 🛠️ Vývoj — Jak přidat nový script nebo konfiguraci

**Nový Bash script:**
1. Vytvořte v `scripts/` nebo `POST_INSTALL/`
2. Přidejte: `#!/bin/bash` + `set -euo pipefail` + help funkce
3. Test lokálně: `bash -n new_script.sh` a `chmod +x new_script.sh`
4. Přidejte testy do `tests/test_scripts.sh`
5. Update: `CHANGELOG.md`, `README.md`
6. Push: GitHub Actions spustí ShellCheck + Bash syntax automaticky

**Nová Home Assistant konfigurace:**
1. Editujte `CONFIG/` (např. `CONFIG/packages/my_integration.yaml`)
2. Validujte: `./scripts/validate_ha_config.py CONFIG/packages/my_integration.yaml`
3. Synchronizujte: `./scripts/sync_config.sh --force --validate`
4. Test: `docker-compose restart homeassistant` a zkontrolujte logy
5. PR: Popište co se změnilo (např. "Přidán balíček pro Zigbee2MQTT s custom automacemi")

**Checklist před PR:**
```bash
bash -n setup_master.sh install.sh scripts/*.sh POST_INSTALL/*.sh    # Syntax check
./scripts/validate_yaml.sh --all                                      # YAML validace
./tests/test_scripts.sh                                               # Unit testy (pokud k dispozici)
```

---

### ⚠️ Kritické detaily — Pasti a gotchas

1. **CONFIG/ vs config/**
   - `CONFIG/` = zdroj, version-controlled, editujte zde
   - `config/` = runtime, Docker mount, auto-synchronizováno
   - Pokud editujete `config/` přímo, změny budou ztraceny při dalším `sync_config.sh`

2. **PyYAML a Home Assistant tagy**
   - Standard `yaml.safe_load()` odmítne `!include`, `!secret`, `!include_dir_merge_named`
   - Projekt má speciální `validate_ha_config.py` který těmto tagům rozumí
   - `sync_config.sh --validate` interně používá `validate_ha_config.py`

3. **Oprávnění a skupiny**
   - `docker` skupina — přístup k `/var/run/docker.sock`
   - `dialout` skupina — přístup k `/dev/ttyUSB0` (Zigbee)
   - `sudo` pro systémové změny (Docker setup, cron jobs)

4. **Systemd vs Docker vs Supervised**
   - Projekt podporuje tři HA režimy: `homeassistant-supervised`, Docker, systemd
   - `setup_master.sh` menu umožňuje výběr
   - Skripty mají podmíněné cesty pro každý režim

5. **Mosquitto network DNS**
   - V Docker compose se Mosquitto jmenuje `mosquitto` (ne IP)
   - Home Assistant se připojuje: `mqtt: broker: mosquitto` (Docker interní DNS)

---

### 📚 Klíčové soubory pro referenci

- **`docs/CONFIGURATION_MANAGEMENT.md`** — Detailní guide: CONFIG/ vs config/, workflow, troubleshooting
- **`docs/DEVELOPER_GUIDE.md`** — Přidání skriptů, modifikace konfigurace, testy
- **`docs/TROUBLESHOOTING.md`** — Řešení chyb, diagnostika
- **`CHANGELOG.md`** — Historie verzí (přidejte nové záznamy)
- **`PROJECT_STRUCTURE.md`** — Přehled všech adresářů
- **`README.md`** — Veřejné API: instrukce pro uživatele

---

### 🚀 Příkazy pro rychlou referenci

```bash
# Instalace
./install.sh install && ./setup_master.sh

# Config workflow
./scripts/sync_config.sh --dry-run                # Náhled
./scripts/sync_config.sh --force --validate       # Nasazení
docker-compose restart homeassistant

# Validace
./scripts/validate_yaml.sh --all
./scripts/validate_ha_config.py config/configuration.yaml

# Zálohování
./scripts/backup_config.sh --keep 7
./scripts/setup_cron_backup.sh install

# Diagnostika
./setup_master.sh                                  # Menu: 5
docker-compose logs -f
./DIAGNOSTICS/health_dashboard.sh

# CI/CD checks
bash -n scripts/*.sh POST_INSTALL/*.sh             # Syntax
./tests/test_scripts.sh                            # Unit testy
```

---

**TL;DR:** Editujte `CONFIG/`, spusťte `sync + validate`, commitujte s popisem. GitHub Actions si ověří YAML/Bash. Všechny nové skripty: `set -euo pipefail`, help funkce, syntax check. Viz `docs/` pro detaily.
