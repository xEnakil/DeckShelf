#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATOR="$ROOT/generate-library.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail(){ printf 'FAIL: %s\n' "$*" >&2; exit 1; }

command -v node >/dev/null 2>&1 || fail "node is required to run the test assertions"
bash -n "$GENERATOR"

ROMS="$TMP/roms"
mkdir -p \
  "$ROMS/snes" \
  "$ROMS/psx" \
  "$ROMS/ps3/Game Folder" \
  "$ROMS/desktop" \
  "$ROMS/media"

printf 'rom' > "$ROMS/snes/Example <Quest>.sfc"
printf 'save' > "$ROMS/snes/Example.srm"
printf 'cue' > "$ROMS/psx/Example Disc.cue"
printf 'bin data' > "$ROMS/psx/Example Disc.bin"
printf 'payload' > "$ROMS/ps3/Game Folder/game.iso"
printf 'shortcut' > "$ROMS/desktop/cloud"
printf 'loose' > "$ROMS/loose-game.rom"
: > "$ROMS/snes/empty.sfc"

JSON_OUT="$TMP/json/library.json"
mkdir -p "$(dirname "$JSON_OUT")"
"$GENERATOR" --roms "$ROMS" --out "$TMP/json/Shelf.html" --json-only >/dev/null

node - "$JSON_OUT" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
const raw = fs.readFileSync(path, 'utf8');
const library = JSON.parse(raw);
const names = library.games.map(game => `${game[0]}/${game[1]}`).sort();
const expected = [
  'ps3/Game Folder',
  'psx/Example Disc.cue',
  'snes/Example <Quest>.sfc',
];
if (JSON.stringify(names) !== JSON.stringify(expected)) {
  throw new Error(`unexpected games: ${JSON.stringify(names)}`);
}
if (!raw.includes('\\u003cQuest\\u003e')) {
  throw new Error('HTML-sensitive filename characters were not escaped');
}
NODE

OUT="$TMP/full"
mkdir -p "$OUT"
"$GENERATOR" --roms "$ROMS" --out "$OUT/Deck Vault.html" --name "Deck Vault" >/dev/null

[ -f "$OUT/Deck Vault.html" ] || fail "HTML output is missing"
[ -f "$OUT/Deck Vault.desktop" ] || fail "Linux launcher is missing"
[ -f "$OUT/Launch Deck Vault.bat" ] || fail "Windows launcher is missing"
[ -f "$OUT/Deck Vault.command" ] || fail "macOS launcher is missing"
[ -f "$OUT/open-shelf.sh" ] || fail "Linux opener is missing"
[ -f "$OUT/icon.svg" ] || fail "SVG icon is missing"
[ -f "$OUT/romshelf.png" ] || fail "PNG icon is missing"
[ -f "$OUT/romshelf.ico" ] || fail "Windows icon is missing"
bash -n "$OUT/open-shelf.sh"
grep -Fq 'const APP_NAME = "Deck Vault"' "$OUT/Deck Vault.html" || fail "custom app name was not injected"
! grep -Fq '__GAME_DATA_PLACEHOLDER__' "$OUT/Deck Vault.html" || fail "game-data placeholder remains"
! grep -Fq 'fonts.googleapis.com' "$OUT/Deck Vault.html" || fail "generated app still makes a font-network request"
node - "$OUT/Deck Vault.html" <<'NODE'
const fs = require('fs');
const html = fs.readFileSync(process.argv[2], 'utf8');
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(match => match[1]);
if (scripts.length !== 1) throw new Error(`expected one app script, found ${scripts.length}`);
new Function(scripts[0]);
NODE

printf 'snes\n' > "$TMP/systems.txt"
mkdir -p "$TMP/filtered"
"$GENERATOR" --roms "$ROMS" --out "$TMP/filtered/Shelf.html" --systems "$TMP/systems.txt" --json-only >/dev/null
node - "$TMP/filtered/library.json" <<'NODE'
const fs = require('fs');
const library = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (library.games.length !== 1 || library.games[0][0] !== 'snes') {
  throw new Error('system filtering returned the wrong games');
}
NODE

if "$GENERATOR" --roms >"$TMP/missing-value.log" 2>&1; then
  fail "an option without a value unexpectedly succeeded"
fi
grep -Fq 'Option --roms needs a value.' "$TMP/missing-value.log" || fail "missing-value error was not useful"

if "$GENERATOR" --roms "$ROMS" --name 'Bad/Name' >"$TMP/unsafe-name.log" 2>&1; then
  fail "an unsafe app name unexpectedly succeeded"
fi
grep -Fq 'Name may contain only' "$TMP/unsafe-name.log" || fail "unsafe-name error was not useful"

printf 'Generator tests passed.\n'
