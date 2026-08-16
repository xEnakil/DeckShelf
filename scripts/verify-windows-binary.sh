#!/usr/bin/env bash
set -euo pipefail

BINARY="${1:-dist/ROM Shelf.exe}"
[ -f "$BINARY" ] || { printf 'Binary not found: %s\n' "$BINARY" >&2; exit 1; }

command -v x86_64-w64-mingw32-objdump >/dev/null 2>&1 || {
  printf 'Missing build dependency: x86_64-w64-mingw32-objdump\n' >&2
  exit 1
}

mapfile -t imports < <(
  x86_64-w64-mingw32-objdump -p "$BINARY" \
    | awk '/DLL Name:/ { print tolower($3) }' \
    | sort -u
)

[ "${#imports[@]}" -gt 0 ] || { printf 'No PE imports found.\n' >&2; exit 1; }

for library in "${imports[@]}"; do
  case "$library" in
    advapi32.dll|kernel32.dll|msvcrt.dll|ole32.dll|shell32.dll|shlwapi.dll|user32.dll|version.dll) ;;
    *) printf 'Unexpected runtime dependency: %s\n' "$library" >&2; exit 1 ;;
  esac
done

size="$(wc -c < "$BINARY" | tr -d ' ')"
[ "$size" -lt 15728640 ] || { printf 'Binary is unexpectedly large: %s bytes\n' "$size" >&2; exit 1; }

printf 'Verified PE imports (%s bytes):\n' "$size"
printf '  %s\n' "${imports[@]}"

