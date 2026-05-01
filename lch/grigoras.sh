#!/bin/bash

# Script pentru configurarea limbii Flatpak în Română (ro)
echo "Se configurează limba pentru Flatpak..."

# 1. Setarea limbilor pentru Flatpak (Română și Engleză ca rezervă)
# Această comandă forțează Flatpak să descarce traducerile necesare (locales).
flatpak config --set languages "ro;en"

if [ $? -eq 0 ]; then
    echo "✅ Configurația Flatpak a fost modificată cu succes în limba Română."
else
    echo "❌ A apărut o eroare la configurarea limbii."
    exit 1
fi

# 2. Actualizarea Flatpak pentru a descărca pachetele de limbă
echo "Se descarcă fișierele de limbă română (dacă este necesar)..."
flatpak update -y

# 3. Informații finale pentru utilizator
echo "----------------------------------------------------"
echo "Gata! Repornește Chrome pentru a vedea modificările."
echo "Dacă Chrome este tot în altă limbă, verifică și setările interne:"
echo "Accesează în browser: chrome://settings/languages"
echo "----------------------------------------------------"
