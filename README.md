# TranslateSelection

A small Wayland shell script that translates your current text selection using the [DeepL API](https://www.deepl.com/docs-api), copies the result to your clipboard, and shows it in a desktop notification.

## How it works

1. Reads the current primary selection (the text you have highlighted) via `wl-paste`.
2. Sends it to DeepL, translating to English (`EN-GB`) by default.
3. If DeepL detects the source text was already English, it re-translates to Spanish (`ES`) instead.
4. Copies the translation to the clipboard with `wl-copy`.
5. Shows the translation in a notification via `notify-send`.

Bind the script to a keyboard shortcut in your Wayland compositor to translate any selected text with one keypress.

## Requirements

- A Wayland session with `wl-clipboard` (`wl-paste` / `wl-copy`)
- `curl`
- `jq`
- `notify-send` (usually provided by `libnotify-bin`)
- A [DeepL API](https://www.deepl.com/pro-api) key (the free tier works)

## Setup

1. Clone this repo.
2. Create a `.env` file next to `translate-selection.sh` with your API key:

   ```
   DEEPL_API_KEY=your-deepl-api-key-here
   ```

   `.env` is gitignored, so your key stays local.

3. Make the script executable if it isn't already:

   ```
   chmod +x translate-selection.sh
   ```

4. Bind `translate-selection.sh` to a keyboard shortcut in your desktop environment or compositor config.

## Usage

Select some text, then run the script (or trigger your keybinding). The translation appears as a notification and is copied to your clipboard, ready to paste.
