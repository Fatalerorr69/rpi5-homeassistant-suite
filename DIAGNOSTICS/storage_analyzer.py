#!/usr/bin/env python3
"""
Home Assistant Storage Analyzer
Komplexní analýza úložišť, formátů a doporučení pro optimální rozdělení
"""

import os
import shutil
import subprocess
import json
from pathlib import Path
import datetime
import logging
from typing import Dict, List, Any, Tuple

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class StorageAnalyzer:
    def __init__(self):
        self.storage_info = {}
        self.analysis_results = {}
        self.recommendations = []
        
    def get_storage_devices(self) -> List[Dict]:
        """Získá informace o všech úložných zařízeních"""
        logger.info("Zjišťuji informace o úložných zařízeních...")
        
        devices = []
        
        try:
            # Použití lsblk pro detailní informace
            result = subprocess.run([
                'lsblk', '-o', 'NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,LABEL,MODEL', '-J'
            ], capture_output=True, text=True)
            
            if result.returncode == 0:
                lsblk_data = json.loads(result.stdout)
                for device in lsblk_data.get('blockdevices', []):
                    device_info = self.analyze_device(device)
                    if device_info:
                        devices.append(device_info)
            
        except Exception as e:
            logger.error(f"Chyba při získávání informací o zařízeních: {e}")
        
        return devices
    
    def analyze_device(self, device: Dict) -> Dict:
        """Analyzuje jednotlivé úložné zařízení"""
        device_info = {
            'name': device.get('name'),
            'size': device.get('size'),
            'type': device.get('type'),
            'mountpoint': device.get('mountpoint'),
            'filesystem': device.get('fstype'),
            'model': device.get('model', 'Neznámý'),
            'children': []
        }
        
        # Detekce typu zařízení
        device_info['device_type'] = self.detect_device_type(device_info)
        
        # Získání detailních informací
        device_info.update(self.get_device_details(device_info['name']))
        
        # Analýza dětí (partitions)
        if device.get('children'):
            for child in device['children']:
                child_info = self.analyze_device(child)
                device_info['children'].append(child_info)
        
        return device_info
    
    def detect_device_type(self, device: Dict) -> str:
        """Detekuje typ úložného zařízení"""
        name = device['name'].lower()
        model = device['model'].lower()
        mountpoint = device['mountpoint'] or ''
        
        # Detekce podle jména zařízení
        if 'mmcblk' in name or mountpoint == '/boot':
            return 'SD_CARD'
        elif 'nvme' in name or 'nvme' in model:
            return 'NVME'
        elif 'sd' in name and 'mmcblk' not in name:
            return 'USB_SSD'
        elif 'usb' in model:
            return 'USB_SSD'
        elif 'hd' in name or 'sda' in name or 'sdb' in name:
            return 'HDD'
        else:
            return 'UNKNOWN'
    
    def get_device_details(self, device_name: str) -> Dict:
        """Získá detailní informace o zařízení"""
        details = {}
        
        try:
            # SMART data pro HDD/SSD
            if not device_name.startswith('mmc'):
                smart_result = subprocess.run([
                    'sudo', 'smartctl', '-i', f'/dev/{device_name}'
                ], capture_output=True, text=True)
                
                if smart_result.returncode == 0:
                    details['smart_available'] = True
                    # Extrahování užitečných informací
                    for line in smart_result.stdout.split('\n'):
                        if 'Model Family' in line:
                            details['family'] = line.split(':')[1].strip()
                        elif 'User Capacity' in line:
                            details['capacity'] = line.split(':')[1].strip()
                        elif 'Sector Size' in line:
                            details['sector_size'] = line.split(':')[1].strip()
                        elif 'Rotation Rate' in line:
                            details['rotation_rate'] = line.split(':')[1].strip()
            
            # Informace o výkonu
            details.update(self.assess_performance(device_name))
            
        except Exception as e:
            logger.warning(f"Nelze získat SMART data pro {device_name}: {e}")
        
        return details
    
    def assess_performance(self, device_name: str) -> Dict:
        """Odhadne výkon zařízení"""
        performance = {
            'performance_tier': 'UNKNOWN',
            'recommended_use': [],
            'speed_estimate': 'UNKNOWN'
        }
        
        device_type = self.detect_device_type({'name': device_name, 'model': ''})
        
        if device_type == 'NVME':
            performance.update({
                'performance_tier': 'VERY_HIGH',
                'recommended_use': ['RECORDER_DATABASE', 'MEDIA_FILES', 'DOCKER_VOLUMES'],
                'speed_estimate': '2000-7000 MB/s',
                'durability': 'HIGH'
            })
        elif device_type == 'USB_SSD':
            performance.update({
                'performance_tier': 'HIGH',
                'recommended_use': ['SYSTEM_FILES', 'CONFIGURATION', 'HOME_ASSISTANT_CORE'],
                'speed_estimate': '400-600 MB/s',
                'durability': 'MEDIUM'
            })
        elif device_type == 'SD_CARD':
            performance.update({
                'performance_tier': 'LOW',
                'recommended_use': ['BACKUPS', 'LOGS', 'TEMP_FILES'],
                'speed_estimate': '50-100 MB/s',
                'durability': 'LOW',
                'warning': 'Omezený počet zápisů - vhodné pouze pro zálohy'
            })
        elif device_type == 'HDD':
            performance.update({
                'performance_tier': 'MEDIUM',
                'recommended_use': ['MEDIA_ARCHIVE', 'LONG_TERM_BACKUPS'],
                'speed_estimate': '80-160 MB/s',
                'durability': 'HIGH',
                'note': 'Pomalý přístup, vhodný pro data s nízkou frekvencí zápisu'
            })
        
        return performance
    
    def analyze_filesystem(self, mountpoint: str) -> Dict:
        """Analyzuje filesystem na mountpointu"""
        if not mountpoint:
            return {}
        
        try:
            result = subprocess.run(['df', '-h', mountpoint], capture_output=True, text=True)
            lines = result.stdout.strip().split('\n')
            
            if len(lines) > 1:
                data = lines[1].split()
                return {
                    'filesystem': data[0],
                    'size': data[1],
                    'used': data[2],
                    'available': data[3],
                    'use_percent': data[4],
                    'mountpoint': data[5]
                }
        except Exception as e:
            logger.error(f"Chyba při analýze filesystemu {mountpoint}: {e}")
        
        return {}
    
    def get_optimal_layout(self) -> Dict:
        """Vrátí optimální rozložení pro Home Assistant"""
        return {
            'SD_CARD': {
                'priority': 'LOW',
                'recommended_use': [
                    'Zálohy (backups)',
                    'Log soubory (logs)',
                    'Dočasné soubory (temp)',
                    'Archivované data'
                ],
                'avoid': [
                    'Databáze recorderu',
                    'Media soubory',
                    'Docker volumes'
                ],
                'notes': 'Omezená životnost - minimalizujte zápisy'
            },
            'USB_SSD': {
                'priority': 'HIGH',
                'recommended_use': [
                    'Home Assistant core system',
                    'Konfigurační soubory',
                    'Docker kontejnery',
                    'Základní databáze'
                ],
                'avoid': [
                    'Velké media soubory',
                    'Nahrávky kamer'
                ],
                'notes': 'Dobrý výkon pro systémové soubory'
            },
            'NVME': {
                'priority': 'VERY_HIGH',
                'recommended_use': [
                    'Recorder databáze',
                    'Media soubory (obrázky, videa)',
                    'Nahrávky kamer',
                    'Docker volumes (databáze, cache)',
                    'TTS cache'
                ],
                'avoid': [
                    'Zálohy (plýtvání prostorem)',
                    'Log soubory (zbytečné opotřebení)'
                ],
                'notes': 'Maximální výkon pro data s vysokou IO zátěží'
            },
            'HDD': {
                'priority': 'MEDIUM',
                'recommended_use': [
                    'Dlouhodobé zálohy',
                    'Media archiv',
                    'Záznamy kamer (long-term)'
                ],
                'avoid': [
                    'Databáze recorderu',
                    'Docker systémové soubory'
                ],
                'notes': 'Vhodný pro data s nízkou frekvencí přístupu'
            }
        }
    
    def generate_recommendations(self, devices: List[Dict]):
        """Generuje doporučení na základě analýzy"""
        logger.info("Generuji doporučení...")
        
        optimal_layout = self.get_optimal_layout()
        current_setup = self.analyze_current_setup(devices)
        
        # Doporučení pro každé zařízení
        for device in devices:
            dev_type = device['device_type']
            mountpoint = device.get('mountpoint')
            
            if dev_type in optimal_layout and mountpoint:
                recommendation = {
                    'device': device['name'],
                    'type': dev_type,
                    'mountpoint': mountpoint,
                    'current_usage': self.get_current_usage(mountpoint),
                    'recommended_usage': optimal_layout[dev_type]['recommended_use'],
                    'avoid_usage': optimal_layout[dev_type]['avoid'],
                    'notes': optimal_layout[dev_type]['notes']
                }
                
                self.recommendations.append(recommendation)
        
        # Celková doporučení
        self.generate_overall_recommendations(current_setup)
    
    def analyze_current_setup(self, devices: List[Dict]) -> Dict:
        """Analyzuje současné nastavení"""
        setup = {
            'total_devices': len(devices),
            'device_types': {},
            'mountpoints': {},
            'potential_issues': []
        }
        
        for device in devices:
            dev_type = device['device_type']
            setup['device_types'][dev_type] = setup['device_types'].get(dev_type, 0) + 1
            
            if device.get('mountpoint'):
                setup['mountpoints'][device['mountpoint']] = {
                    'device': device['name'],
                    'type': dev_type,
                    'size': device['size']
                }
        
        # Detekce potenciálních problémů
        if setup['device_types'].get('SD_CARD', 0) > 0:
            setup['potential_issues'].append(
                "SD karta detekována - zvažte použití pouze pro zálohy kvůli omezené životnosti"
            )
        
        if setup['device_types'].get('NVME', 0) == 0:
            setup['potential_issues'].append(
                "NVMe disk nebyl detekován - pro optimální výkon zvažte jeho pořízení"
            )
        
        return setup
    
    def get_current_usage(self, mountpoint: str) -> List[str]:
        """Získá současné využití mountpointu"""
        usage = []
        mount_path = Path(mountpoint)
        
        if mount_path.exists():
            # Analýza typů souborů
            try:
                for item in mount_path.iterdir():
                    if item.is_dir():
                        if item.name in ['backups', 'backup']:
                            usage.append('Zálohy')
                        elif item.name in ['media', 'www']:
                            usage.append('Media soubory')
                        elif item.name in ['config', 'configuration']:
                            usage.append('Konfigurace')
                        elif item.name in ['logs', 'log']:
                            usage.append('Logy')
            except PermissionError:
                usage.append('Nelze analyzovat - problém s oprávněními')
        
        return usage if usage else ['Neznámé využití']
    
    def generate_migration_plan(self):
        """Generuje plán migrace na optimální nastavení"""
        logger.info("Generuji plán migrace...")
        
        migration_steps = []
        
        # Krok 1: Příprava NVMe pro data
        migration_steps.append({
            'step': 1,
            'title': 'Příprava NVMe disku',
            'actions': [
                'Naformátujte NVMe disk na ext4: sudo mkfs.ext4 /dev/nvme0n1',
                'Vytvořte mount point: sudo mkdir -p /mnt/nvme',
                'Přidejte do /etc/fstab pro automatické připojování',
                'Vytvořte adresářovou strukturu: /mnt/nvme/{hass_data,media,recordings,backups}'
            ]
        })
        
        # Krok 2: Přesun recorder databáze
        migration_steps.append({
            'step': 2,
            'title': 'Přesun recorder databáze na NVMe',
            'actions': [
                'Zastavte Home Assistant: docker stop home-assistant',
                'Zálohujte současnou databázi',
                'Upravte configuration.yaml: použijte MySQL nebo přesuňte SQLite na NVMe',
                'Nastavte práva: sudo chown -R $USER:$USER /mnt/nvme/hass_data'
            ]
        })
        
        # Krok 3: Optimalizace SD karty
        migration_steps.append({
            'step': 3,
            'title': 'Optimalizace SD karty pro zálohy',
            'actions': [
                'Vytvořte strukturu: /mnt/sdcard/{backups/daily,backups/weekly,logs/archive}',
                'Nastavte automatické zálohování na SD kartu',
                'Přesuňte staré logy na SD kartu',
                'Nastavte cron pro pravidelné čištění'
            ]
        })
        
        return migration_steps
    
    def run_analysis(self):
        """Provede kompletní analýzu"""
        logger.info("🔍 Spouštím analýzu úložišť...")
        
        devices = self.get_storage_devices()
        self.generate_recommendations(devices)
        migration_plan = self.generate_migration_plan()
        
        results = {
            'timestamp': datetime.datetime.now().isoformat(),
            'devices': devices,
            'recommendations': self.recommendations,
            'optimal_layout': self.get_optimal_layout(),
            'migration_plan': migration_plan
        }
        
        return results
    
    def generate_report(self, results: Dict, output_file: str = None):
        """Vygeneruje podrobný report"""
        if not output_file:
            output_file = f"storage_analysis_report_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write("=" * 80 + "\n")
            f.write("HOME ASSISTANT - ANALÝZA ÚLOŽIŠŤ A DOPORUČENÍ\n")
            f.write("=" * 80 + "\n\n")
            
            # Přehled zařízení
            f.write("📊 PŘEHLED ÚLOŽNÝCH ZAŘÍZENÍ:\n")
            f.write("-" * 50 + "\n")
            for device in results['devices']:
                f.write(f"\n🔧 {device['name']} ({device['device_type']})\n")
                f.write(f"   Velikost: {device['size']}\n")
                f.write(f"   Filesystem: {device.get('filesystem', 'N/A')}\n")
                f.write(f"   Mountpoint: {device.get('mountpoint', 'Nepřipojeno')}\n")
                f.write(f"   Model: {device.get('model', 'Neznámý')}\n")
                f.write(f"   Odhad výkonu: {device.get('performance_tier', 'Neznámý')}\n")
            
            # Doporučení
            f.write("\n💡 DOPORUČENÍ PRO ROZDĚLENÍ:\n")
            f.write("-" * 50 + "\n")
            for rec in results['recommendations']:
                f.write(f"\n📍 {rec['device']} ({rec['type']}) - {rec['mountpoint']}\n")
                f.write(f"   Doporučené použití:\n")
                for use in rec['recommended_usage']:
                    f.write(f"   ✅ {use}\n")
                f.write(f"   Nevhodné použití:\n")
                for avoid in rec['avoid_usage']:
                    f.write(f"   ❌ {avoid}\n")
                f.write(f"   Poznámka: {rec['notes']}\n")
            
            # Plán migrace
            f.write("\n🔄 PLÁN MIGRACE NA OPTIMÁLNÍ NASTAVENÍ:\n")
            f.write("-" * 50 + "\n")
            for step in results['migration_plan']:
                f.write(f"\nKrok {step['step']}: {step['title']}\n")
                for action in step['actions']:
                    f.write(f"   • {action}\n")
            
            # Optimální layout
            f.write("\n🎯 OPTIMÁLNÍ ROZDĚLENÍ PODLE TYPU ZAŘÍZENÍ:\n")
            f.write("-" * 50 + "\n")
            for dev_type, layout in results['optimal_layout'].items():
                f.write(f"\n{dev_type}:\n")
                f.write(f"   Priorita: {layout['priority']}\n")
                f.write("   Doporučené použití:\n")
                for use in layout['recommended_use']:
                    f.write(f"   • {use}\n")
        
        logger.info(f"✅ Report uložen do: {output_file}")
        return output_file

def main():
    """Hlavní funkce"""
    print("🔍 Home Assistant Storage Analyzer")
    print("===================================")
    
    analyzer = StorageAnalyzer()
    results = analyzer.run_analysis()
    
    report_file = analyzer.generate_report(results)
    
    # Zobrazení souhrnu
    print(f"\n📊 SOUHRN ANALÝZY:")
    print(f"   Nalezeno zařízení: {len(results['devices'])}")
    
    device_types = {}
    for device in results['devices']:
        dev_type = device['device_type']
        device_types[dev_type] = device_types.get(dev_type, 0) + 1
    
    for dev_type, count in device_types.items():
        print(f"   {dev_type}: {count} zařízení")
    
    print(f"\n💡 DOPORUČENÍ:")
    for rec in results['recommendations']:
        print(f"   {rec['device']} -> {rec['mountpoint']}")
        print(f"      {rec['recommended_usage'][0]}")
    
    print(f"\n✅ Podrobný report: {report_file}")

if __name__ == "__main__":
    main()