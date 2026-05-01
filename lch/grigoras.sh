#!/bin/bash

# Script om Flatpak taal naar Roemeens (ro) te zetten
echo "Bezig met het configureren van Flatpak talen..."

# 1. Stel de talen in voor Flatpak (Roemeens en Engels als backup)
# Dit zorgt ervoor dat Flatpak de juiste runtime-vertalingen downloadt.
flatpak config --set languages "ro;en"

if [ $? -eq 0 ]; then
    echo "✅ Flatpak taalinstelling gewijzigd naar Roemeens."
else
    echo "❌ Er ging iets mis bij het instellen van de taal."
    exit 1
fi

# 2. Update Flatpak om de nieuwe taalpakketten binnen te halen
echo "Bezig met het downloaden van de Roemeense taalbestanden (indien nodig)..."
flatpak update -y

# 3. Informatie voor de gebruiker
echo "----------------------------------------------------"
echo "Klaar! Herstart Chrome om de wijzigingen te zien."
echo "Mocht Chrome nog steeds in het Nederlands openen,"
echo "controleer dan de instellingen binnen Chrome zelf via:"
echo "chrome://settings/languages"
echo "----------------------------------------------------"
