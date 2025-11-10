#!/usr/bin/env python3
"""
Home Assistant Device Structure Scanner
Kompletní analýza všech zařízení, entit, oblastí a jejich vztahů
"""

import json
import yaml
from pathlib import Path
import datetime
import logging
from typing import Dict, List, Any
import sqlite3
import requests

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class HomeAssistantDeviceScanner:
    def __init__(self, config_path: str = "/config", ha_url: str = "http://localhost:8123"):
        self.config_path = Path(config_path)
        self.ha_url = ha_url
        self.scan_results = {
            "scan_date": datetime.datetime.now().isoformat(),
            "areas": {},
            "devices": {},
            "entities": {},
            "integrations": {},
            "automations": {},
            "scripts": {},
            "relationships": {},
            "statistics": {}
        }
    
    def scan_from_database(self):
        """Načte data z SQLite databáze Home Assistant"""
        logger.info("Skenuji data z databáze...")
        
        db_path = self.config_path / "home-assistant_v2.db"
        if not db_path.exists():
            logger.error("Databáze Home Assistant nebyla nalezena!")
            return
        
        try:
            conn = sqlite3.connect(str(db_path))
            cursor = conn.cursor()
            
            # Získání všech entit
            cursor.execute("SELECT entity_id, state, attributes FROM states WHERE last_updated > datetime('now', '-1 day')")
            entities = cursor.fetchall()
            
            for entity_id, state, attributes in entities:
                entity_info = {
                    "entity_id": entity_id,
                    "state": state,
                    "attributes": json.loads(attributes) if attributes else {}
                }
                self.scan_results["entities"][entity_id] = entity_info
            
            # Získání zařízení
            cursor.execute("SELECT id, name_by_user, area_id, model, manufacturer FROM devices")
            devices = cursor.fetchall()
            
            for device_id, name, area_id, model, manufacturer in devices:
                device_info = {
                    "id": device_id,
                    "name": name,
                    "area_id": area_id,
                    "model": model,
                    "manufacturer": manufacturer,
                    "entities": []
                }
                self.scan_results["devices"][device_id] = device_info
            
            conn.close()
            logger.info(f"Načteno {len(entities)} entit a {len(devices)} zařízení z databáze")
            
        except Exception as e:
            logger.error(f"Chyba při čtení databáze: {e}")
    
    def scan_from_config_files(self):
        """Analyzuje konfigurační soubory pro další informace"""
        logger.info("Analyzuji konfigurační soubory...")
        
        # Načtení areas
        areas_file = self.config_path / ".storage" / "core.area_registry"
        if areas_file.exists():
            try:
                with open(areas_file, 'r') as f:
                    areas_data = json.load(f)
                    for area in areas_data.get("data", {}).get("areas", []):
                        self.scan_results["areas"][area["area_id"]] = {
                            "name": area["name"],
                            "devices": [],
                            "entities": []
                        }
            except Exception as e:
                logger.error(f"Chyba při čtení areas: {e}")
        
        # Načtení automatizací a skriptů z YAML
        self.scan_automations_and_scripts()
        
        # Analýza vztahů
        self.analyze_relationships()
    
    def scan_automations_and_scripts(self):
        """Analyzuje automatizace a skripty"""
        logger.info("Analyzuji automatizace a skripty...")
        
        # Automatizace
        automation_files = [
            self.config_path / "automations.yaml",
            self.config_path / "configuration.yaml"
        ]
        
        for file_path in automation_files:
            if file_path.exists():
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    # Jednoduchá analýza - hledání entit v automatizacích
                    lines = content.split('\n')
                    for i, line in enumerate(lines):
                        if 'entity_id:' in line:
                            # Extrahování entity_id
                            parts = line.split('entity_id:')
                            if len(parts) > 1:
                                entity_ref = parts[1].strip()
                                if entity_ref.startswith('"') or entity_ref.startswith("'"):
                                    entity_ref = entity_ref[1:-1]
                                
                                if entity_ref in self.scan_results["entities"]:
                                    self.scan_results["entities"][entity_ref]["used_in_automations"] = True
                                    
                except Exception as e:
                    logger.error(f"Chyba při analýze {file_path}: {e}")
    
    def analyze_relationships(self):
        """Analyzuje vztahy mezi entitami, zařízeními a oblastmi"""
        logger.info("Analyzuji vztahy...")
        
        # Spojení zařízení s oblastmi
        for device_id, device_info in self.scan_results["devices"].items():
            area_id = device_info.get("area_id")
            if area_id and area_id in self.scan_results["areas"]:
                self.scan_results["areas"][area_id]["devices"].append(device_id)
        
        # Spojení entit se zařízeními (z atributů)
        for entity_id, entity_info in self.scan_results["entities"].items():
            device_id = entity_info.get("attributes", {}).get("device_id")
            if device_id and device_id in self.scan_results["devices"]:
                self.scan_results["devices"][device_id]["entities"].append(entity_id)
            
            # Přidání entity do oblasti přes zařízení
            if device_id and device_id in self.scan_results["devices"]:
                area_id = self.scan_results["devices"][device_id].get("area_id")
                if area_id and area_id in self.scan_results["areas"]:
                    self.scan_results["areas"][area_id]["entities"].append(entity_id)
    
    def generate_statistics(self):
        """Generuje statistiky o struktuře"""
        logger.info("Generuji statistiky...")
        
        stats = self.scan_results["statistics"]
        
        # Počty
        stats["total_areas"] = len(self.scan_results["areas"])
        stats["total_devices"] = len(self.scan_results["devices"])
        stats["total_entities"] = len(self.scan_results["entities"])
        
        # Rozdělení entit podle domény
        domain_stats = {}
        for entity_id in self.scan_results["entities"]:
            domain = entity_id.split('.')[0]
            domain_stats[domain] = domain_stats.get(domain, 0) + 1
        
        stats["entities_by_domain"] = domain_stats
        
        # Zařízení podle oblasti
        devices_by_area = {}
        for area_id, area_info in self.scan_results["areas"].items():
            devices_by_area[area_info["name"]] = len(area_info["devices"])
        
        stats["devices_by_area"] = devices_by_area
        
        # Nejčastější výrobci
        manufacturers = {}
        for device_info in self.scan_results["devices"].values():
            manufacturer = device_info.get("manufacturer", "Neznámý")
            manufacturers[manufacturer] = manufacturers.get(manufacturer, 0) + 1
        
        stats["manufacturers"] = manufacturers
    
    def generate_detailed_report(self, output_file: Path = None):
        """Generuje podrobný report"""
        if not output_file:
            output_file = self.config_path / f"device_structure_report_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write("=" * 80 + "\n")
            f.write("HOME ASSISTANT - KOMPLETNÍ STRUKTURA ZAŘÍZENÍ\n")
            f.write("=" * 80 + "\n\n")
            
            # Statistiky
            stats = self.scan_results["statistics"]
            f.write("📊 SOUHRNNÉ STATISTIKY:\n")
            f.write("-" * 40 + "\n")
            f.write(f"Oblasti: {stats.get('total_areas', 0)}\n")
            f.write(f"Zařízení: {stats.get('total_devices', 0)}\n")
            f.write(f"Entity: {stats.get('total_entities', 0)}\n")
            f.write("\n")
            
            # Entity podle domény
            f.write("🏷️  ENTITY PODLE DOMÉNY:\n")
            f.write("-" * 40 + "\n")
            for domain, count in sorted(stats.get('entities_by_domain', {}).items(), key=lambda x: x[1], reverse=True):
                f.write(f"{domain}: {count}\n")
            f.write("\n")
            
            # Oblasti
            f.write("🏠 OBLASTI A JEJICH ZAŘÍZENÍ:\n")
            f.write("-" * 40 + "\n")
            for area_id, area_info in self.scan_results["areas"].items():
                f.write(f"\n📌 {area_info['name']}:\n")
                f.write(f"   Zařízení: {len(area_info['devices'])}\n")
                f.write(f"   Entity: {len(area_info['entities'])}\n")
                
                # Zařízení v oblasti
                for device_id in area_info["devices"]:
                    device = self.scan_results["devices"][device_id]
                    f.write(f"   🔧 {device.get('name', 'Nepojmenované')} ({device_id})\n")
                    
                    # Entity zařízení
                    for entity_id in device.get("entities", []):
                        entity = self.scan_results["entities"].get(entity_id, {})
                        state = entity.get("state", "unknown")
                        f.write(f"      • {entity_id} = {state}\n")
            
            # Zařízení bez oblasti
            f.write("\n🔧 ZAŘÍZENÍ BEZ OBLASTI:\n")
            f.write("-" * 40 + "\n")
            orphaned_devices = 0
            for device_id, device_info in self.scan_results["devices"].items():
                if not device_info.get("area_id"):
                    f.write(f"   {device_info.get('name', 'Nepojmenované')} ({device_id})\n")
                    orphaned_devices += 1
            
            if orphaned_devices == 0:
                f.write("   ✅ Všechna zařízení mají přiřazenou oblast\n")
            
            # Výrobci
            f.write("\n🏭 VÝROBCI ZAŘÍZENÍ:\n")
            f.write("-" * 40 + "\n")
            for manufacturer, count in sorted(stats.get('manufacturers', {}).items(), key=lambda x: x[1], reverse=True):
                f.write(f"   {manufacturer}: {count} zařízení\n")
            
            # Podrobný seznam všech entit
            f.write("\n📋 KOMPLETNÍ SEZNAM ENTIT:\n")
            f.write("-" * 40 + "\n")
            for entity_id, entity_info in sorted(self.scan_results["entities"].items()):
                state = entity_info.get("state", "unknown")
                friendly_name = entity_info.get("attributes", {}).get("friendly_name", "")
                f.write(f"{entity_id} = {state}")
                if friendly_name:
                    f.write(f" ({friendly_name})")
                f.write("\n")
        
        return str(output_file)
    
    def generate_visual_map(self, output_file: Path = None):
        """Generuje vizuální mapu vztahů"""
        if not output_file:
            output_file = self.config_path / f"device_visual_map_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write("🏠 VIZUÁLNÍ MAPA HOME ASSISTANT\n")
            f.write("=" * 60 + "\n\n")
            
            for area_id, area_info in self.scan_results["areas"].items():
                f.write(f"┌─ OBLAST: {area_info['name']}\n")
                
                for device_id in area_info["devices"]:
                    device = self.scan_results["devices"][device_id]
                    f.write(f"│  ┌─ ZAŘÍZENÍ: {device.get('name', 'Nepojmenované')}\n")
                    f.write(f"│  │   Model: {device.get('model', 'Neznámý')}\n")
                    f.write(f"│  │   Výrobce: {device.get('manufacturer', 'Neznámý')}\n")
                    
                    for entity_id in device.get("entities", []):
                        entity = self.scan_results["entities"].get(entity_id, {})
                        state = entity.get("state", "unknown")
                        f.write(f"│  │   └─ {entity_id} = {state}\n")
                
                f.write("│\n")
            
            f.write("\nLEGENDA:\n")
            f.write("┌─ Oblast\n")
            f.write("│  ┌─ Zařízení\n")
            f.write("│  │   └─ Entita\n")
        
        return str(output_file)
    
    def run_complete_scan(self):
        """Provede kompletní skenování"""
        logger.info("🔍 Spouštím kompletní skenování struktury zařízení...")
        
        self.scan_from_database()
        self.scan_from_config_files()
        self.generate_statistics()
        
        # Generování reportů
        report_file = self.generate_detailed_report()
        visual_map_file = self.generate_visual_map()
        
        logger.info("✅ Skenování dokončeno!")
        
        return {
            "report_file": report_file,
            "visual_map_file": visual_map_file,
            "statistics": self.scan_results["statistics"]
        }

def main():
    """Hlavní funkce"""
    print("🔍 Home Assistant Device Structure Scanner")
    print("=" * 50)
    
    scanner = HomeAssistantDeviceScanner("/config")
    
    print("Skenování struktury zařízení...")
    results = scanner.run_complete_scan()
    
    stats = results["statistics"]
    
    print(f"\n✅ Reporty vygenerovány:")
    print(f"   📄 Podrobný report: {results['report_file']}")
    print(f"   🗺️  Vizuální mapa: {results['visual_map_file']}")
    
    print(f"\n📊 NALEZENO:")
    print(f"   🏠 Oblastí: {stats.get('total_areas', 0)}")
    print(f"   🔧 Zařízení: {stats.get('total_devices', 0)}")
    print(f"   🏷️  Entit: {stats.get('total_entities', 0)}")
    
    # Top 5 domén
    domains = stats.get('entities_by_domain', {})
    top_domains = sorted(domains.items(), key=lambda x: x[1], reverse=True)[:5]
    print(f"\n🔝 TOP 5 typů zařízení:")
    for domain, count in top_domains:
        print(f"   {domain}: {count} entit")

if __name__ == "__main__":
    main()