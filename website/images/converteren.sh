#!/bin/bash

# Check of cwebp is geïnstalleerd
if ! command -v cwebp &> /dev/null
then
    echo "Fout: cwebp is niet geïnstalleerd. Gebruik 'sudo apt install webp' om het te installeren."
    exit
fi

echo "Starten met converteren van PNG naar WebP..."
echo "----------------------------------------"

# Loop door alle png bestanden
for file in *.png; do
    # Controleer of er wel png-bestanden zijn
    [ -e "$file" ] || continue
    
    # Bestandsnaam zonder extensie bepalen
    filename="${file%.*}"
    
    # Converteren naar webp (kwaliteit 80)
    cwebp -q 80 "$file" -o "${filename}.webp" -quiet
    
    # Grootte vergelijken voor de log
    old_size=$(du -h "$file" | cut -f1)
    new_size=$(du -h "${filename}.webp" | cut -f1)
    
    echo "✅ Geconverteerd: $file ($old_size) -> ${filename}.webp ($new_size)"
done

echo "----------------------------------------"
echo "Klaar! Vergeet niet je Markdown-links aan te passen naar .webp"
