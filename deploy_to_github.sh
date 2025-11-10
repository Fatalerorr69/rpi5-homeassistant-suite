#!/bin/bash
# Skript pro nasazení na GitHub

echo "🚀 Příprava repozitáře pro GitHub..."

# Inicializace Git
git init
git add .

# Commit zpráva s timestamp
COMMIT_MSG="🎉 Initial commit: RPi5 Home Assistant Suite $(date +%Y-%m-%d)"
git commit -m "$COMMIT_MSG"

# Vytvoření GitHub repozitáře (pokud neexistuje)
echo "📦 Vytvářím GitHub repozitář..."
gh repo create rpi5-homeassistant-suite --public --description "Complete Home Assistant suite for Raspberry Pi 5 with MHS35 display support" --push

echo "✅ Repozitář úspěšně nahrán na GitHub!"
