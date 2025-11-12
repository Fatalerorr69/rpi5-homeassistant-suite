# Configuration Management Guide

## Přehled

RPi5 Home Assistant Suite má **dva adresáře konfigurace**:

- **`CONFIG/`** — Zdrojové konfigurace (version control, templates)
- **`config/`** — Runtime konfigurace (Docker mounts, default)

## Struktura

```
PROJECT_ROOT/
├── CONFIG/                          # 📝 Zdroj (git tracked)
│   ├── configuration.yaml
│   ├── automations.yaml
│   ├── scripts.yaml
│   ├── secrets.yaml
│   ├── templates.yaml
│   ├── ui-lovelace.yaml
│   └── packages/                    # Integrační balíčky
│
├── config/                          # 🚀 Runtime (Docker mounts)
│   └── (synchronized from CONFIG/)
│
├── scripts/
│   ├── merge_configs.sh             # Synchronizace CONFIG/ → config/
│   ├── validate_ha_config.py        # YAML validace s HA tagy
│   ├── sync_config.sh               # Backup a synchronizace
│   └── validate_yaml.sh             # Obecná YAML validace
│
└── docker-compose.yml               # Mounty: ./config:/config
```

## Workflow

### 1. Instalace (poprvé)

```bash
git clone https://github.com/Fatalerorr69/rpi5-homeassistant-suite.git
cd rpi5-homeassistant-suite

# Instalace závislostí
./install.sh install

# Slučování a validace konfigurace
./scripts/merge_configs.sh

# Spuštění Home Assistant
./setup_master.sh  # Volba: Home Assistant
```

### 2. Editace konfigurace

**Vždy editujte `CONFIG/` adresář** (zdroj):

```bash
# Editace
nano CONFIG/configuration.yaml
nano CONFIG/automations.yaml
nano CONFIG/packages/my_integration.yaml

# Validace
./scripts/validate_ha_config.py CONFIG/configuration.yaml

# Synchronizace do runtime
./scripts/merge_configs.sh

# Restart Home Assistant v Docker
docker-compose restart homeassistant
```

### 3. Backup konfigurace

```bash
# Jednorázový backup
./scripts/backup_config.sh

# Instalace automatických záloh (cron)
./scripts/setup_cron_backup.sh

# Zobrazit dostupné zálohy
ls -lh backups/
```

## YAML Validace

### Home Assistant YAML

Home Assistant používá **custom YAML tagy**:

```yaml
# !include - zahrne externí soubor
template: !include templates.yaml

# !secret - načte hodnotu z secrets.yaml
mqtt:
  password: !secret mqtt_password

# !include_dir_merge_named - zahrne všechny .yaml z adresáře jako dict
homeassistant:
  packages: !include_dir_merge_named packages

# !include_dir_merge_list - zahrne všechny .yaml z adresáře jako list
automation: !include automations.yaml
```

### Validátor

```bash
# Validace s podporou HA tagů
python3 scripts/validate_ha_config.py config/configuration.yaml

# Výstup:
# ✅ configuration.yaml - Validní YAML
```

**Poznámka:** Generic YAML validátor (VS Code linter) nebude rozpoznávat `!include` tagy. To je **normální** — Home Assistant je umí.

## Synchronizace a Docker

### docker-compose.yml

```yaml
services:
  homeassistant:
    volumes:
      - ./config:/config        # config/ → /config v kontejneru
      - /etc/localtime:/etc/localtime:ro
```

### Workflow: Edit → Validate → Sync → Restart

```bash
# 1. Editace
vim CONFIG/automation/my_automation.yaml

# 2. Validace
./scripts/validate_ha_config.py CONFIG/

# 3. Synchronizace
./scripts/merge_configs.sh

# 4. Restart
docker-compose restart homeassistant

# 5. Kontrola logů
docker-compose logs -f homeassistant
```

## Troubleshooting

### Problem: YAML syntaxy error v Home Assistant

```yaml
# ❌ ŠPATNĚ (chybí mezera po klíči)
mqtt:broker: mosquitto

# ✅ SPRÁVNĚ
mqtt:
  broker: mosquitto
```

### Problem: !secret tag nefunguje

```yaml
# ✅ Ujistěte se, že secrets.yaml obsahuje klíč
# secrets.yaml
mqtt_password: "your_password"

# configuration.yaml
mqtt:
  password: !secret mqtt_password
```

### Problem: !include_dir_merge_named vyhazuje chybu

```yaml
# ✅ Ujistěte se, že adresář obsahuje .yaml soubory
packages/
  - energy_monitoring.yaml
  - security_cameras.yaml
  - gaming_pc.yaml
```

### Problem: Config se neupdatuje po editaci

```bash
# 1. Synchronizujte
./scripts/merge_configs.sh

# 2. Restartujte kontejner
docker-compose restart homeassistant

# 3. Zkontrolujte logy
docker-compose logs homeassistant | grep -i error
```

## Klíčové soubory

| Soubor | Účel |
|--------|------|
| `scripts/validate_ha_config.py` | YAML validace s HA tagy |
| `scripts/merge_configs.sh` | Synchronizace CONFIG/ → config/ |
| `scripts/sync_config.sh` | Backup + validace + synchronizace |
| `scripts/validate_yaml.sh` | Obecná YAML validace (bez custom tagů) |
| `.github/workflows/validate-yaml.yml` | CI/CD YAML checks |

## Best Practices

✅ **DO:**
- Editujte `CONFIG/` adresář
- Commitujte změny do git (`CONFIG/` je v git)
- Spusťte `merge_configs.sh` po editaci
- Validujte YAML před deploymentem
- Zálohujte před velkými změnami

❌ **DON'T:**
- Neměňte `config/` přímo (synchronizace smaže)
- Nepoužívejte generic YAML validator (neznají HA tagy)
- Necommitujte `config/` do git (je v .gitignore)
- Necommitujte `secrets.yaml` (obsahuje hesla!)

## Příklady

### Nový balíček (Package)

```bash
cat > CONFIG/packages/energy_monitoring.yaml << 'EOF'
# Energy Monitoring Package
template:
  - sensor:
      - name: "Daily Energy"
        unit_of_measurement: "kWh"
        value_template: "{{ states('sensor.total_energy') }}"
EOF

./scripts/validate_ha_config.py CONFIG/
./scripts/merge_configs.sh
docker-compose restart homeassistant
```

### Nová automatizace

```bash
cat >> CONFIG/automations.yaml << 'EOF'
# Night mode automation
- id: night_mode_on
  alias: Night Mode On
  trigger:
    platform: sun
    event: sunset
  action:
    - service: light.turn_off
      target:
        entity_id: light.living_room
EOF

./scripts/validate_ha_config.py CONFIG/automations.yaml
./scripts/merge_configs.sh
docker-compose restart homeassistant
```

## Další informace

- 📚 [Home Assistant YAML](https://www.home-assistant.io/docs/configuration/yaml/)
- 🔧 [Home Assistant Package System](https://www.home-assistant.io/docs/configuration/packages/)
- 📝 [Repository Structure](../PROJECT_STRUCTURE.md)
- 🚀 [Installation Guide](../README.md)
