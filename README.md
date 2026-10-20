# TranslateSelection

A small Wayland shell script that works on your current text selection. It can translate it using the [DeepL API](https://www.deepl.com/docs-api), suggest better Spanish phrasing using Gemini or Claude, check Spanish spelling and accents using [LanguageTool](https://languagetool.org/), open the conjugation page for a Spanish verb on [Reverso Conjugator](https://conjugator.reverso.net/), or look up a word's meaning on [SpanishDict](https://www.spanishdict.com/).

## How it works

### Translate (default)

1. Reads the current primary selection (the text you have highlighted) via `wl-paste`.
2. Sends it to DeepL, translating to English (`EN-GB`) by default.
3. If DeepL detects the source text was already English, it re-translates to Spanish (`ES`) instead.
4. Copies the translation to the clipboard with `wl-copy`.
5. Shows the translation in a notification via `notify-send`.

### Improve (`-i` / `--improve`, `-ic` / `--improve-claude`)

1. Sends the selected Spanish to Gemini (falling back to Anthropic's Claude if Gemini fails). `-ic` goes straight to Claude.
2. Copies the improved Spanish to the clipboard.
3. Shows the improved text, plus a short English explanation of what changed, in a notification.

### Conjugate (`-cj` / `--conjugate`)

Takes the first word of the selection and opens its Reverso Conjugator page in your browser, which shows every tense and mood. A conjugated form (e.g. *tengo*) is usually enough; Reverso works out the infinitive.

### Define (`-d` / `--define`)

Opens the SpanishDict dictionary page for the selection in your browser. It works in either direction (Spanish or English) and takes the whole selection, so set phrases such as *echar de menos* can be looked up too. Punctuation is stripped and the text is lowercased first.

### Spell check (`-s` / `--spell`)

1. Sends the selected Spanish to the free LanguageTool API (no key needed).
2. Shows a notification titled either "✓ No errors found" or "✗ N errors found". Each error is listed as `✗ wrong → correct`, with any alternative suggestions after it (e.g. ✗ arbol → **árbol** *(or: arbola, arbole)*).
3. If anything was corrected, copies the selection with the top suggestions applied to the clipboard.

Words that are correct either way, such as *esta/está*, *se/sé* and *tu/tú*, can only be judged in context, so select the surrounding phrase rather than the bare word.

Bind each mode to its own keyboard shortcut in your desktop environment or Wayland compositor, so any selected text is one keypress away.

## Requirements

- A Wayland session with `wl-clipboard` (`wl-paste` / `wl-copy`)
- `curl`
- `jq`
- `notify-send` (provided by `libnotify-bin` on Debian/Ubuntu, `libnotify` on Fedora)
- `xdg-open` (provided by `xdg-utils`), for conjugate and define modes

On Fedora: `sudo dnf install wl-clipboard curl jq libnotify xdg-utils`. On Debian/Ubuntu: `sudo apt install wl-clipboard curl jq libnotify-bin xdg-utils`.
- A [DeepL API](https://www.deepl.com/pro-api) key (the free tier works), for translate mode
- A [Gemini API](https://aistudio.google.com/apikey) key and/or an [Anthropic API](https://console.anthropic.com/) key, for improve mode

## Setup

1. Clone this repo.
2. Create a `.env` file next to `translate-selection.sh` with your API keys (only the ones for the modes you use are needed):

   ```
   DEEPL_API_KEY=your-deepl-api-key-here
   GEMINI_API_KEY=your-gemini-api-key-here
   ANTHROPIC_API_KEY=your-anthropic-api-key-here
   ```

   `.env` is gitignored, so your keys stay local.

3. Make the script executable if it isn't already:

   ```
   chmod +x translate-selection.sh
   ```

4. Bind `translate-selection.sh` (and, if you want them, `translate-selection.sh -i`, `translate-selection.sh -cj`, `translate-selection.sh -d` and `translate-selection.sh -s`) to keyboard shortcuts in your desktop environment or compositor config.

## Usage

Select some text, then run the script (or trigger your keybinding). In translate mode, the translation appears as a notification (shown at critical urgency, so it stays on screen until dismissed, with the text bolded and no title) and is copied to your clipboard, ready to paste.

## Privacy

Translate, improve and spell-check modes send the selected text to DeepL, Google (Gemini), Anthropic or LanguageTool. Conjugate and define modes only put the selected text into a Reverso or SpanishDict URL that opens in your browser. Avoid running the script on text you wouldn't want to leave your machine.
