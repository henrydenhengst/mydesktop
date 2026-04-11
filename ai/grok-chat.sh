#!/bin/bash

# =============================================
# Eenvoudige Grok chat vanuit de terminal
# Gebruik: ./grok-chat.sh
# =============================================

# Controleer of de API-key is ingesteld
if [ -z "$XAI_API_KEY" ]; then
    echo "❌ Fout: Stel eerst je xAI API-key in:"
    echo "   export XAI_API_KEY='xai-je-sleutel-hier'"
    echo "   (of voeg dit toe aan je \~/.bashrc)"
    exit 1
fi

echo "🤖 Grok chat gestart (typ 'exit' of 'quit' om te stoppen)"
echo "-----------------------------------------------------"

# Geschiedenis van het gesprek (blijft in geheugen tijdens deze sessie)
MESSAGES='[{"role": "system", "content": "Je bent Grok, een behulpzame en waarheidsgetrouwe AI gebouwd door xAI."}]'

while true; do
    # Vraag om input
    echo -n "👤 Jij: "
    read -r user_input

    # Stoppen als gebruiker exit typt
    if [[ "$user_input" == "exit" || "$user_input" == "quit" || "$user_input" == "q" ]]; then
        echo "👋 Grok chat beëindigd."
        break
    fi

    # Voeg gebruiker input toe aan de geschiedenis
    MESSAGES=$(echo "$MESSAGES" | jq --arg content "$user_input" '. += [{"role": "user", "content": $content}]')

    # Roep de Grok API aan
    RESPONSE=$(curl -s https://api.x.ai/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $XAI_API_KEY" \
        -d '{
            "model": "grok-4",           # of grok-3-latest / grok-4.20-reasoning etc.
            "messages": '"$MESSAGES"',
            "temperature": 0.7,
            "max_tokens": 2048,
            "stream": false
        }')

    # Haal het antwoord eruit (met jq)
    if command -v jq >/dev/null 2>&1; then
        ANSWER=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // "❌ Fout bij het ophalen van antwoord"')
        echo -e "🤖 Grok: $ANSWER\n"
        
        # Voeg het antwoord toe aan de geschiedenis
        MESSAGES=$(echo "$MESSAGES" | jq --arg content "$ANSWER" '. += [{"role": "assistant", "content": $content}]')
    else
        echo "❌ jq is niet geïnstalleerd. Installeer met: sudo apt install jq"
        echo "Raw response:"
        echo "$RESPONSE"
        break
    fi
done