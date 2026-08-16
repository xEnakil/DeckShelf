#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/dist}"
VERSION="${VERSION:-dev}"

for tool in go x86_64-w64-mingw32-gcc x86_64-w64-mingw32-g++ x86_64-w64-mingw32-windres; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'Missing build dependency: %s\n' "$tool" >&2
    exit 1
  }
done

mkdir -p "$OUT"
cd "$ROOT"

cleanup(){ rm -f "$ROOT/romshelf.syso"; }
trap cleanup EXIT

x86_64-w64-mingw32-windres -i romshelf.rc -o romshelf.syso

GOOS=windows \
GOARCH=amd64 \
CGO_ENABLED=1 \
CC=x86_64-w64-mingw32-gcc \
CXX=x86_64-w64-mingw32-g++ \
go build \
  -trimpath \
  -ldflags "-H windowsgui -s -w -X main.version=$VERSION" \
  -o "$OUT/ROM Shelf.exe" \
  .

printf 'Built %s\n' "$OUT/ROM Shelf.exe"
