#!/bin/bash

# Configuratie
API_KEY="JOUW_API_SLEUTEL"
PROMPT="$*"

if [ -z "$PROMPT" ]; then
    echo "Gebruik: ./gemini.sh <jouw vraag>"
    exit 1
fi

# We gebruiken de Ansible 'uri' module via een ad-hoc commando
# Dit zorgt ervoor dat de aanroep volgens jouw voorkeur via Ansible verloopt.
ansible localhost -m uri -a "
  url=https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$API_KEY
  method=POST
  body_format=json
  return_content=yes
  body='{\"contents\": [{\"parts\": [{\"text\": \"$PROMPT\"}]}]}'
" --quiet | grep -oP '"text": "\K[^"]+' | sed 's/\\n/\n/g'
