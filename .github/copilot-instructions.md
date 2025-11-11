## RPi5 Home Assistant Suite — instrukce pro AI kodovací agenty

Krátké, konkrétní pokyny, které vám pomohou být produktivní v tomto repozitáři.

- Projektová struktura: `INSTALLATION/`, `HARDWARE/`, `CONFIG/` (zdrojové HA config šablony), `DIAGNOSTICS/`, `POST_INSTALL/`, `TEMPLATES/`.
- Důležité soubory: `docker-compose.yml`, `setup_master.sh`, `install.sh`, `PROJECT_STRUCTURE.md`, `README.md`.

Hlavní myšlenka (big picture)
- Repo poskytuje kompletní instalační sadu pro Home Assistant na RPi5. Instalace má dvě vrstvy:
  1) systémové závislosti a HA supervised agenty via `install.sh` / `setup_master.sh` (APT + dpkg).
  2) Dockerové služby (Home Assistant, Mosquitto, Zigbee2MQTT, Node-RED, Portainer) spouštěné přes `docker-compose.yml`.
- `CONFIG/` (velká písmena) obsahuje zdrojové konfigurační šablony. Runtime očekává nízkopísmenný adresář `config/` (docker-compose a instalační skripty používají `./config`). Při modifikacích:
  - upravujte zdroj v `CONFIG/` nebo v `TEMPLATES/`, ale před spuštěním služeb se ujistěte, že odpovídající soubory jsou v `config/` (repo root) nebo aktualizujte `docker-compose.yml` podle potřeby.

Důležité workflow a příkazy
- Nastavení systému (po klonování):
  - Spusťte: `./install.sh install` (instaluje závislosti, Docker, os-agent). Tento skript volá apt/dpkg a mění skupiny uživatele (docker, dialout).
  - Poté spusťte: `./setup_master.sh` z kořenového adresáře projektu (skript kontroluje, že je spuštěn z adresáře s `docker-compose.yml`).
- Pro Docker služby (z kořene repo):
  - `docker-compose up -d` — použijí se služby definované v `docker-compose.yml`.
  - Kontrola: `docker-compose ps`, `docker logs <container>` nebo `docker-compose logs`.
- Diagnostika a opravy:
  - Spusťte `./setup_master.sh` → volba 5 (diagnostika) nebo použijte skripty v `DIAGNOSTICS/` (např. `repair_homeassistant.py`, `health_dashboard.sh`).

Projektové konvence a vzory (specifické)
- Skripty jsou bash s `set -e` a vlastní logovací funkcí — změny musí zachovat chování (pokud přidáváte kroky, používejte `log "..."` a vracejte nenulové kódy při chybě).
- Skripty kontrolují YAML pomocí Python `yaml.safe_load(...)`. Pokud generujete YAML, ujistěte se, že je kompatibilní s PyYAML (projekt očekává python3 + pyyaml při validaci).
- Nikdy nespouštějte hlavní instalační skripty jako `root` (skripty explicitně kontrolují `whoami` a exitují při root).
- Pokud přidáváte nový Docker service, aktualizujte `docker-compose.yml` a případně `TEMPLATES/docker-compose.yml.tmpl`.

Integrace a závislosti
- Repo používá apt/dpkg pro systémové balíčky a stahuje konkrétní `.deb` pro `os-agent` a `homeassistant-supervised` (kontrola verzí v skriptech). Pozor na architekturu (aarch64 pro RPi5).
- Docker kontejner `homeassistant` je mapován na `./config:/config` — to znamená, že runtime konfigurace HA se nachází v `config/`.
- Zigbee2MQTT očekává device mapping `/dev/ttyUSB0` — pokud upravujete integraci, zkontrolujte `docker-compose.yml` `devices:` a oprávnění (skupiny `dialout`).

Jak psát změny (praktické příklady)
- Menší změna konfigurace HA:
  1) upravte `CONFIG/configuration.yaml` (zdroj),
  2) zkopírujte do `config/configuration.yaml` (runtime),
  3) restartujte službu: `docker-compose restart homeassistant`.
- Přidání služby do compose:
  - Přidejte službu do `docker-compose.yml`, přidejte popis do `PROJECT_STRUCTURE.md` a případně vytvořte template v `TEMPLATES/`.

Pozor na časté pasti (edge cases)
- Rozdíl `CONFIG/` vs `config/` — to je zdroj mnoha zmatků. Před spuštěním Dockeru ověřte obsah `config/`.
- Skripty mění systémová nastavení (systemd, uživatelské skupiny). Testujte změny v izolovaném prostředí nebo VM.
- YAML validace používá lokální Python; pokud přidáte YAML-generující kód, přidejte test validace (můžete spustit `python3 -c "import yaml; yaml.safe_load(open('path'))"`).

Kde hledat příklady v repozitáři
- `docker-compose.yml` — hlavní composition a mappingy
- `setup_master.sh`, `install.sh` — všechny instalační postupy, kontrolní a diagnostické příklady
- `CONFIG/configuration.yaml`, `TEMPLATES/*` — příklady struktury HA konfigurace
- `HARDWARE/mhs35*` nebo `mhs35_setup.sh` — příklad specializovaného hardware setupu

Poslední poznámka
- Buďte explicitní: když navrhujete změnu konfigurace, v PR uveďte přesně jaký soubor v `CONFIG/` byl změněn a jak ho do `config/` nasadit (kopírování / restart služby). Pokud něco vyžaduje změnu systémových práv nebo instalaci balíčku, uveďte to jasně v PR popisu.

Pokud chcete, mohu tento soubor zkrátit, rozšířit o návrhy PR template nebo přidat kontrolní skripty pro synchronizaci `CONFIG/` -> `config/`.
