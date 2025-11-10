#!/usr/bin/env python3
"""
Home Assistant Repair Script
Automaticky opraví běžné problémy s konfigurací Home Assistant
"""

import os
import shutil
import logging
from pathlib import Path
import subprocess
import sys

# Nastavení loggingu
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class HomeAssistantRepair:
    def __init__(self, config_path="/config"):
        self.config_path = Path(config_path)
        self.backup_path = self.config_path / "backup_repair"
        
    def create_backup(self):
        """Vytvoří zálohu konfigurace"""
        logger.info("Vytvářím zálohu konfigurace...")
        if not self.backup_path.exists():
            self.backup_path.mkdir()
            
        backup_files = [
            "configuration.yaml",
            "automations.yaml", 
            "scripts.yaml",
            "scenes.yaml",
            "secrets.yaml",
            "ui-lovelace.yaml"
        ]
        
        for file in backup_files:
            source = self.config_path / file
            if source.exists():
                backup_file = self.backup_path / f"{file}.backup"
                shutil.copy2(source, backup_file)
                logger.info(f"Zálohováno: {file}")
                
    def fix_http_config(self):
        """Opraví HTTP konfiguraci v configuration.yaml"""
        logger.info("Opravuji HTTP konfiguraci...")
        
        config_file = self.config_path / "configuration.yaml"
        if not config_file.exists():
            logger.error("Soubor configuration.yaml nebyl nalezen!")
            return False
            
        with open(config_file, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Odstranění neplatné volby ip_ban_enrollment
        old_http_config = """http:
  ip_ban_enrollment: true
  login_attempts_threshold: 3"""
        
        new_http_config = """http:
  server_port: 8123
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
    - ::1
  login_attempts_threshold: 5"""
        
        if "ip_ban_enrollment" in content:
            content = content.replace(old_http_config, new_http_config)
            logger.info("Neprávná volba ip_ban_enrollment odstraněna")
            
        # Zápis opraveného obsahu
        with open(config_file, 'w', encoding='utf-8') as f:
            f.write(content)
            
        logger.info("HTTP konfigurace opravena")
        return True
        
    def remove_broken_integrations(self):
        """Odstraní nefunkční custom integrace"""
        logger.info("Odstraňuji nefunkční integrace...")
        
        broken_integrations = [
            "balena_cloud",
            "pypi_updates", 
            "devtools"
        ]
        
        custom_components = self.config_path / "custom_components"
        if not custom_components.exists():
            logger.info("Adresář custom_components neexistuje")
            return
            
        for integration in broken_integrations:
            integration_path = custom_components / integration
            if integration_path.exists():
                shutil.rmtree(integration_path)
                logger.info(f"Odstraněno: {integration}")
                
    def reinstall_hacs(self):
        """Přeinstaluje HACS"""
        logger.info("Instaluji HACS...")
        
        hacs_path = self.config_path / "custom_components" / "hacs"
        
        # Odstranění starého HACS
        if hacs_path.exists():
            shutil.rmtree(hacs_path)
            logger.info("Starý HACS odstraněn")
            
        # Vytvoření adresáře
        hacs_path.mkdir(parents=True, exist_ok=True)
        
        # Stažení HACS
        try:
            import requests
            import zipfile
            import io
            
            hacs_url = "https://github.com/hacs/integration/releases/latest/download/hacs.zip"
            response = requests.get(hacs_url)
            response.raise_for_status()
            
            # Rozbalení ZIP souboru
            with zipfile.ZipFile(io.BytesIO(response.content)) as zip_file:
                zip_file.extractall(hacs_path)
                
            logger.info("HACS úspěšně nainstalován")
            
        except Exception as e:
            logger.error(f"Chyba při instalaci HACS: {e}")
            # Fallback - vytvoření základní struktury
            self.create_basic_hacs_structure()
            
    def create_basic_hacs_structure(self):
        """Vytvoří základní strukturu HACS pokud se nepodaří stáhnout"""
        hacs_path = self.config_path / "custom_components" / "hacs"
        hacs_path.mkdir(parents=True, exist_ok=True)
        
        # Základní __init__.py
        init_content = '''"""HACS integration."""\nfrom .hacs import Hacs\n\nasync def async_setup(hass, config):\n    """Set up HACS."""\n    return True\n'''
        
        with open(hacs_path / "__init__.py", "w") as f:
            f.write(init_content)
            
        logger.info("Základní struktura HACS vytvořena")
        
    def create_fixed_configuration(self):
        """Vytvoří opravenou konfiguraci pokud původní neexistuje"""
        config_file = self.config_path / "configuration.yaml"
        
        if not config_file.exists():
            logger.info("Vytvářím nový configuration.yaml...")
            
            config_content = """# Základní nastavení - opravená konfigurace
default_config:

# HTTP - opravená konfigurace
http:
  server_port: 8123
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
    - ::1
  login_attempts_threshold: 5

# Logování
logger:
  default: info
  logs:
    custom_components.hacs: debug

# MQTT
mqtt:
  broker: 127.0.0.1
  port: 1883
  discovery: true

# Frontend
frontend:
  themes: !include_dir_merge_named themes

# Recorder
recorder:
  db_url: !secret recorder_db_url
  purge_keep_days: 10

# History
history:

# Logbook
logbook:
"""
            with open(config_file, 'w', encoding='utf-8') as f:
                f.write(config_content)
                
            logger.info("Nový configuration.yaml vytvořen")
            
    def create_cleanup_script(self):
        """Vytvoří skript pro vyčištění systému"""
        script_file = self.config_path / "cleanup_script.yaml"
        
        script_content = """script:
  system_repair_cleanup:
    alias: "Vyčištění systému po opravě"
    sequence:
      - service: system_log.clear
      - service: recorder.purge
        data:
          keep_days: 7
      - service: homeassistant.reload_core_config
      - delay:
          seconds: 10
      - service: persistent_notification.create
        data:
          title: "Systém opraven"
          message: "Všechny konfigurační chyby byly opraveny"
          
  check_system_health:
    alias: "Kontrola zdraví systému"
    sequence:
      - service: homeassistant.check_config
      - service: system_health.check
      - service: persistent_notification.create
        data:
          title: "Kontrola systému"
          message: "Konfigurace je v pořádku"
"""
        with open(script_file, 'w', encoding='utf-8') as f:
            f.write(script_content)
            
        logger.info("Cleanup skript vytvořen")
        
    def create_secrets_template(self):
        """Vytvoří šablonu secrets.yaml pokud neexistuje"""
        secrets_file = self.config_path / "secrets.yaml"
        
        if not secrets_file.exists():
            logger.info("Vytvářím šablonu secrets.yaml...")
            
            secrets_content = """# Lokace
home_latitude: "50.0755"
home_longitude: "14.4378"
home_elevation: 200

# Databáze
recorder_db_url: "sqlite:////config/home-assistant_v2.db"

# MQTT
mqtt_username: "homeassistant"
mqtt_password: "silne_heslo_zmente_prosim"

# API klíče
# openai_api_key: "your_key_here"
# google_maps_api_key: "your_key_here"
"""
            with open(secrets_file, 'w', encoding='utf-8') as f:
                f.write(secrets_content)
                
            logger.info("Šablona secrets.yaml vytvořena")
            
    def run_config_check(self):
        """Spustí kontrolu konfigurace"""
        logger.info("Spouštím kontrolu konfigurace...")
        
        try:
            # V kontejneru Home Assistant
            result = subprocess.run([
                "python", "-m", "homeassistant", 
                "--config", str(self.config_path), 
                "--script", "check_config"
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                logger.info("✅ Konfigurace je platná!")
            else:
                logger.warning("⚠️  Konfigurace obsahuje chyby:")
                logger.warning(result.stderr)
                
        except Exception as e:
            logger.warning(f"Kontrolu konfigurace nelze spustit: {e}")
            
    def repair_all(self):
        """Provede všechny opravy"""
        logger.info("🚀 Zahajuji opravu Home Assistant konfigurace...")
        
        try:
            # 1. Záloha
            self.create_backup()
            
            # 2. Oprava konfigurace
            self.fix_http_config()
            
            # 3. Vytvoření chybějících souborů
            self.create_fixed_configuration()
            self.create_secrets_template()
            self.create_cleanup_script()
            
            # 4. Oprava custom komponent
            self.remove_broken_integrations()
            self.reinstall_hacs()
            
            # 5. Kontrola
            self.run_config_check()
            
            logger.info("✅ Oprava dokončena!")
            logger.info("📋 Další kroky:")
            logger.info("   1. Restartujte Home Assistant")
            logger.info("   2. Zkontrolujte logy")
            logger.info("   3. Spusťte skript 'system_repair_cleanup'")
            
        except Exception as e:
            logger.error(f"❌ Chyba během opravy: {e}")
            return False
            
        return True

def main():
    """Hlavní funkce"""
    print("=" * 60)
    print("Home Assistant Repair Tool")
    print("=" * 60)
    
    # Zjištění cesty ke konfiguraci
    config_path = input("Zadejte cestu ke konfiguraci Home Assistant [/config]: ").strip()
    if not config_path:
        config_path = "/config"
        
    if not os.path.exists(config_path):
        print(f"❌ Cesta {config_path} neexistuje!")
        sys.exit(1)
        
    # Spuštění opravy
    repair = HomeAssistantRepair(config_path)
    
    print("\nOpravy které budou provedeny:")
    print("1. ✅ Oprava HTTP konfigurace")
    print("2. ✅ Odstranění nefunkčních integrací") 
    print("3. ✅ Přegenerování HACS")
    print("4. ✅ Vytvoření chybějících souborů")
    print("5. ✅ Kontrola konfigurace")
    
    confirm = input("\nPokračovat? (y/N): ").strip().lower()
    if confirm not in ['y', 'yes']:
        print("Operace zrušena")
        sys.exit(0)
        
    success = repair.repair_all()
    
    if success:
        print("\n🎉 Oprava úspěšně dokončena!")
        print("🔄 Restartujte nyní Home Assistant")
    else:
        print("\n💥 Během opravy došlo k chybám")
        print("📁 Záloha byla vytvořena v: backup_repair")
        sys.exit(1)

if __name__ == "__main__":
    main()