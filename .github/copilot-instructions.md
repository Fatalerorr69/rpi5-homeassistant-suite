## RPi5 Home Assistant Suite — instrukce pro AI kodovací agenty

Krátké, konkrétní pokyny, které vám pomohou být produktivní v tomto repozitáři.

**Projektová struktura:** `INSTALLATION/`, `HARDWARE/`, `CONFIG/` (zdrojové HA config), `DIAGNOSTICS/`, `POST_INSTALL/`, `TEMPLATES/`, `tests/`, `docs/`, `scripts/`.

**Klíčové soubory:** `docker-compose.yml`, `setup_master.sh`, `install.sh`, `PROJECT_STRUCTURE.md`, `README.md`, `CHANGELOG.md`.

### Architektura (big picture)

Repo poskytuje **kompletní instalační sadu** pro Home Assistant na RPi5 se **dvěma vrstvami**:
1. **Systémové vrstvy** — `install.sh` / `setup_master.sh` instalují závislosti, Docker, os-agent (APT + dpkg).
2. **Dockerové služby** — `docker-compose.yml` orchestruje: Home Assistant, Mosquitto (MQTT), Zigbee2MQTT, Node-RED, Portainer.

**Config management:** `CONFIG/` (zdroj) → `scripts/sync_config.sh` → `config/` (runtime). Před Docker startem se automaticky synchronizuje a validuje.

### Workflow: Instalace a nasazení

**Po klonování:**

```bash
./install.sh install            # Systémové závislosti, Docker
./setup_master.sh               # Home Assistant + Docker služby (menu vybere)
```

**Po změně konfigurace:**

```bash
./scripts/sync_config.sh --dry-run              # Náhled
./scripts/sync_config.sh --force --validate     # Nasazení + YAML check
docker-compose restart homeassistant
```

**Diagnostika:**

```bash
./setup_master.sh               # Menu: 5 = Diagnostika
# nebo
docker-compose logs -f
```

### Automatizace v projektu

- `scripts/sync_config.sh` — Synchronizace `CONFIG/` → `config/`, s validací YAML
- `scripts/validate_yaml.sh` — YAML validace (všechny `.yaml` pod `config/`)
- `scripts/backup_config.sh` — Zálohování s rotací (default 7 záloh)
- `scripts/setup_cron_backup.sh` — Instalace cron job (každých 12h)
- `POST_INSTALL/post_install_addons.sh` — Příprava runtime provedení
- `.github/workflows/validate-yaml.yml` — CI: YAML check na PR/push
- `.github/workflows/lint.yml` — CI: ShellCheck + Markdown lint
- `tests/test_scripts.sh` — Unit testy pro skripty

### Konvence a pravidla

- **Bash:** `set -euo pipefail` na začátek, logování přes `log "..."`, správné exit kódy.
- **YAML:** Všechny YAML kontrolovány přes `python3 -c "import yaml; yaml.safe_load(open(...))"`.
- **Root:** Hlavní skripty **nikdy** jako `root` (kontrola v kódu); změny vyžadují `sudo`.
- **Permissions:** Nový skript musí být `chmod +x`; testy spuštěny přes `bash -n`.
- **Dokumentace:** Každá nová funkcionalita → zápis do `CHANGELOG.md`, popis v `README.md` nebo `docs/`.

### Vývoj a testování

**Přidat nový skript:**

1. Vytvořte v `scripts/` nebo `POST_INSTALL/`, přidejte `#!/bin/bash` + `set -euo pipefail`
2. Testujte lokálně: `bash -n script.sh`
3. Přidejte test do `tests/test_scripts.sh`
4. Aktualizujte `CHANGELOG.md` a `README.md`

**Přidat novou config:**

1. Editujte `CONFIG/soubor.yaml`
2. Spusťte: `./scripts/sync_config.sh --dry-run`
3. Spusťte: `./scripts/sync_config.sh --force --validate`
4. V PR: popište co se změnilo a jak nasadit

**Před PR:**

```bash
bash -n setup_master.sh install.sh scripts/*.sh              # Syntax check
./scripts/validate_yaml.sh --all                             # YAML validace
./tests/test_scripts.sh                                      # Testy
```

### Klíčové adresáře a příklady

- `CONFIG/` — Zdrojové YAML konfigurace (configuration.yaml, automations.yaml, etc.)
- `config/` — Runtime (synchronizováno, docker mountuje)
- `scripts/` — Pomocné skripty (sync, backup, validate, cron)
- `tests/` — Unit testy (`test_scripts.sh`)
- `docs/` — DEVELOPER_GUIDE.md, TROUBLESHOOTING.md
- `DIAGNOSTICS/` — Health dashboard, repairovací skripty
- `.github/workflows/` — CI/CD (validate-yaml.yml, lint.yml)

### Příklady z repo

- `docker-compose.yml` — Služby a volume mappingy
- `setup_master.sh` — Instalace, diagnostika, repair logika
- `CONFIG/configuration.yaml` — HA config struktura
- `TEMPLATES/` — Ukázkové konfigurace a balíčky
- `HARDWARE/mhs35_setup.sh` — Hardware specializace

### Pozor na pasti

1. **`CONFIG/` vs `config/`** — `CONFIG/` je zdroj, `config/` runtime. Vždy synchronizujte před Docker.
2. **PyYAML dostupnost** — Instalace zajištěna, ale pokud chybí: `pip3 install pyyaml`.
3. **Oprávnění** — `docker` skupina pro Docker, `dialout` pro Zigbee USB, `sudo` pro systémové změny.
4. **Systemd/Supervised** — Projekt podporuje jak `homeassistant-supervised` tak Docker; skripty mají obě cesty.

### Kde hledat help

- **Dokumentace:** `docs/DEVELOPER_GUIDE.md`, `docs/TROUBLESHOOTING.md`
- **Historie:** `CHANGELOG.md`
- **Struktura:** `PROJECT_STRUCTURE.md`
- **Logy:** `/home/$(whoami)/ha_suite_install.log`, `docker logs <service>`, `journalctl -u homeassistant`
- **Diagnostika:** `./setup_master.sh` → volba 5 nebo `DIAGNOSTICS/health_dashboard.sh`

---

**Tl;dr:** Repo je **automatizovaný**, s **testováním a CI**, **zdrojovým config managementem** a **kompletní dokumentací**. Prostě: editujte `CONFIG/`, spusťte sync + validate, commitujte s popisem, otevřete PR.
