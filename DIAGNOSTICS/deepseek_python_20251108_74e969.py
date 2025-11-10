#!/usr/bin/env python3
"""
Home Assistant Complete Scanner
Prozkoumá celou instalaci a vygeneruje podrobný report
"""

import os
import json
import yaml
import subprocess
import datetime
from pathlib import Path
import hashlib
import logging
from typing import Dict, List, Any

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class HomeAssistantScanner:
    def __init__(self, config_path: str = "/config"):
        self.config_path = Path(config_path)
        self.scan_results = {
            "scan_date": datetime.datetime.now().isoformat(),
            "system_info": {},
            "directory_structure": {},
            "file_analysis": {},
            "configuration_analysis": {},
            "custom_components": {},
            "automations": {},
            "scripts": {},
            "entities": {},
            "integrations": {},
            "issues": [],
            "recommendations": []
        }
    
    def get_system_info(self):
        """Získá informace o systému"""
        logger.info("Získávám systémové informace...")
        
        try:
            # Informace o Home Assistant
            result = subprocess.run([
                "python", "-m", "homeassistant", 
                "--config", str(self.config_path), 
                "--version"
            ], capture_output=True, text=True)
            
            self.scan_results["system_info"]["homeassistant_version"] = result.stdout.strip() if result.returncode == 0 else "Neznámá"
            
        except Exception as e:
            logger.warning(f"Nelze získat verzi HA: {e}")
        
        # Informace o adresáři
        self.scan_results["system_info"]["config_path"] = str(self.config_path)
        self.scan_results["system_info"]["total_size"] = self.get_directory_size(self.config_path)
        
    def get_directory_structure(self):
        """Získá kompletní strukturu adresářů"""
        logger.info("Skenuji strukturu adresářů...")
        
        def scan_dir(path: Path, level: int = 0):
            structure = {
                "name": path.name,
                "path": str(path),
                "type": "directory",
                "size": self.get_directory_size(path),
                "children": []
            }
            
            try:
                for item in path.iterdir():
                    if item.is_dir():
                        if level < 5:  # Omezení hloubky rekurze
                            structure["children"].append(scan_dir(item, level + 1))
                    else:
                        file_info = {
                            "name": item.name,
                            "path": str(item),
                            "type": "file",
                            "size": item.stat().st_size,
                            "modified": datetime.datetime.fromtimestamp(item.stat().st_mtime).isoformat()
                        }
                        structure["children"].append(file_info)
            except PermissionError:
                structure["error"] = "Permission denied"
            
            return structure
        
        self.scan_results["directory_structure"] = scan_dir(self.config_path)
    
    def analyze_configuration_files(self):
        """Analyzuje všechny konfigurační soubory"""
        logger.info("Analyzuji konfigurační soubory...")
        
        yaml_files = list(self.config_path.glob("**/*.yaml")) + list(self.config_path.glob("**/*.yml"))
        
        for yaml_file in yaml_files:
            try:
                with open(yaml_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                file_analysis = {
                    "size": yaml_file.stat().st_size,
                    "lines": len(content.splitlines()),
                    "is_valid_yaml": True,
                    "entities_found": [],
                    "errors": []
                }
                
                # Validace YAML
                try:
                    data = yaml.safe_load(content)
                    if data:
                        # Analýza obsahu
                        self.analyze_yaml_content(yaml_file.name, data, file_analysis)
                except yaml.YAMLError as e:
                    file_analysis["is_valid_yaml"] = False
                    file_analysis["errors"].append(f"YAML chyba: {e}")
                
                self.scan_results["file_analysis"][str(yaml_file)] = file_analysis
                
            except Exception as e:
                self.scan_results["file_analysis"][str(yaml_file)] = {
                    "error": f"Chyba při čtení: {e}"
                }
    
    def analyze_yaml_content(self, filename: str, data: Any, analysis: Dict):
        """Analyzuje obsah YAML souboru"""
        if not isinstance(data, dict):
            return
        
        # Hledání entit
        entities_to_find = ["sensor", "binary_sensor", "light", "switch", "automation", "script"]
        
        for entity_type in entities_to_find:
            if entity_type in data:
                if isinstance(data[entity_type], list):
                    for item in data[entity_type]:
                        if isinstance(item, dict) and "name" in item:
                            analysis["entities_found"].append({
                                "type": entity_type,
                                "name": item.get("name"),
                                "platform": item.get("platform", "unknown")
                            })
        
        # Speciální analýza pro configuration.yaml
        if filename == "configuration.yaml":
            self.analyze_main_config(data)
    
    def analyze_main_config(self, config: Dict):
        """Analyzuje hlavní konfigurační soubor"""
        logger.info("Analyzuji hlavní konfiguraci...")
        
        main_config_analysis = {}
        
        # Kontrola základních sekcí
        essential_sections = ["default_config", "http", "logger", "frontend"]
        for section in essential_sections:
            main_config_analysis[section] = section in config
        
        # Analýza includovaných souborů
        includes_found = []
        for key, value in config.items():
            if isinstance(value, str) and value.startswith("!include"):
                includes_found.append({"key": key, "include": value})
        
        main_config_analysis["includes"] = includes_found
        self.scan_results["configuration_analysis"]["main_config"] = main_config_analysis
    
    def scan_custom_components(self):
        """Skenuje custom komponenty"""
        logger.info("Skenuji custom komponenty...")
        
        custom_components_path = self.config_path / "custom_components"
        if not custom_components_path.exists():
            self.scan_results["custom_components"]["status"] = "Neexistuje"
            return
        
        components = {}
        for component_dir in custom_components_path.iterdir():
            if component_dir.is_dir():
                component_info = {
                    "path": str(component_dir),
                    "size": self.get_directory_size(component_dir),
                    "files": [],
                    "has_manifest": False,
                    "manifest": {}
                }
                
                # Kontrola manifest.json
                manifest_file = component_dir / "manifest.json"
                if manifest_file.exists():
                    try:
                        with open(manifest_file, 'r') as f:
                            component_info["manifest"] = json.load(f)
                        component_info["has_manifest"] = True
                    except Exception as e:
                        component_info["manifest_error"] = str(e)
                
                # Seznam souborů
                for file in component_dir.glob("**/*.py"):
                    component_info["files"].append(file.name)
                
                components[component_dir.name] = component_info
        
        self.scan_results["custom_components"] = {
            "status": "Nalezeno",
            "count": len(components),
            "components": components
        }
    
    def scan_automations_and_scripts(self):
        """Analyzuje automatizace a skripty"""
        logger.info("Analyzuji automatizace a skripty...")
        
        # Hledání v hlavních souborech
        automation_files = [
            self.config_path / "automations.yaml",
            self.config_path / "scripts.yaml"
        ]
        
        for file_path in automation_files:
            if file_path.exists():
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    # Jednoduchá analýza - počítání aliasů
                    if "automations.yaml" in str(file_path):
                        automation_count = content.count("alias:")
                        self.scan_results["automations"]["count"] = automation_count
                        self.scan_results["automations"]["file"] = str(file_path)
                    
                    if "scripts.yaml" in str(file_path):
                        script_count = content.count("alias:")
                        self.scan_results["scripts"]["count"] = script_count
                        self.scan_results["scripts"]["file"] = str(file_path)
                        
                except Exception as e:
                    logger.error(f"Chyba při analýze {file_path}: {e}")
    
    def check_for_issues(self):
        """Kontroluje běžné problémy"""
        logger.info("Kontroluji problémy...")
        
        issues = []
        
        # Kontrola existence základních souborů
        essential_files = ["configuration.yaml", "secrets.yaml"]
        for file in essential_files:
            if not (self.config_path / file).exists():
                issues.append(f"Chybí základní soubor: {file}")
        
        # Kontrola velikosti souborů
        for file_path, analysis in self.scan_results["file_analysis"].items():
            if "size" in analysis and analysis["size"] > 1024 * 1024:  # 1MB
                issues.append(f"Velký soubor: {file_path} ({analysis['size']} bytes)")
            
            if "is_valid_yaml" in analysis and not analysis["is_valid_yaml"]:
                issues.append(f"Neplatný YAML: {file_path}")
        
        # Kontrola custom komponent
        if self.scan_results["custom_components"].get("status") == "Nalezeno":
            for comp_name, comp_info in self.scan_results["custom_components"]["components"].items():
                if not comp_info["has_manifest"]:
                    issues.append(f"Custom komponenta bez manifestu: {comp_name}")
        
        self.scan_results["issues"] = issues
    
    def generate_recommendations(self):
        """Generuje doporučení"""
        logger.info("Generuji doporučení...")
        
        recommendations = []
        
        # Doporučení na základě analýzy
        if not self.scan_results["automations"]:
            recommendations.append("Přidejte automatizace pro lepší automatizaci domácnosti")
        
        if not self.scan_results["custom_components"]:
            recommendations.append("Zvažte instalaci HACS pro rozšíření funkcionality")
        
        # Doporučení pro optimalizaci
        total_files = len(self.scan_results["file_analysis"])
        if total_files > 50:
            recommendations.append("Zvažte reorganizaci konfigurace do balíčků (packages)")
        
        self.scan_results["recommendations"] = recommendations
    
    def get_directory_size(self, path: Path) -> int:
        """Vypočítá velikost adresáře"""
        total_size = 0
        try:
            for file_path in path.rglob('*'):
                if file_path.is_file():
                    total_size += file_path.stat().st_size
        except (PermissionError, OSError):
            pass
        return total_size
    
    def run_full_scan(self):
        """Provede kompletní skenování"""
        logger.info("🔄 Spouštím kompletní skenování Home Assistant...")
        
        self.get_system_info()
        self.get_directory_structure()
        self.analyze_configuration_files()
        self.scan_custom_components()
        self.scan_automations_and_scripts()
        self.check_for_issues()
        self.generate_recommendations()
        
        logger.info("✅ Skenování dokončeno!")
        
        return self.scan_results
    
    def generate_report(self, output_file: str = None):
        """Vygeneruje report ze scan výsledků"""
        if not output_file:
            output_file = self.config_path / f"ha_scan_report_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        # Uložení JSON reportu
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(self.scan_results, f, indent=2, ensure_ascii=False)
        
        # Vytvoření human-readable reportu
        text_report = self.config_path / f"ha_scan_report_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        self.generate_text_report(text_report)
        
        return str(output_file), str(text_report)
    
    def generate_text_report(self, output_file: Path):
        """Vygeneruje textový report"""
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write("=" * 80 + "\n")
            f.write("HOME ASSISTANT COMPLETE SCAN REPORT\n")
            f.write("=" * 80 + "\n\n")
            
            # Systémové informace
            f.write("SYSTÉMOVÉ INFORMACE:\n")
            f.write("-" * 40 + "\n")
            for key, value in self.scan_results["system_info"].items():
                f.write(f"{key}: {value}\n")
            f.write("\n")
            
            # Struktura adresářů
            f.write("STRUKTURA ADRESÁŘŮ:\n")
            f.write("-" * 40 + "\n")
            f.write(f"Celková velikost: {self.scan_results['system_info']['total_size'] / 1024 / 1024:.2f} MB\n")
            f.write("\n")
            
            # Analýza souborů
            f.write("ANALÝZA KONFIGURAČNÍCH SOUBORŮ:\n")
            f.write("-" * 40 + "\n")
            for file_path, analysis in self.scan_results["file_analysis"].items():
                f.write(f"\n{file_path}:\n")
                f.write(f"  Velikost: {analysis.get('size', 0)} bytes\n")
                f.write(f"  Řádků: {analysis.get('lines', 0)}\n")
                f.write(f"  Validní YAML: {analysis.get('is_valid_yaml', 'N/A')}\n")
                if analysis.get('entities_found'):
                    f.write(f"  Nalezené entity: {len(analysis['entities_found'])}\n")
            
            # Custom komponenty
            f.write("\nCUSTOM KOMPONENTY:\n")
            f.write("-" * 40 + "\n")
            custom_comps = self.scan_results["custom_components"]
            f.write(f"Stav: {custom_comps.get('status', 'N/A')}\n")
            f.write(f"Počet: {custom_comps.get('count', 0)}\n")
            for comp_name, comp_info in custom_comps.get('components', {}).items():
                f.write(f"  {comp_name}: {len(comp_info.get('files', []))} souborů\n")
            
            # Automatizace a skripty
            f.write("\nAUTOMATIZACE A SKRIPTY:\n")
            f.write("-" * 40 + "\n")
            f.write(f"Automatizace: {self.scan_results['automations'].get('count', 0)}\n")
            f.write(f"Skripty: {self.scan_results['scripts'].get('count', 0)}\n")
            
            # Problémy
            f.write("\nPROBLÉMY:\n")
            f.write("-" * 40 + "\n")
            for issue in self.scan_results["issues"]:
                f.write(f"❌ {issue}\n")
            if not self.scan_results["issues"]:
                f.write("✅ Žádné kritické problémy nenalezeny\n")
            
            # Doporučení
            f.write("\nDOPORUČENÍ:\n")
            f.write("-" * 40 + "\n")
            for recommendation in self.scan_results["recommendations"]:
                f.write(f"💡 {recommendation}\n")
            
            f.write("\n" + "=" * 80 + "\n")
            f.write("KONEC REPORTU\n")
            f.write("=" * 80 + "\n")

def main():
    """Hlavní funkce"""
    print("🔍 Home Assistant Complete Scanner")
    print("=" * 50)
    
    scanner = HomeAssistantScanner("/config")
    
    print("Skenování může chvíli trvat...")
    scanner.run_full_scan()
    
    json_report, text_report = scanner.generate_report()
    
    print(f"\n✅ Reporty vygenerovány:")
    print(f"   JSON: {json_report}")
    print(f"   Text: {text_report}")
    
    # Zobrazení souhrnu
    print(f"\n📊 SOUHRN:")
    print(f"   Celková velikost: {scanner.scan_results['system_info']['total_size'] / 1024 / 1024:.2f} MB")
    print(f"   Konfiguračních souborů: {len(scanner.scan_results['file_analysis'])}")
    print(f"   Custom komponent: {scanner.scan_results['custom_components'].get('count', 0)}")
    print(f"   Automatizací: {scanner.scan_results['automations'].get('count', 0)}")
    print(f"   Skriptů: {scanner.scan_results['scripts'].get('count', 0)}")
    print(f"   Problémů: {len(scanner.scan_results['issues'])}")
    
    if scanner.scan_results['issues']:
        print(f"\n⚠️  Nalezené problémy:")
        for issue in scanner.scan_results['issues'][:5]:  # Prvních 5 problémů
            print(f"   - {issue}")

if __name__ == "__main__":
    main()