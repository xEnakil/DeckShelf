#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:?Usage: package-release.sh VERSION [OUTPUT_DIR]}"
OUT="${2:-$ROOT/dist}"
BINARY="$OUT/ROM Shelf.exe"

for tool in zip sha256sum; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'Missing packaging dependency: %s\n' "$tool" >&2
    exit 1
  }
done
[ -f "$BINARY" ] || { printf 'Build the Windows executable first: %s\n' "$BINARY" >&2; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
BUNDLE="$STAGE/ROM Shelf $VERSION"
ARCHIVE="ROM-Shelf-$VERSION-windows-x64.zip"

mkdir -p "$BUNDLE/assets"
cp "$BINARY" "$BUNDLE/ROM Shelf.exe"
cp "$ROOT/generate-library.sh" "$BUNDLE/generate-library.sh"
cp "$ROOT/library-template.html" "$BUNDLE/library-template.html"
cp "$ROOT/README.md" "$BUNDLE/README.md"
cp "$ROOT/LICENSE" "$BUNDLE/LICENSE"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$BUNDLE/THIRD_PARTY_NOTICES.md"
cp "$ROOT/examples/library.sample.json" "$BUNDLE/library.sample.json"
cp "$ROOT/assets/icon.svg" "$ROOT/assets/romshelf.png" "$ROOT/assets/romshelf.ico" "$BUNDLE/assets/"

rm -f "$OUT/$ARCHIVE" "$OUT/SHA256SUMS.txt"
(
  cd "$STAGE"
  zip -qr "$OUT/$ARCHIVE" "$(basename "$BUNDLE")"
)
(
  cd "$OUT"
  sha256sum "ROM Shelf.exe" "$ARCHIVE" > SHA256SUMS.txt
)

printf 'Packaged %s\n' "$OUT/$ARCHIVE"
printf 'Checksums: %s\n' "$OUT/SHA256SUMS.txt"
