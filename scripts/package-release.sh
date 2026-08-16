#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:?Usage: package-release.sh VERSION PLATFORM ARCH [OUTPUT_DIR]}"
PLATFORM="${2:?Usage: package-release.sh VERSION PLATFORM ARCH [OUTPUT_DIR]}"
ARCH="${3:?Usage: package-release.sh VERSION PLATFORM ARCH [OUTPUT_DIR]}"
OUT="${4:-$ROOT/dist}"

case "$PLATFORM" in
  windows)
    SOURCE="$ROOT/target/release/deck-shelf.exe"
    APP_FILE="Deck Shelf.exe"
    STANDALONE="Deck-Shelf-$VERSION-windows-$ARCH.exe"
    ;;
  macos)
    SOURCE="$ROOT/target/release/deck-shelf"
    APP_FILE="Deck Shelf"
    STANDALONE="Deck-Shelf-$VERSION-macos-$ARCH"
    ;;
  linux)
    SOURCE="$ROOT/target/release/deck-shelf"
    APP_FILE="deck-shelf"
    STANDALONE="Deck-Shelf-$VERSION-linux-$ARCH"
    ;;
  *)
    printf 'Unsupported platform: %s\n' "$PLATFORM" >&2
    exit 1
    ;;
esac

[ -f "$SOURCE" ] || { printf 'Release binary not found: %s\n' "$SOURCE" >&2; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
BUNDLE="$STAGE/Deck Shelf $VERSION"
ARCHIVE="Deck-Shelf-$VERSION-$PLATFORM-$ARCH.zip"

mkdir -p "$OUT" "$BUNDLE/assets"
cp "$SOURCE" "$BUNDLE/$APP_FILE"
cp "$SOURCE" "$OUT/$STANDALONE"
cp "$ROOT/generate-library.sh" "$ROOT/library-template.html" "$BUNDLE/"
cp "$ROOT/README.md" "$ROOT/LICENSE" "$ROOT/THIRD_PARTY_NOTICES.txt" "$BUNDLE/"
cp "$ROOT/examples/library.sample.json" "$BUNDLE/library.sample.json"
cp "$ROOT/assets/icon.svg" "$ROOT/assets/deck-shelf.png" "$ROOT/assets/deck-shelf.ico" "$BUNDLE/assets/"

if [ "$PLATFORM" != "windows" ]; then
  chmod +x "$BUNDLE/$APP_FILE" "$OUT/$STANDALONE"
fi

rm -f "$OUT/$ARCHIVE"
if command -v zip >/dev/null 2>&1; then
  (
    cd "$STAGE"
    zip -qr "$OUT/$ARCHIVE" "$(basename "$BUNDLE")"
  )
elif command -v 7z >/dev/null 2>&1; then
  (
    cd "$STAGE"
    7z a -bd -tzip "$OUT/$ARCHIVE" "$(basename "$BUNDLE")" >/dev/null
  )
elif command -v python3 >/dev/null 2>&1; then
  (
    cd "$STAGE"
    python3 -m zipfile -c "$OUT/$ARCHIVE" "$(basename "$BUNDLE")"
  )
else
  printf 'Packaging needs zip, 7z, or Python 3.\n' >&2
  exit 1
fi

printf 'Packaged %s and %s\n' "$OUT/$ARCHIVE" "$OUT/$STANDALONE"
