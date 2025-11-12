# RPi5 Home Assistant Suite — Instrukce pro AI Kodovací Agenty# RPi5 Home Assistant Suite — Instrukce pro AI Kodovací Agenty



Konkrétní pokyny pro produktivní práci v tomto projektu. Zaměřte se na architektura, pracovní postupy a konvence.Konkrétní pokyny pro produktivní práci v tomto projektu. Zaměřte se na architektura, pracovní postupy a konvence.



------



## 🏗️ Architektura — „Big Picture"### 🏗️ Architektura — „Big Picture"



Repo orchestruje **dvoustupňový Docker deployment** Home Assistant na RPi5:Repo orchestruje **dvoustupňový Docker deployment** Home Assistant na RPi5:



**Vrstva 1: Systémová instalace** (`install.sh` → `setup_master.sh`)**Vrstva 1: Systémová instalace** (`install.sh` → `setup_master.sh`)

- Instalace APT balíčků (Python, Docker, systemd-resolved, dbus)- Instalace APT balíčků (Python, Docker, systemd-resolved, dbus)

- Ověření PyYAML (pro validaci YAML)- Ověření PyYAML (pro validaci YAML)

- Setup Docker + docker-compose, přidání uživatele do `docker` skupiny- Setup Docker + docker-compose, přidání uživatele do `docker` skupiny

- Hardware-specific: `HARDWARE/mhs35_setup.sh` pro MHS35 displej- Hardware-specific: `HARDWARE/mhs35_setup.sh` pro MHS35 displej



**Vrstva 2: Docker orchestrace** (`docker-compose.yml`)**Vrstva 2: Docker orchestrace** (`docker-compose.yml`)

- **homeassistant** — Primární služba, síťový mód `host`, mount `./config:/config`- **homeassistant** — Primární služba, síťový mód `host`, mount `./config:/config`

- **mosquitto** — MQTT broker (1883 interní, 9001 WebSocket)- **mosquitto** — MQTT broker (1883 interní, 9001 WebSocket)

- **zigbee2mqtt** — Zigbee integrační most (`/dev/ttyUSB0`)- **zigbee2mqtt** — Zigbee integrační most (`/dev/ttyUSB0`)

- **nodered** — Automatizace a flow (port 1880)- **nodered** — Automatizace a flow (port 1880)

- **portainer** — Docker UI (port 9000)- **portainer** — Docker UI (port 9000)



**Config management — centrální workflow:****Config management — centrální workflow:**

```

```CONFIG/ (version control, zdroj)

CONFIG/ (version control, zdroj)  ↓ [sync_config.sh --force --validate]

  ↓ [sync_config.sh --force --validate]config/ (runtime, Docker mount)

config/ (runtime, Docker mount)  ↓ [docker-compose restart homeassistant]

  ↓ [docker-compose restart homeassistant]Home Assistant proces

Home Assistant proces```

```

---

---

### 🔄 Praktické workflow — Co dělat

## 🔄 Praktické workflow — Co dělat

#### Po klonování: Instalace

### Po klonování: Instalace```bash

./install.sh install                           # Systémové závislosti

```bash./setup_master.sh                              # Menu: vyberte instalaci

./install.sh install                           # Systémové závislosti./POST_INSTALL/post_install_setup_menu.sh      # Post-install (volitelné)

./setup_master.sh                              # Menu: vyberte instalaci```

./POST_INSTALL/post_install_setup_menu.sh      # Post-install (volitelné)

```#### Po úpravě konfigurace

```bash

### Po úpravě konfigurace# 1. Editujte VŽDY CONFIG/, nikdy config/

nano CONFIG/configuration.yaml

```bashnano CONFIG/automations.yaml

# 1. Editujte VŽDY CONFIG/, nikdy config/

nano CONFIG/configuration.yaml# 2. Náhled změn

nano CONFIG/automations.yaml./scripts/sync_config.sh --dry-run



# 2. Náhled změn# 3. Nasazení + YAML validace (PyYAML + Home Assistant custom tagy)

./scripts/sync_config.sh --dry-run./scripts/sync_config.sh --force --validate



# 3. Nasazení + YAML validace (PyYAML + Home Assistant custom tagy)# 4. Restart Home Assistant

./scripts/sync_config.sh --force --validatedocker-compose restart homeassistant

```

# 4. Restart Home Assistant

docker-compose restart homeassistant#### Diagnostika a opravy

``````bash

# Menu diagnostiky

### Diagnostika a opravy./setup_master.sh                      # Volba: 5 = Diagnostika



```bash# Nebo přímo

# Menu diagnostikydocker-compose logs -f homeassistant

./setup_master.sh                      # Volba: 5 = Diagnostikadocker-compose logs mosquitto

./DIAGNOSTICS/health_dashboard.sh

# Nebo přímo./DIAGNOSTICS/quick_scan.sh

docker-compose logs -f homeassistant```

docker-compose logs mosquitto

./DIAGNOSTICS/health_dashboard.sh---

./DIAGNOSTICS/quick_scan.sh

```### 📋 Klíčové skripty — Co existuje a jak se používá



---| Script | Účel | Příklady |

|--------|------|----------|

## 📋 Klíčové skripty — Co existuje a jak se používá| `scripts/sync_config.sh` | Synchronizace CONFIG/ → config/ s PyYAML validací | `--dry-run` (náhled), `--force --validate` (nasazení) |

| `scripts/validate_yaml.sh` | Validace všech YAML souborů v config/ | `--all` (všechny) |

| Script | Účel | Příklady || `scripts/validate_ha_config.py` | **HA-aware** YAML validace (rozpoznává !include, !secret) | `validate_ha_config.py config/configuration.yaml` |

|--------|------|----------|| `scripts/backup_config.sh` | Záloha config/ do backups/ s rotací | `--keep 7` (zachovat 7 záloh) |

| `scripts/sync_config.sh` | Synchronizace CONFIG/ → config/ s YAML validací | `--dry-run`, `--force --validate` || `scripts/setup_cron_backup.sh` | Automatické zálohování každých 12h | `install` (nainstalovat), `remove` (odinstalovat) |

| `scripts/validate_yaml.sh` | Validace všech YAML souborů | `--all` (všechny) || `scripts/system_check.sh` | Kontrola integrity: bash syntaxe, YAML validace, oprávnění | Generuje report |

| `scripts/validate_ha_config.py` | HA-aware YAML validace (rozpoznává !include, !secret) | `validate_ha_config.py config/configuration.yaml` || `POST_INSTALL/setup_file_explorer.sh` | Samba, SFTP, web file browser | Interaktivní menu |

| `scripts/backup_config.sh` | Záloha config/ do backups/ s rotací | `--keep 7` (zachovat 7 záloh) || `POST_INSTALL/setup_maintenance.sh` | Cron cleanup, log rotation, Docker optimization | — |

| `scripts/setup_cron_backup.sh` | Automatické zálohování každých 12h | `install`, `remove` |

| `scripts/system_check.sh` | Kontrola integrity: bash, YAML, oprávnění | Generuje report |---

| `scripts/install_hacs_repos.sh` | Správa 18+ HACS custom repozitářů | `--list`, `--install-all`, `--install-essentials` |

| `POST_INSTALL/setup_file_explorer.sh` | Samba, SFTP, web file browser | Interaktivní menu |### ✅ Konvence a pravidla (nutné pro CI/CD)

| `POST_INSTALL/setup_maintenance.sh` | Cron cleanup, log rotation, Docker optimization | — |

**Bash skripty:**

---- Začátek: `#!/bin/bash` + `set -euo pipefail` (exit na chybu, undefined vars, pipe failure)

- Logování: `log "zpráva"` nebo `echo "[$(date)] zpráva"`

## ✅ Konvence a pravidla (nutné pro CI/CD)- Syntax check: `bash -n script.sh` (před committem)

- Permissions: `chmod +x script.sh` (při přidání nového skriptu)

### Bash skripty- Bez `root`: Skripty nikdy NEspouštějte jako root; `sudo` se volá interně



- Začátek: `#!/bin/bash` + `set -euo pipefail` (exit na chybu, undefined vars, pipe failure)**YAML konfigurace:**

- Logování: `log "zpráva"` nebo `echo "[$(date)] zpráva"`- Zdroj: `CONFIG/` (git tracked) — **VŽDY tu editujte**

- Syntax check: `bash -n script.sh` (před committem)- Runtime: `config/` (Docker mount) — **autosynchronizováno**

- Permissions: `chmod +x script.sh` (při přidání nového skriptu)- Validace: `python3 -c "import yaml; yaml.safe_load(open('soubor.yaml'))"`

- Bez `root`: Skripty nikdy NEspouštějte jako root; `sudo` se volá interně- Home Assistant custom tagy: `!include`, `!secret`, `!include_dir_merge_named` — validuje `validate_ha_config.py`



### YAML konfigurace**Dokumentace:**

- Nová funkcionalita → přidejte zápis do `CHANGELOG.md` (formát viz existující)

- Zdroj: `CONFIG/` (git tracked) — **VŽDY tu editujte**- Nový skript/feature → dokumentace v `README.md` nebo `docs/*.md`

- Runtime: `config/` (Docker mount) — **autosynchronizováno**- Změny konfigurace → popis do PR: "Přidán MQTT broker pro Zigbee, viz CONFIG/configuration.yaml"

- Validace: `python3 -c "import yaml; yaml.safe_load(open('soubor.yaml'))"`

- Home Assistant custom tagy: `!include`, `!secret`, `!include_dir_merge_named` — validuje `validate_ha_config.py`**CI/CD pipeline:**

- `.github/workflows/validate-yaml.yml` — Validace YAML na PR/push (automaticky)

### Dokumentace- `.github/workflows/lint.yml` — ShellCheck + Markdown lint + Bash syntax check

- `tests/test_scripts.sh` — Lokální unit testy pro sync, backup, validate

- Nová funkcionalita → přidejte zápis do `CHANGELOG.md` (formát viz existující)

- Nový skript/feature → dokumentace v `README.md` nebo `docs/*.md`---

- Změny konfigurace → popis do PR: "Přidán MQTT broker pro Zigbee, viz CONFIG/configuration.yaml"

### 🛠️ Vývoj — Jak přidat nový script nebo konfiguraci

### CI/CD pipeline

**Nový Bash script:**

- `.github/workflows/validate-yaml.yml` — Validace YAML na PR/push (automaticky)1. Vytvořte v `scripts/` nebo `POST_INSTALL/`

- `.github/workflows/lint.yml` — ShellCheck + Markdown lint + Bash syntax check2. Přidejte: `#!/bin/bash` + `set -euo pipefail` + help funkce

- `tests/test_scripts.sh` — Lokální unit testy pro sync, backup, validate3. Test lokálně: `bash -n new_script.sh` a `chmod +x new_script.sh`

4. Přidejte testy do `tests/test_scripts.sh`

---5. Update: `CHANGELOG.md`, `README.md`

6. Push: GitHub Actions spustí ShellCheck + Bash syntax automaticky

## 🛠️ Vývoj — Jak přidat nový script nebo konfiguraci

**Nová Home Assistant konfigurace:**

### Nový Bash script1. Editujte `CONFIG/` (např. `CONFIG/packages/my_integration.yaml`)

2. Validujte: `./scripts/validate_ha_config.py CONFIG/packages/my_integration.yaml`

1. Vytvořte v `scripts/` nebo `POST_INSTALL/`3. Synchronizujte: `./scripts/sync_config.sh --force --validate`

2. Přidejte: `#!/bin/bash` + `set -euo pipefail` + help funkce4. Test: `docker-compose restart homeassistant` a zkontrolujte logy

3. Test lokálně: `bash -n new_script.sh` a `chmod +x new_script.sh`5. PR: Popište co se změnilo (např. "Přidán balíček pro Zigbee2MQTT s custom automacemi")

4. Přidejte testy do `tests/test_scripts.sh`

5. Update: `CHANGELOG.md`, `README.md`**Checklist před PR:**

6. Push: GitHub Actions spustí ShellCheck + Bash syntax automaticky```bash

bash -n setup_master.sh install.sh scripts/*.sh POST_INSTALL/*.sh    # Syntax check

### Nová Home Assistant konfigurace./scripts/validate_yaml.sh --all                                      # YAML validace

./tests/test_scripts.sh                                               # Unit testy (pokud k dispozici)

1. Editujte `CONFIG/` (např. `CONFIG/packages/my_integration.yaml`)```

2. Validujte: `./scripts/validate_ha_config.py CONFIG/packages/my_integration.yaml`

3. Synchronizujte: `./scripts/sync_config.sh --force --validate`---

4. Test: `docker-compose restart homeassistant` a zkontrolujte logy

5. PR: Popište co se změnilo (např. "Přidán balíček pro Zigbee2MQTT s custom automacemi")### ⚠️ Kritické detaily — Pasti a gotchas



### Checklist před PR1. **CONFIG/ vs config/**

   - `CONFIG/` = zdroj, version-controlled, editujte zde

```bash   - `config/` = runtime, Docker mount, auto-synchronizováno

bash -n setup_master.sh install.sh scripts/*.sh POST_INSTALL/*.sh    # Syntax check   - Pokud editujete `config/` přímo, změny budou ztraceny při dalším `sync_config.sh`

./scripts/validate_yaml.sh --all                                      # YAML validace

./tests/test_scripts.sh                                               # Unit testy (pokud k dispozici)2. **PyYAML a Home Assistant tagy**

```   - Standard `yaml.safe_load()` odmítne `!include`, `!secret`, `!include_dir_merge_named`

   - Projekt má speciální `validate_ha_config.py` který těmto tagům rozumí

---   - `sync_config.sh --validate` interně používá `validate_ha_config.py`



## ⚠️ Kritické detaily — Pasti a gotchas3. **Oprávnění a skupiny**

   - `docker` skupina — přístup k `/var/run/docker.sock`

### 1. CONFIG/ vs config/   - `dialout` skupina — přístup k `/dev/ttyUSB0` (Zigbee)

   - `sudo` pro systémové změny (Docker setup, cron jobs)

- `CONFIG/` = zdroj, version-controlled, editujte zde

- `config/` = runtime, Docker mount, auto-synchronizováno4. **Systemd vs Docker vs Supervised**

- Pokud editujete `config/` přímo, změny budou ztraceny při dalším `sync_config.sh`   - Projekt podporuje tři HA režimy: `homeassistant-supervised`, Docker, systemd

   - `setup_master.sh` menu umožňuje výběr

### 2. PyYAML a Home Assistant tagy   - Skripty mají podmíněné cesty pro každý režim



- Standard `yaml.safe_load()` odmítne `!include`, `!secret`, `!include_dir_merge_named`5. **Mosquitto network DNS**

- Projekt má speciální `validate_ha_config.py` který těmto tagům rozumí   - V Docker compose se Mosquitto jmenuje `mosquitto` (ne IP)

- `sync_config.sh --validate` interně používá `validate_ha_config.py`   - Home Assistant se připojuje: `mqtt: broker: mosquitto` (Docker interní DNS)



### 3. Oprávnění a skupiny---



- `docker` skupina — přístup k `/var/run/docker.sock`### 📚 Klíčové soubory pro referenci

- `dialout` skupina — přístup k `/dev/ttyUSB0` (Zigbee)

- `sudo` pro systémové změny (Docker setup, cron jobs)- **`docs/CONFIGURATION_MANAGEMENT.md`** — Detailní guide: CONFIG/ vs config/, workflow, troubleshooting

- **`docs/DEVELOPER_GUIDE.md`** — Přidání skriptů, modifikace konfigurace, testy

### 4. Systemd vs Docker vs Supervised- **`docs/TROUBLESHOOTING.md`** — Řešení chyb, diagnostika

- **`CHANGELOG.md`** — Historie verzí (přidejte nové záznamy)

- Projekt podporuje tři HA režimy: `homeassistant-supervised`, Docker, systemd- **`PROJECT_STRUCTURE.md`** — Přehled všech adresářů

- `setup_master.sh` menu umožňuje výběr- **`README.md`** — Veřejné API: instrukce pro uživatele

- Skripty mají podmíněné cesty pro každý režim

---

### 5. Mosquitto network DNS

### 🚀 Příkazy pro rychlou referenci

- V Docker compose se Mosquitto jmenuje `mosquitto` (ne IP)

- Home Assistant se připojuje: `mqtt: broker: mosquitto` (Docker interní DNS)```bash

# Instalace

---./install.sh install && ./setup_master.sh



## 📚 Klíčové soubory pro referenci# Config workflow

./scripts/sync_config.sh --dry-run                # Náhled

- **`docs/CONFIGURATION_MANAGEMENT.md`** — Detailní guide: CONFIG/ vs config/, workflow, troubleshooting./scripts/sync_config.sh --force --validate       # Nasazení

- **`docs/DEVELOPER_GUIDE.md`** — Přidání skriptů, modifikace konfigurace, testydocker-compose restart homeassistant

- **`docs/TROUBLESHOOTING.md`** — Řešení chyb, diagnostika

- **`CHANGELOG.md`** — Historie verzí (přidejte nové záznamy)# Validace

- **`PROJECT_STRUCTURE.md`** — Přehled všech adresářů./scripts/validate_yaml.sh --all

- **`README.md`** — Veřejné API: instrukce pro uživatele./scripts/validate_ha_config.py config/configuration.yaml



---# Zálohování

./scripts/backup_config.sh --keep 7

## 🚀 Příkazy pro rychlou referenci./scripts/setup_cron_backup.sh install



### Instalace# Diagnostika

./setup_master.sh                                  # Menu: 5

```bashdocker-compose logs -f

./install.sh install && ./setup_master.sh./DIAGNOSTICS/health_dashboard.sh

```

# CI/CD checks

### Config workflowbash -n scripts/*.sh POST_INSTALL/*.sh             # Syntax

./tests/test_scripts.sh                            # Unit testy

```bash```

./scripts/sync_config.sh --dry-run                # Náhled

./scripts/sync_config.sh --force --validate       # Nasazení---

docker-compose restart homeassistant

```**TL;DR:** Editujte `CONFIG/`, spusťte `sync + validate`, commitujte s popisem. GitHub Actions si ověří YAML/Bash. Všechny nové skripty: `set -euo pipefail`, help funkce, syntax check. Viz `docs/` pro detaily.


### Validace

```bash
./scripts/validate_yaml.sh --all
./scripts/validate_ha_config.py config/configuration.yaml
```

### Zálohování

```bash
./scripts/backup_config.sh --keep 7
./scripts/setup_cron_backup.sh install
```

### Diagnostika

```bash
./setup_master.sh                                  # Menu: 5
docker-compose logs -f
./DIAGNOSTICS/health_dashboard.sh
```

### CI/CD checks

```bash
bash -n scripts/*.sh POST_INSTALL/*.sh             # Syntax
./tests/test_scripts.sh                            # Unit testy
```

---

## 📝 TL;DR

Editujte `CONFIG/`, spusťte `sync + validate`, commitujte s popisem. GitHub Actions si ověří YAML/Bash. Všechny nové skripty: `set -euo pipefail`, help funkce, syntax check. Viz `docs/` pro detaily.
