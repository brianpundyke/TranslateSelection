#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

if [ -z "$DEEPL_API_KEY" ]; then
    notify-send "Translate" "DEEPL_API_KEY not set (missing .env?)"
    exit 1
fi

TEXT=$(wl-paste --primary --no-newline)

if [ -z "$TEXT" ]; then
    notify-send "Translate" "No text selected"
    exit 1
fi

# First call: auto-detect source, translate to English as a default guess
RESPONSE=$(curl -s -X POST "https://api-free.deepl.com/v2/translate" \
    -H "Authorization: DeepL-Auth-Key $DEEPL_API_KEY" \
    -d "text=$TEXT" \
    -d "target_lang=EN-GB" \
    --max-time 20)

DETECTED=$(echo "$RESPONSE" | jq -r '.translations[0].detected_source_language // empty')

# If the detected source was already English, re-translate to Spanish instead
if [ "$DETECTED" = "EN" ]; then
    RESPONSE=$(curl -s -X POST "https://api-free.deepl.com/v2/translate" \
        -H "Authorization: DeepL-Auth-Key $DEEPL_API_KEY" \
        -d "text=$TEXT" \
        -d "source_lang=EN" \
        -d "target_lang=ES" \
        --max-time 20)
fi

TRANSLATION=$(echo "$RESPONSE" | jq -r '.translations[0].text // empty')

if [ -z "$TRANSLATION" ]; then
    ERROR=$(echo "$RESPONSE" | jq -r '.message // "no response / timed out"')
    notify-send "Translation failed" "$ERROR"
    exit 1
fi

echo -n "$TRANSLATION" | wl-copy
notify-send "Translation" "$TRANSLATION" --expire-time=8000
