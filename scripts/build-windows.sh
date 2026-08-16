#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/dist}"
VERSION="${VERSION:-dev}"

for tool in go patch x86_64-w64-mingw32-gcc x86_64-w64-mingw32-g++ x86_64-w64-mingw32-windres; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'Missing build dependency: %s\n' "$tool" >&2
    exit 1
  }
done

mkdir -p "$OUT"
cd "$ROOT"

CASE_INCLUDE="$(mktemp -d)"
MODULE_CACHE="$(mktemp -d)"
printf '#include <eventtoken.h>\n' > "$CASE_INCLUDE/EventToken.h"

cleanup(){
  rm -f "$ROOT/romshelf.syso"
  rm -rf "$CASE_INCLUDE"
  rm -rf "$MODULE_CACHE"
}
trap cleanup EXIT

WEBVIEW_DIR="$(GOMODCACHE="$MODULE_CACHE" go list -mod=mod -m -f '{{.Dir}}' github.com/webview/webview_go)"
chmod -R u+w "$WEBVIEW_DIR"
patch --directory "$WEBVIEW_DIR" --strip 1 --forward --silent \
  < "$ROOT/patches/webview-portable-cache.patch"

x86_64-w64-mingw32-windres -i romshelf.rc -o romshelf.syso

GOOS=windows \
GOARCH=amd64 \
CGO_ENABLED=1 \
CC=x86_64-w64-mingw32-gcc \
CXX=x86_64-w64-mingw32-g++ \
CGO_CXXFLAGS="-I$CASE_INCLUDE" \
GOMODCACHE="$MODULE_CACHE" \
go build \
  -trimpath \
  -ldflags "-H windowsgui -s -w -X main.version=$VERSION" \
  -o "$OUT/ROM Shelf.exe" \
  .

printf 'Built %s\n' "$OUT/ROM Shelf.exe"
