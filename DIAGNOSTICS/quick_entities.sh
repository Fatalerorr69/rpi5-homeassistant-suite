#!/bin/bash

# Rychlý výpis všech entit a jejich stavů

echo "🔍 Rychlý výpis entit Home Assistant"
echo "===================================="

CONFIG_DIR="/config"
DB_PATH="$CONFIG_DIR/home-assistant_v2.db"
OUTPUT_FILE="$CONFIG_DIR/quick_entities_$(date +%Y%m%d_%H%M%S).txt"

if [ ! -f "$DB_PATH" ]; then
    echo "❌ Databáze Home Assistant nebyla nalezena!"
    exit 1
fi

echo "Generováno: $(date)" > "$OUTPUT_FILE"
echo "Databáze: $DB_PATH" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Počty entit podle domény
echo "📊 ENTITY PODLE TYPU:" >> "$OUTPUT_FILE"
echo "-------------------" >> "$OUTPUT_FILE"
sqlite3 "$DB_PATH" "SELECT substr(entity_id, 1, instr(entity_id, '.')-1) as domain, COUNT(*) FROM states WHERE last_updated > datetime('now', '-1 day') GROUP BY domain ORDER BY COUNT(*) DESC;" >> "$OUTPUT_FILE"

echo "" >> "$OUTPUT_FILE"
echo "📋 VŠECHNY AKTIVNÍ ENTITY A JEJICH STAVY:" >> "$OUTPUT_FILE"
echo "----------------------------------------" >> "$OUTPUT_FILE"

# Všechny entity a jejich poslední stav
sqlite3 "$DB_PATH" "SELECT entity_id, state FROM states WHERE last_updated IN (SELECT MAX(last_updated) FROM states GROUP BY entity_id) ORDER BY entity_id;" >> "$OUTPUT_FILE"

echo "✅ Rychlý výpis uložen do: $OUTPUT_FILE"

# Zobrazení souhrnu na obrazovku
echo ""
echo "📊 SOUHRN:"
sqlite3 "$DB_PATH" "SELECT COUNT(DISTINCT entity_id) as 'Celkem entit:' FROM states WHERE last_updated > datetime('now', '-1 day');"
echo ""
echo "🔝 Nejčastější entity:"
sqlite3 "$DB_PATH" "SELECT substr(entity_id, 1, instr(entity_id, '.')-1) as domain, COUNT(*) as count FROM states WHERE last_updated > datetime('now', '-1 day') GROUP BY domain ORDER BY count DESC LIMIT 5;"