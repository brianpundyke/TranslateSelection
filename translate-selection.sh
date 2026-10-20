#!/bin/bash
# Usage: translate-selection.sh [MODE]
#   (no mode)               translate the selection with DeepL (to English, or to Spanish if already English)
#   -i,  --improve          suggest better Spanish phrasing (Gemini, falling back to Anthropic)
#   -ic, --improve-claude   as --improve, but go direct to Anthropic
#   -cj, --conjugate        open the Reverso conjugation page for the selected Spanish verb
#   -s,  --spell            check Spanish spelling and accents with LanguageTool
#   -d,  --define           open the SpanishDict dictionary page for the selected word or phrase

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

# --- Helpers ---

notify() {
    notify-send -a "Translate" "$@"
}

# Show an error notification and exit
fail() {
    notify "$1" "$2"
    exit 1
}

# Escape text from stdin for notification markup
escape_markup() {
    sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

# ask_gemini PROMPT TEXT -- prints the reply, or nothing on failure
ask_gemini() {
    [ -n "$GEMINI_API_KEY" ] || return
    local body
    body=$(jq -n --arg p "$1" --arg t "$2" '{contents: [{parts: [{text: ($p + "\n\n" + $t)}]}]}')

    curl -s -X POST \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent" \
        -H "Content-Type: application/json" \
        -H "X-goog-api-key: $GEMINI_API_KEY" \
        -d "$body" \
        --max-time 20 \
        | jq -r '.candidates[0].content.parts[0].text // empty'
}

# ask_claude SYSTEM_PROMPT TEXT -- prints the reply, or nothing on failure
ask_claude() {
    [ -n "$ANTHROPIC_API_KEY" ] || return
    local body
    body=$(jq -n --arg s "$1" --arg t "$2" '{
        model: "claude-haiku-4-5-20251001",
        max_tokens: 300,
        system: $s,
        messages: [{role: "user", content: $t}]
    }')

    curl -s -X POST "https://api.anthropic.com/v1/messages" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "Content-Type: application/json" \
        -d "$body" \
        --max-time 20 \
        | jq -r '.content[0].text // empty'
}

# deepl TEXT [EXTRA CURL ARGS...] -- prints the raw JSON response
deepl() {
    local text=$1
    shift
    curl -s -X POST "https://api-free.deepl.com/v2/translate" \
        -H "Authorization: DeepL-Auth-Key $DEEPL_API_KEY" \
        --data-urlencode "text=$text" \
        "$@" \
        --max-time 20
}

# --- Modes ---

# improve SKIP_GEMINI -- suggest better Spanish phrasing
improve() {
    local skip_gemini=$1
    local prompt="You help an English speaker improve their written Spanish. Given a Spanish phrase, reply in exactly two lines. Line 1: ONLY the better or more natural way to say it (or the original unchanged, if it is already good). Line 2: a brief English explanation of what you changed and why, or a short note that it is already good. Keep the whole reply under 200 characters if possible. Do not include any preamble."
    local result="" provider=""

    if [ "$skip_gemini" = false ]; then
        result=$(ask_gemini "$prompt" "$TEXT")
        [ -n "$result" ] && provider="Gemini"
    fi

    if [ -z "$result" ]; then
        result=$(ask_claude "$prompt" "$TEXT")
        [ -n "$result" ] && provider="Claude"
    fi

    if [ -z "$result" ]; then
        if [ "$skip_gemini" = true ]; then
            fail "Improve failed" "Anthropic failed (check ANTHROPIC_API_KEY?)"
        fi
        fail "Improve failed" "Both Gemini and Anthropic failed (check API keys?)"
    fi

    # Copy just the improved Spanish (the first non-blank line)
    echo -n "$result" | sed -n '/[^[:space:]]/{p;q}' | tr -d '\n' | wl-copy

    notify "Improved ($provider)" "$(echo -n "$result" | escape_markup)" --urgency=critical
}

# conjugate -- open the Reverso conjugation page for the first word of the selection
conjugate() {
    local verb
    verb=$(echo "$TEXT" | awk 'NF { print $1; exit }')
    verb=${verb//[[:punct:]¿¡«»]/}
    verb=${verb,,}

    if [ -z "$verb" ]; then
        fail "Conjugate" "No verb selected"
    fi

    local url
    url="https://conjugator.reverso.net/conjugation-spanish-verb-$(jq -rn --arg v "$verb" '$v | @uri').html"
    # Not backgrounded: KDE runs shortcuts as systemd units, which kill leftover children on exit
    xdg-open "$url" >/dev/null 2>&1
}

# define -- open the SpanishDict dictionary page for the selected word or phrase
define() {
    local term
    term=${TEXT//[.,;:!?¿¡«»\"()]/}
    term=$(echo "$term" | awk '{ $1 = $1; printf "%s%s", sep, $0; sep = " " }')
    term=${term,,}

    if [ -z "$term" ]; then
        fail "Define" "No word selected"
    fi

    local url
    url="https://www.spanishdict.com/translate/$(jq -rn --arg t "$term" '$t | @uri')"
    # Not backgrounded: KDE runs shortcuts as systemd units, which kill leftover children on exit
    xdg-open "$url" >/dev/null 2>&1
}

# spell -- check Spanish spelling and accents with LanguageTool, copying the corrected text
spell() {
    local response
    response=$(curl -s -X POST "https://api.languagetool.org/v2/check" \
        --data-urlencode "text=$TEXT" \
        -d "language=es" \
        --max-time 20)

    if ! echo "$response" | jq -e '.matches' >/dev/null 2>&1; then
        fail "Spell check failed" "No response from LanguageTool (offline or rate-limited?)"
    fi

    local count
    count=$(echo "$response" | jq '.matches | length')

    if [ "$count" -eq 0 ]; then
        notify "✓ No errors found" "$(echo -n "$TEXT" | escape_markup)" --urgency=critical
        return
    fi

    # One line per problem: ✗ wrong → <b>fix</b> (or: alternatives)
    local problems
    problems=$(echo "$response" | jq -r --arg t "$TEXT" '
        def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
        .matches[]
        | "✗ \($t[.offset:.offset + .length] | esc) → "
          + (if (.replacements | length) > 0
             then "<b>\(.replacements[0].value | esc)</b>"
                  + (if (.replacements | length) > 1
                     then "  <i>(or: \([.replacements[1:3][].value | esc] | join(", ")))</i>"
                     else "" end)
             else "<i>\(.message | esc)</i>" end)')

    # Apply each top suggestion, working backwards so earlier offsets stay valid
    local corrected
    corrected=$(echo "$response" | jq -r --arg t "$TEXT" '
        reduce ([.matches[] | select((.replacements | length) > 0)] | sort_by(-.offset))[] as $m
            ($t; .[:$m.offset] + $m.replacements[0].value + .[$m.offset + $m.length:])')

    if [ "$corrected" != "$TEXT" ]; then
        echo -n "$corrected" | wl-copy
        problems+=$'\n\n'"<i>Corrected text copied to clipboard</i>"
    fi

    local plural="s"
    [ "$count" -eq 1 ] && plural=""
    notify "✗ $count error$plural found" "$problems" --urgency=critical
}

# translate -- DeepL to English, or to Spanish if the text is already English
translate() {
    if [ -z "$DEEPL_API_KEY" ]; then
        fail "Translate" "DEEPL_API_KEY not set (missing .env?)"
    fi

    # First call: auto-detect source, translate to English as a default guess
    local response detected translation error
    response=$(deepl "$TEXT" -d "target_lang=EN-GB")
    detected=$(echo "$response" | jq -r '.translations[0].detected_source_language // empty')

    # If the detected source was already English, re-translate to Spanish instead
    if [ "$detected" = "EN" ]; then
        response=$(deepl "$TEXT" -d "source_lang=EN" -d "target_lang=ES")
    fi

    translation=$(echo "$response" | jq -r '.translations[0].text // empty')

    if [ -z "$translation" ]; then
        error=$(echo "$response" | jq -r '.message // "no response / timed out"' 2>/dev/null)
        fail "Translation failed" "${error:-no response / timed out}"
    fi

    echo -n "$translation" | wl-copy
    notify "" "<b>$(echo -n "$translation" | escape_markup)</b>" --urgency=critical
}

# --- Main ---

TEXT=$(wl-paste --primary --no-newline)

if [ -z "$TEXT" ]; then
    fail "Translate" "No text selected"
fi

# Ignore stray whitespace (e.g. a newline pasted into a KDE shortcut command)
MODE=${1//[[:space:]]/}

case "$MODE" in
    "")                    translate ;;
    -i|--improve)          improve false ;;
    -ic|--improve-claude)  improve true ;;
    -cj|--conjugate)       conjugate ;;
    -s|--spell)            spell ;;
    -d|--define)           define ;;
    *)                     fail "Translate" "Unknown option: $(printf '%q' "$1")" ;;
esac
