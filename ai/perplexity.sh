#!/bin/bash
# Simpel Perplexity CLI-script voor Debian (geen Snap)
# Vereisten: python3, pip, requests
# API-key: maak gratis aan op https://www.perplexity.ai/settings/api

# Configuratie
API_KEY="YOUR_API_KEY_HERE"  # Vervang door je eigen key!
MODEL="sonar-small-online"   # Gratis model met search
BASE_URL="https://api.perplexity.ai/chat/completions"

# Functie voor query
query_perplexity() {
    local prompt="$1"
    if [ -z "$prompt" ]; then
        echo "Gebruik: $0 'je vraag hier'"
        exit 1
    fi

    # Python one-liner voor API-call
    python3 -c "
import sys, requests, json
prompt = '$prompt'
headers = {
    'Authorization': 'Bearer $API_KEY',
    'Content-Type': 'application/json'
}
data = {
    'model': '$MODEL',
    'messages': [{'role': 'user', 'content': prompt}]
}
response = requests.post('$BASE_URL', headers=headers, json=data)
if response.status_code == 200:
    result = response.json()['choices'][0]['message']['content']
    print(result)
else:
    print('Fout:', response.status_code, response.text)
" 2>/dev/null
}

# Hoofdprogramma
query_perplexity "$@"