# RPi5 Home Assistant Suite — Instrukce pro AI Kodovací Agenty# RPi5 Home Assistant Suite — Instrukce pro AI Kodovací Agenty# RPi5 Home Assistant Suite — Instrukce pro AI Kodovací Agenty



Konkrétní pokyny pro produktivní práci v tomto projektu. Zaměřte se na architekturu, pracovní postupy a konvence.



---Konkrétní pokyny pro produktivní práci v tomto projektu. Zaměřte se na architektura, pracovní postupy a konvence.Konkrétní pokyny pro produktivní práci v tomto projektu. Zaměřte se na architektura, pracovní postupy a konvence.



## 🏗️ Architektura — „Big Picture"



Repo orchestruje **dvoustupňový Docker deployment** Home Assistant na RPi5:------



### Vrstva 1: Systémová instalace (`install.sh` → `setup_master.sh`)



- Instalace APT balíčků (Python, Docker, systemd-resolved, dbus)## 🏗️ Architektura — „Big Picture"### 🏗️ Architektura — „Big Picture"

- Ověření PyYAML (pro validaci YAML)

- Setup Docker + docker-compose, přidání uživatele do `docker` skupiny

- Hardware-specific: `HARDWARE/mhs35_setup.sh` pro MHS35 displej

Repo orchestruje **dvoustupňový Docker deployment** Home Assistant na RPi5:Repo orchestruje **dvoustupňový Docker deployment** Home Assistant na RPi5:

### Vrstva 2: Docker orchestrace (`docker-compose.yml`)



- **homeassistant** — Primární služba, síťový mód `host`, mount `./config:/config`

- **mosquitto** — MQTT broker (1883 interní, 9001 WebSocket)**Vrstva 1: Systémová instalace** (`install.sh` → `setup_master.sh`)**Vrstva 1: Systémová instalace** (`install.sh` → `setup_master.sh`)

- **zigbee2mqtt** — Zigbee integrační most (`/dev/ttyUSB0`)

- **nodered** — Automatizace a flow (port 1880)- Instalace APT balíčků (Python, Docker, systemd-resolved, dbus)- Instalace APT balíčků (Python, Docker, systemd-resolved, dbus)

- **portainer** — Docker UI (port 9000)

- Ověření PyYAML (pro validaci YAML)- Ověření PyYAML (pro validaci YAML)

### Config management — centrální workflow

- Setup Docker + docker-compose, přidání uživatele do `docker` skupiny- Setup Docker + docker-compose, přidání uživatele do `docker` skupiny

```

CONFIG/ (version control, zdroj)- Hardware-specific: `HARDWARE/mhs35_setup.sh` pro MHS35 displej- Hardware-specific: `HARDWARE/mhs35_setup.sh` pro MHS35 displej

  ↓ [sync_config.sh --force --validate]

config/ (runtime, Docker mount)

  ↓ [docker-compose restart homeassistant]

Home Assistant proces**Vrstva 2: Docker orchestrace** (`docker-compose.yml`)**Vrstva 2: Docker orchestrace** (`docker-compose.yml`)

```

- **homeassistant** — Primární služba, síťový mód `host`, mount `./config:/config`- **homeassistant** — Primární služba, síťový mód `host`, mount `./config:/config`

---

- **mosquitto** — MQTT broker (1883 interní, 9001 WebSocket)- **mosquitto** — MQTT broker (1883 interní, 9001 WebSocket)

## 🔄 Praktické workflow — Co dělat

- **zigbee2mqtt** — Zigbee integrační most (`/dev/ttyUSB0`)- **zigbee2mqtt** — Zigbee integrační most (`/dev/ttyUSB0`)

### Po klonování: Instalace

- **nodered** — Automatizace a flow (port 1880)- **nodered** — Automatizace a flow (port 1880)

```bash

./install.sh install                           # Systémové závislosti- **portainer** — Docker UI (port 9000)- **portainer** — Docker UI (port 9000)

./setup_master.sh                              # Menu: vyberte instalaci

./POST_INSTALL/post_install_setup_menu.sh      # Post-install (volitelné)

```

**Config management — centrální workflow:****Config management — centrální workflow:**

### Po úpravě konfigurace

```

```bash

# 1. Editujte VŽDY CONFIG/, nikdy config/```CONFIG/ (version control, zdroj)

nano CONFIG/configuration.yaml

nano CONFIG/automations.yamlCONFIG/ (version control, zdroj)  ↓ [sync_config.sh --force --validate]



# 2. Náhled změn  ↓ [sync_config.sh --force --validate]config/ (runtime, Docker mount)

./scripts/sync_config.sh --dry-run

config/ (runtime, Docker mount)  ↓ [docker-compose restart homeassistant]

# 3. Nasazení + YAML validace (PyYAML + Home Assistant custom tagy)

./scripts/sync_config.sh --force --validate  ↓ [docker-compose restart homeassistant]Home Assistant proces



# 4. Restart Home AssistantHome Assistant proces```

docker-compose restart homeassistant

``````



### Diagnostika a opravy---



```bash---

# Menu diagnostiky

./setup_master.sh                      # Volba: 5 = Diagnostika### 🔄 Praktické workflow — Co dělat



# Nebo přímo## 🔄 Praktické workflow — Co dělat

docker-compose logs -f homeassistant

docker-compose logs mosquitto#### Po klonování: Instalace

./DIAGNOSTICS/health_dashboard.sh

./DIAGNOSTICS/quick_scan.sh### Po klonování: Instalace```bash

```

./install.sh install                           # Systémové závislosti

---

```bash./setup_master.sh                              # Menu: vyberte instalaci

## 📋 Klíčové skripty — Co existuje a jak se používá

./install.sh install                           # Systémové závislosti./POST_INSTALL/post_install_setup_menu.sh      # Post-install (volitelné)

| Script | Účel | Příklady |

|--------|------|----------|./setup_master.sh                              # Menu: vyberte instalaci```

| `scripts/sync_config.sh` | Synchronizace CONFIG/ → config/ s YAML validací | `--dry-run`, `--force --validate` |

| `scripts/validate_yaml.sh` | Validace všech YAML souborů | `--all` (všechny) |./POST_INSTALL/post_install_setup_menu.sh      # Post-install (volitelné)

| `scripts/validate_ha_config.py` | HA-aware YAML validace (rozpoznává !include, !secret) | `validate_ha_config.py config/configuration.yaml` |

| `scripts/backup_config.sh` | Záloha config/ do backups/ s rotací | `--keep 7` (zachovat 7 záloh) |```#### Po úpravě konfigurace

| `scripts/setup_cron_backup.sh` | Automatické zálohování každých 12h | `install`, `remove` |

| `scripts/system_check.sh` | Kontrola integrity: bash syntaxe, YAML validace, oprávnění | Generuje report |```bash

| `scripts/install_hacs_repos.sh` | Správa 18+ HACS custom repozitářů | `--list`, `--install-all`, `--install-essentials` |

| `POST_INSTALL/setup_file_explorer.sh` | Samba, SFTP, web file browser | Interaktivní menu |### Po úpravě konfigurace# 1. Editujte VŽDY CONFIG/, nikdy config/

| `POST_INSTALL/setup_maintenance.sh` | Cron cleanup, log rotation, Docker optimization | — |

nano CONFIG/configuration.yaml

---

```bashnano CONFIG/automations.yaml

## ✅ Konvence a pravidla (nutné pro CI/CD)

# 1. Editujte VŽDY CONFIG/, nikdy config/

### Bash skripty

nano CONFIG/configuration.yaml# 2. Náhled změn

- Začátek: bash shebang + `set -euo pipefail` (exit na chybu, undefined vars, pipe failure)

- Logování: `log "zpráva"` nebo `echo "[$(date)] zpráva"`nano CONFIG/automations.yaml./scripts/sync_config.sh --dry-run

- Syntax check: `bash -n script.sh` (před committem)

- Permissions: `chmod +x script.sh` (při přidání nového skriptu)

- Bez `root`: Skripty nikdy NEspouštějte jako root; `sudo` se volá interně

# 2. Náhled změn# 3. Nasazení + YAML validace (PyYAML + Home Assistant custom tagy)

### YAML konfigurace

./scripts/sync_config.sh --dry-run./scripts/sync_config.sh --force --validate

- Zdroj: `CONFIG/` (git tracked) — **VŽDY tu editujte**

- Runtime: `config/` (Docker mount) — **autosynchronizováno**

- Validace: `python3 -c "import yaml; yaml.safe_load(open('soubor.yaml'))"`

- Home Assistant custom tagy: `!include`, `!secret`, `!include_dir_merge_named` — validuje `validate_ha_config.py`# 3. Nasazení + YAML validace (PyYAML + Home Assistant custom tagy)# 4. Restart Home Assistant



### Dokumentace./scripts/sync_config.sh --force --validatedocker-compose restart homeassistant



- Nová funkcionalita → přidejte zápis do `CHANGELOG.md` (formát viz existující)```

- Nový skript/feature → dokumentace v `README.md` nebo `docs/*.md`

- Změny konfigurace → popis do PR: "Přidán MQTT broker pro Zigbee, viz CONFIG/configuration.yaml"# 4. Restart Home Assistant



### CI/CD pipelinedocker-compose restart homeassistant#### Diagnostika a opravy



- `.github/workflows/validate-yaml.yml` — Validace YAML na PR/push (automaticky)``````bash

- `.github/workflows/lint.yml` — ShellCheck + Markdown lint + Bash syntax check

- `tests/test_scripts.sh` — Lokální unit testy pro sync, backup, validate# Menu diagnostiky



---### Diagnostika a opravy./setup_master.sh                      # Volba: 5 = Diagnostika



## 🛠️ Vývoj — Jak přidat nový script nebo konfiguraci



### Nový Bash script```bash# Nebo přímo



1. Vytvořte v `scripts/` nebo `POST_INSTALL/`# Menu diagnostikydocker-compose logs -f homeassistant

2. Přidejte: bash shebang + `set -euo pipefail` + help funkce

3. Test lokálně: `bash -n new_script.sh` a `chmod +x new_script.sh`./setup_master.sh                      # Volba: 5 = Diagnostikadocker-compose logs mosquitto

4. Přidejte testy do `tests/test_scripts.sh`

5. Update: `CHANGELOG.md`, `README.md`./DIAGNOSTICS/health_dashboard.sh

6. Push: GitHub Actions spustí ShellCheck + Bash syntax automaticky

# Nebo přímo./DIAGNOSTICS/quick_scan.sh

### Nová Home Assistant konfigurace

docker-compose logs -f homeassistant```

1. Editujte `CONFIG/` (např. `CONFIG/packages/my_integration.yaml`)

2. Validujte: `./scripts/validate_ha_config.py CONFIG/packages/my_integration.yaml`docker-compose logs mosquitto

3. Synchronizujte: `./scripts/sync_config.sh --force --validate`

4. Test: `docker-compose restart homeassistant` a zkontrolujte logy./DIAGNOSTICS/health_dashboard.sh---

5. PR: Popište co se změnilo (např. "Přidán balíček pro Zigbee2MQTT s custom automacemi")

./DIAGNOSTICS/quick_scan.sh

### Checklist před PR

```### 📋 Klíčové skripty — Co existuje a jak se používá

```bash

bash -n setup_master.sh install.sh scripts/*.sh POST_INSTALL/*.sh    # Syntax check

./scripts/validate_yaml.sh --all                                      # YAML validace

./tests/test_scripts.sh                                               # Unit testy (pokud k dispozici)---| Script | Účel | Příklady |

```

|--------|------|----------|

---

## 📋 Klíčové skripty — Co existuje a jak se používá| `scripts/sync_config.sh` | Synchronizace CONFIG/ → config/ s PyYAML validací | `--dry-run` (náhled), `--force --validate` (nasazení) |

## ⚠️ Kritické detaily — Pasti a gotchas

| `scripts/validate_yaml.sh` | Validace všech YAML souborů v config/ | `--all` (všechny) |

### 1. CONFIG/ vs config/

| Script | Účel | Příklady || `scripts/validate_ha_config.py` | **HA-aware** YAML validace (rozpoznává !include, !secret) | `validate_ha_config.py config/configuration.yaml` |

- `CONFIG/` = zdroj, version-controlled, editujte zde

- `config/` = runtime, Docker mount, auto-synchronizováno|--------|------|----------|| `scripts/backup_config.sh` | Záloha config/ do backups/ s rotací | `--keep 7` (zachovat 7 záloh) |

- Pokud editujete `config/` přímo, změny budou ztraceny při dalším `sync_config.sh`

| `scripts/sync_config.sh` | Synchronizace CONFIG/ → config/ s YAML validací | `--dry-run`, `--force --validate` || `scripts/setup_cron_backup.sh` | Automatické zálohování každých 12h | `install` (nainstalovat), `remove` (odinstalovat) |

### 2. PyYAML a Home Assistant tagy

| `scripts/validate_yaml.sh` | Validace všech YAML souborů | `--all` (všechny) || `scripts/system_check.sh` | Kontrola integrity: bash syntaxe, YAML validace, oprávnění | Generuje report |

- Standard `yaml.safe_load()` odmítne `!include`, `!secret`, `!include_dir_merge_named`

- Projekt má speciální `validate_ha_config.py` který těmto tagům rozumí| `scripts/validate_ha_config.py` | HA-aware YAML validace (rozpoznává !include, !secret) | `validate_ha_config.py config/configuration.yaml` || `POST_INSTALL/setup_file_explorer.sh` | Samba, SFTP, web file browser | Interaktivní menu |

- `sync_config.sh --validate` interně používá `validate_ha_config.py`

| `scripts/backup_config.sh` | Záloha config/ do backups/ s rotací | `--keep 7` (zachovat 7 záloh) || `POST_INSTALL/setup_maintenance.sh` | Cron cleanup, log rotation, Docker optimization | — |

### 3. Oprávnění a skupiny

| `scripts/setup_cron_backup.sh` | Automatické zálohování každých 12h | `install`, `remove` |

- `docker` skupina — přístup k `/var/run/docker.sock`

- `dialout` skupina — přístup k `/dev/ttyUSB0` (Zigbee)| `scripts/system_check.sh` | Kontrola integrity: bash, YAML, oprávnění | Generuje report |---

- `sudo` pro systémové změny (Docker setup, cron jobs)

| `scripts/install_hacs_repos.sh` | Správa 18+ HACS custom repozitářů | `--list`, `--install-all`, `--install-essentials` |

### 4. Systemd vs Docker vs Supervised

| `POST_INSTALL/setup_file_explorer.sh` | Samba, SFTP, web file browser | Interaktivní menu |### ✅ Konvence a pravidla (nutné pro CI/CD)

- Projekt podporuje tři HA režimy: `homeassistant-supervised`, Docker, systemd

- `setup_master.sh` menu umožňuje výběr| `POST_INSTALL/setup_maintenance.sh` | Cron cleanup, log rotation, Docker optimization | — |

- Skripty mají podmíněné cesty pro každý režim

**Bash skripty:**

### 5. Mosquitto network DNS

---- Začátek: bash shebang + `set -euo pipefail` (exit na chybu, undefined vars, pipe failure)

- V Docker compose se Mosquitto jmenuje `mosquitto` (ne IP)

- Home Assistant se připojuje: `mqtt: broker: mosquitto` (Docker interní DNS)- Logování: `log "zpráva"` nebo `echo "[$(date)] zpráva"`



---## ✅ Konvence a pravidla (nutné pro CI/CD)- Syntax check: `bash -n script.sh` (před committem)



## 📚 Klíčové soubory pro referenci- Permissions: `chmod +x script.sh` (při přidání nového skriptu)



- **`docs/CONFIGURATION_MANAGEMENT.md`** — Detailní guide: CONFIG/ vs config/, workflow, troubleshooting### Bash skripty- Bez `root`: Skripty nikdy NEspouštějte jako root; `sudo` se volá interně

- **`docs/DEVELOPER_GUIDE.md`** — Přidání skriptů, modifikace konfigurace, testy

- **`docs/TROUBLESHOOTING.md`** — Řešení chyb, diagnostika

- **`CHANGELOG.md`** — Historie verzí (přidejte nové záznamy)

- **`PROJECT_STRUCTURE.md`** — Přehled všech adresářů- Začátek: bash shebang + `set -euo pipefail` (exit na chybu, undefined vars, pipe failure)**YAML konfigurace:**

- **`README.md`** — Veřejné API: instrukce pro uživatele

- Logování: `log "zpráva"` nebo `echo "[$(date)] zpráva"`- Zdroj: `CONFIG/` (git tracked) — **VŽDY tu editujte**

---

- Syntax check: `bash -n script.sh` (před committem)- Runtime: `config/` (Docker mount) — **autosynchronizováno**

## 🚀 Příkazy pro rychlou referenci

- Permissions: `chmod +x script.sh` (při přidání nového skriptu)- Validace: `python3 -c "import yaml; yaml.safe_load(open('soubor.yaml'))"`

### Instalace

- Bez `root`: Skripty nikdy NEspouštějte jako root; `sudo` se volá interně- Home Assistant custom tagy: `!include`, `!secret`, `!include_dir_merge_named` — validuje `validate_ha_config.py`

```bash

./install.sh install && ./setup_master.sh

```

### YAML konfigurace**Dokumentace:**

### Config workflow

- Nová funkcionalita → přidejte zápis do `CHANGELOG.md` (formát viz existující)

```bash

./scripts/sync_config.sh --dry-run                # Náhled- Zdroj: `CONFIG/` (git tracked) — **VŽDY tu editujte**- Nový skript/feature → dokumentace v `README.md` nebo `docs/*.md`

./scripts/sync_config.sh --force --validate       # Nasazení

docker-compose restart homeassistant- Runtime: `config/` (Docker mount) — **autosynchronizováno**- Změny konfigurace → popis do PR: "Přidán MQTT broker pro Zigbee, viz CONFIG/configuration.yaml"

```

- Validace: `python3 -c "import yaml; yaml.safe_load(open('soubor.yaml'))"`

### Validace

- Home Assistant custom tagy: `!include`, `!secret`, `!include_dir_merge_named` — validuje `validate_ha_config.py`**CI/CD pipeline:**

```bash

./scripts/validate_yaml.sh --all- `.github/workflows/validate-yaml.yml` — Validace YAML na PR/push (automaticky)

./scripts/validate_ha_config.py config/configuration.yaml

```### Dokumentace- `.github/workflows/lint.yml` — ShellCheck + Markdown lint + Bash syntax check



### Zálohování- `tests/test_scripts.sh` — Lokální unit testy pro sync, backup, validate



```bash- Nová funkcionalita → přidejte zápis do `CHANGELOG.md` (formát viz existující)

./scripts/backup_config.sh --keep 7

./scripts/setup_cron_backup.sh install- Nový skript/feature → dokumentace v `README.md` nebo `docs/*.md`---

```

- Změny konfigurace → popis do PR: "Přidán MQTT broker pro Zigbee, viz CONFIG/configuration.yaml"

### Diagnostika

### 🛠️ Vývoj — Jak přidat nový script nebo konfiguraci

```bash

./setup_master.sh                                  # Menu: 5### CI/CD pipeline

docker-compose logs -f

./DIAGNOSTICS/health_dashboard.sh**Nový Bash script:**

```

- `.github/workflows/validate-yaml.yml` — Validace YAML na PR/push (automaticky)1. Vytvořte v `scripts/` nebo `POST_INSTALL/`

### CI/CD checks

- `.github/workflows/lint.yml` — ShellCheck + Markdown lint + Bash syntax check2. Přidejte: bash shebang + `set -euo pipefail` + help funkce

```bash

bash -n scripts/*.sh POST_INSTALL/*.sh             # Syntax- `tests/test_scripts.sh` — Lokální unit testy pro sync, backup, validate3. Test lokálně: `bash -n new_script.sh` a `chmod +x new_script.sh`

./tests/test_scripts.sh                            # Unit testy

```4. Přidejte testy do `tests/test_scripts.sh`



------5. Update: `CHANGELOG.md`, `README.md`



## 📝 TL;DR6. Push: GitHub Actions spustí ShellCheck + Bash syntax automaticky



Editujte `CONFIG/`, spusťte `sync + validate`, commitujte s popisem. GitHub Actions si ověří YAML/Bash. Všechny nové skripty: `set -euo pipefail`, help funkce, syntax check. Viz `docs/` pro detaily.## 🛠️ Vývoj — Jak přidat nový script nebo konfiguraci


**Nová Home Assistant konfigurace:**

### Nový Bash script1. Editujte `CONFIG/` (např. `CONFIG/packages/my_integration.yaml`)

2. Validujte: `./scripts/validate_ha_config.py CONFIG/packages/my_integration.yaml`

1. Vytvořte v `scripts/` nebo `POST_INSTALL/`3. Synchronizujte: `./scripts/sync_config.sh --force --validate`

2. Přidejte: bash shebang + `set -euo pipefail` + help funkce4. Test: `docker-compose restart homeassistant` a zkontrolujte logy

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
