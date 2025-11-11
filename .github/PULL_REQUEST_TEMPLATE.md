<!-- Popis: použijte tuto šablonu pro změny, které ovlivňují konfiguraci Home Assistant -->

## Stručný popis změn

<!-- Co měníte a proč -->

## Změny v konfiguraci
- Pokud upravujete soubory v `CONFIG/`, uveďte přesné soubory (např. `CONFIG/configuration.yaml`, `CONFIG/automations.yaml`)
- Popište, jak se má změna nasadit (např. `./scripts/sync_config.sh --force --validate` a `docker-compose restart homeassistant`)

## Kontrola před PR
- Spuštěno: `./scripts/validate_yaml.sh --all` ✅/❌
- Spuštěno: `./scripts/sync_config.sh --dry-run` ✅/❌

## Poznámky pro reviewera
- Potřebuje PR speciální oprávnění nebo systémové změny (sudo opětovnání, přidání do skupin)?
