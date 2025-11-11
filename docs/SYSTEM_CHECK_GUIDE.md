# System Check & Version Selection Guide

Skript `scripts/system_check.sh` zajišťuje integritu systémových souborů a umožňuje výběr verze instalace.

## 📋 Funkce

### 1. Kontrola Systémových Souborů

#### Bash Skripty
```bash
./scripts/system_check.sh
# Vyberte: 2
```
- Kontrola syntaxe všech `.sh` souborů
- Detekce chyb v kódu
- Zpráva o počtu chyb

#### YAML Soubory
```bash
./scripts/system_check.sh
# Vyberte: 3
```
- Validace všech `.yaml` a `.yml` souborů
- Detekce syntaktických chyb
- Automatická instalace PyYAML (pokud chybí)

#### Markdown Dokumentace
```bash
./scripts/system_check.sh
# Vyberte: 4
```
- Kontrola struktury `.md` souborů
- Verifikace headingů

#### Struktura Adresářů
```bash
./scripts/system_check.sh
# Vyberte: 5
```
- Ověření přítomnosti povinných adresářů:
  - `scripts/`, `POST_INSTALL/`, `CONFIG/`, `config/`
  - `docs/`, `tests/`, `ansible/`, `.github/`

#### Kritické Soubory
```bash
./scripts/system_check.sh
# Vyberte: 6
```
- Kontrola přítomnosti klíčových souborů:
  - `setup_master.sh`, `install.sh`, `docker-compose.yml`
  - `README.md`, `CHANGELOG.md`, `.github/copilot-instructions.md`

#### Oprávnění Skriptů
```bash
./scripts/system_check.sh
# Vyberte: 7
```
- Kontrola `chmod +x` (executable bit)
- Automatická oprava (pokud chybí)

#### Velikosti Souborů
```bash
./scripts/system_check.sh
# Vyberte: 8
```
- Kontrola neobvyklých velikostí
- Varování na velmi malé (<50B) nebo velké (>50KB) soubory

### 2. Výběr Verze Instalace

```bash
./scripts/system_check.sh
# Vyberte: 9
```

Nabízí 9 verzí instalace:

#### Home Assistant Instalace
1. **Home Assistant Supervised** — Docker + Supervised mode
2. **Home Assistant Docker** — Jen Docker, bez Supervised
3. **Full Suite** — Všechny komponenty (Home Assistant + MQTT + Zigbee + Node-RED)

#### Hardware Specifické
4. **MHS35 Interactive** — Interaktivní setup displeje
5. **MHS35 Auto** — Automatický setup displeje
6. **Minimální Setup** — Jen základy

#### Docker Compose
7. **Standard Docker Compose** — Standardní konfigurace
8. **HA Docker Compose** — Home Assistant specifická
9. **Vlastní** — Uživatelská konfigurace

### 3. Generování Reportu

```bash
./scripts/system_check.sh
# Vyberte: 10
```

Vytvoří kompletní report obsahující:
- Počty souborů (Bash, YAML, Markdown)
- Git informace (pokud je repo)
- Systémové informace (OS, Kernel, Disk, RAM)

## 🔄 Integrace se `setup_master.sh`

Skript je automaticky integrován do hlavního menu:

```bash
./setup_master.sh
```

Menu:
```
9) Kontrola systémových souborů
10) Vybrat verzi instalace
```

## 🚀 Použití

### Rychlá Kontrola

```bash
# Všechno najednou
./scripts/system_check.sh
# Vyberte: 1
```

### Specifická Kontrola

```bash
# Jen Bash skripty
./scripts/system_check.sh
# Vyberte: 2

# Jen YAML
./scripts/system_check.sh
# Vyberte: 3
```

### Oprava Problémů

```bash
# Oprava oprávnění
./scripts/system_check.sh
# Vyberte: 7
```

## 📊 Příklady Výstupů

### Kompletní Kontrola
```
[2025-11-12 10:00:00] Spuštění kontroly systému
[2025-11-12 10:00:00] 🔍 Kontrola struktury adresářů...
[2025-11-12 10:00:00]   ✅ scripts/
[2025-11-12 10:00:00]   ✅ POST_INSTALL/
...
[2025-11-12 10:00:01] ✅ Všechny kontroly dokončeny
```

### YAML Validace
```
[2025-11-12 10:00:00] 🔍 Kontrola YAML souborů...
[2025-11-12 10:00:00]   ✅ CONFIG/configuration.yaml
[2025-11-12 10:00:00]   ✅ CONFIG/automations.yaml
[2025-11-12 10:00:01] YAML souborů kontroleno: 4, Chyb: 0
```

### Výběr Verze
```
=========================================
📦 DOSTUPNÉ VERZE INSTALACE
=========================================

🏠 HOME ASSISTANT INSTALACE:
  1) Home Assistant Supervised (docker + supervised mode)
  2) Home Assistant Docker (pouze docker, bez supervised)
  3) Home Assistant Full Suite (všechny komponenty)

🖥️ HARDWARE SPECIFICKÉ:
  4) MHS35 TFT Display (interaktivní setup)
  5) MHS35 Auto Setup (plně automatický)
  6) Minimální setup (jen základy)

🐳 DOCKER COMPOSE:
  7) Standard Docker Compose
  8) Home Assistant Docker Compose
  9) Vlastní konfiguraci

Vyberte verzi instalace [1-9]: 
```

## ⚠️ Poznámky

1. **PyYAML** — Automaticky se instaluje, pokud chybí
2. **Oprávnění** — Některé kontroly vyžadují `sudo`
3. **Git** — Report detekuje Git info (pokud je repo)
4. **Logging** — Všechny akce se logují do `/home/$(whoami)/system_check.log`

## 🆘 Troubleshooting

### Chyba: "PyYAML není nainstalován"
```bash
sudo apt-get install python3-yaml
# nebo
sudo pip3 install pyyaml
```

### Chyba: "Skript není executable"
```bash
chmod +x scripts/system_check.sh
```

### Chyba: "Žádné verze instalace nebyly nalezeny"
- Zkontroluj, zda máš `/INSTALLATION/` adresář s instalačními skripty
- Zkontroluj, zda máš `/HARDWARE/` adresář s hardware setupy

## 📞 Support

- **Problémy** — Viz `docs/TROUBLESHOOTING.md`
- **Struktura** — Viz `PROJECT_STRUCTURE_v2.md`
- **Celkový Přehled** — Viz `IMPLEMENTATION_OVERVIEW.md`
