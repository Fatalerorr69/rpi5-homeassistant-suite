#!/usr/bin/env python3
"""
Home Assistant Configuration YAML Validator
Handles custom Home Assistant tags (!include, !secret, etc.)
"""

import sys
import yaml
from pathlib import Path

class HomeAssistantYAMLLoader(yaml.SafeLoader):
    """Custom YAML loader that recognizes Home Assistant tags"""
    pass

# Register Home Assistant custom tags
def include_constructor(loader, node):
    """Handle !include tag"""
    return f"<{node.value}>"

def secret_constructor(loader, node):
    """Handle !secret tag"""
    return f"<secret: {node.value}>"

def include_dir_merge_named_constructor(loader, node):
    """Handle !include_dir_merge_named tag"""
    return f"<include_dir_merge_named: {node.value}>"

def include_dir_merge_list_constructor(loader, node):
    """Handle !include_dir_merge_list tag"""
    return f"<include_dir_merge_list: {node.value}>"

def include_dir_named_constructor(loader, node):
    """Handle !include_dir_named tag"""
    return f"<include_dir_named: {node.value}>"

def include_dir_list_constructor(loader, node):
    """Handle !include_dir_list tag"""
    return f"<include_dir_list: {node.value}>"

# Register constructors
HomeAssistantYAMLLoader.add_constructor('!include', include_constructor)
HomeAssistantYAMLLoader.add_constructor('!secret', secret_constructor)
HomeAssistantYAMLLoader.add_constructor('!include_dir_merge_named', include_dir_merge_named_constructor)
HomeAssistantYAMLLoader.add_constructor('!include_dir_merge_list', include_dir_merge_list_constructor)
HomeAssistantYAMLLoader.add_constructor('!include_dir_named', include_dir_named_constructor)
HomeAssistantYAMLLoader.add_constructor('!include_dir_list', include_dir_list_constructor)

def validate_yaml_file(filepath):
    """Validate a YAML file with Home Assistant custom tags support"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            yaml.load(f, Loader=HomeAssistantYAMLLoader)
        return True, None
    except yaml.YAMLError as e:
        return False, str(e)
    except Exception as e:
        return False, str(e)

def main():
    if len(sys.argv) < 2:
        print("Usage: validate_ha_config.py <yaml_file> [yaml_file2 ...]")
        sys.exit(1)
    
    all_valid = True
    
    for filepath in sys.argv[1:]:
        path = Path(filepath)
        if not path.exists():
            print(f"❌ Soubor neexistuje: {filepath}")
            all_valid = False
            continue
        
        is_valid, error = validate_yaml_file(filepath)
        
        if is_valid:
            print(f"✅ {path.name} - Validní YAML")
        else:
            print(f"❌ {path.name} - Chyba YAML:")
            print(f"   {error}")
            all_valid = False
    
    sys.exit(0 if all_valid else 1)

if __name__ == '__main__':
    main()
