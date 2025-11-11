# Průvodce pro vývojáře

Jak modifikovat a testovat tento projekt.

## Struktura projektu

```
.
├── CONFIG/              # Zdrojové konfigurace Home Assistant
├── config/              # Runtime konfigurace (synchronizováno z CONFIG/)
├── INSTALLATION/        # Instalační skripty
├── POST_INSTALL/        # Post-instalační úkoly
├── DIAGNOSTICS/         # Diagnostické nástroje
├── scripts/             # Pomocné skripty (sync, validate, backup, cron)
├── tests/               # Testy
├── TEMPLATES/           # Šablony a příklady
├── HARDWARE/            # Hardware nastavení (MHS35 displej)
├── docker-compose.yml   # Docker služby
└── setup_master.sh      # Hlavní instalační skript
```

## Přidání nového skriptu

1. Vytvořte skript v `scripts/` nebo `POST_INSTALL/`
2. Přidejte `#!/bin/bash` a `set -euo pipefail` na začátek
3. Přidejte help funkci (vrácením kódu 1)
4. Spusťte `bash -n` na syntaxovou kontrolu
5. Napište testy do `tests/test_scripts.sh`
6. Aktualizujte `README.md` a `CHANGELOG.md`

## Modifikace konfigurace Home Assistant

1. Editujte zdrojový soubor v `CONFIG/` (např. `CONFIG/configuration.yaml`)
2. Spusťte: `./scripts/sync_config.sh --dry-run` (náhled)
3. Spusťte: `./scripts/sync_config.sh --force --validate` (nasazení)
4. Restartujte službu: `docker-compose restart homeassistant`
5. V PR popište, jaký soubor v `CONFIG/` jste změnili

## Přidání YAML konfigurace

Všechny YAML soubory se musí validovat pomocí PyYAML:

```bash
./scripts/validate_yaml.sh --all
```

Lokálně si můžete ověřit:

```python
import yaml
yaml.safe_load(open('config/configuration.yaml'))
```

## Spuštění testů

```bash
chmod +x tests/test_scripts.sh
./tests/test_scripts.sh
```

Testy zkontrolují:
- `backup_config.sh` vytvoří archiv
- `sync_config.sh --dry-run` zobrazí změny
- `sync_config.sh --force` zkopíruje soubory
- Oprávnění všech skriptů

## Linting a kvalita kódu

Spusťte syntax check:

```bash
bash -n setup_master.sh install.sh scripts/*.sh POST_INSTALL/*.sh
```

Spusťte ShellCheck (pokud dostupný):

```bash
shellcheck setup_master.sh install.sh scripts/*.sh
```

## CI/CD procesy

- **Validace YAML** — `.github/workflows/validate-yaml.yml` spouští na PR a push
- **PR šablona** — `.github/PULL_REQUEST_TEMPLATE.md` vede autory k testování

## Zálohování a údržba

Automatické zálohování:

```bash
./scripts/setup_cron_backup.sh install
```

Ruční záloha:

```bash
./scripts/backup_config.sh --keep 10
```

## Diagnostika a troubleshooting

Spusťte diagnostiku:

```bash
./setup_master.sh
# Vyberte možnost 5: Diagnostika systému
```

Nebo ručně:

```bash
docker-compose ps
docker logs homeassistant
docker-compose logs mosquitto
```

## Před odesláním PR

1. ✅ Spusťte `bash -n` na všechny bash skripty
2. ✅ Spusťte `./scripts/validate_yaml.sh --all`
3. ✅ Spusťte `tests/test_scripts.sh`
4. ✅ Aktualizujte `CHANGELOG.md`
5. ✅ Popište co se změnilo v `CONFIG/`
6. ✅ Testujte `--dry-run` před real nasazením

## Verzování

Projekt používá [Semantic Versioning](https://semver.org/):
- MAJOR.MINOR.PATCH (např. 2.1.0)
- Aktualizujte `CHANGELOG.md` při každé změně
