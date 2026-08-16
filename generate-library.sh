#!/usr/bin/env bash
# =============================================================================
#  ROM Shelf — library generator
#  Scans your ROM folders and writes a single self-contained HTML file you can
#  copy to any computer and open offline.
#
#  Usage:
#     ./generate-library.sh                      scan the auto-detected roms dir
#     ./generate-library.sh -r /path/to/roms     scan a specific folder
#     ./generate-library.sh -o ~/Desktop/x.html  choose where the HTML lands
#     ./generate-library.sh -s systems.txt       only scan the systems listed
#     ./generate-library.sh --json-only          write library.json, skip the HTML
#     ./generate-library.sh -n "Deck Vault"       rename the app and the file
#     ./generate-library.sh --all                keep every file, no filtering
#     ./generate-library.sh --no-launchers       skip the desktop shortcuts
#
#  Needs: bash, find, awk, du. Nothing else.
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/library-template.html"
OUT=""
ROOT=""
SYSFILE=""
NAME="ROM Shelf"
JSON_ONLY=0
KEEP_ALL=0
LAUNCHERS=1
JUNK_EXTRA=""

die(){ printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }
say(){ printf '%s\n' "$*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    -r|--roms)      ROOT="${2:-}"; shift 2 ;;
    -o|--out)       OUT="${2:-}"; shift 2 ;;
    -t|--template)  TEMPLATE="${2:-}"; shift 2 ;;
    -s|--systems)   SYSFILE="${2:-}"; shift 2 ;;
    -n|--name)      NAME="${2:-}"; shift 2 ;;
    --no-launchers) LAUNCHERS=0; shift ;;
    -x|--exclude)   JUNK_EXTRA="$JUNK_EXTRA ${2:-}"; shift 2 ;;
    --json-only)    JSON_ONLY=1; shift ;;
    --all)          KEEP_ALL=1; shift ;;
    -h|--help)      sed -n '2,20p' "$0"; exit 0 ;;
    *)              die "Unknown option: $1  (try --help)" ;;
  esac
done

# ---------------------------------------------------------------- find the roms
if [ -z "$ROOT" ]; then
  for c in \
    "$HOME/Emulation/roms" \
    "$HOME/retrodeck/roms" \
    "$HOME/.var/app/net.retrodeck.retrodeck/retrodeck/roms" \
    "$HOME/ROMs" \
    "$HOME/roms" \
    /run/media/deck/*/Emulation/roms \
    /run/media/*/Emulation/roms \
    /run/media/mmcblk0p1/Emulation/roms
  do
    [ -d "$c" ] && { ROOT="$c"; break; }
  done
fi
[ -n "$ROOT" ] || die "Could not find a roms folder. Point me at one:  $0 -r /path/to/roms"
[ -d "$ROOT" ] || die "Not a folder: $ROOT"
ROOT="$(cd "$ROOT" && pwd)"
[ -n "$NAME" ] || NAME="ROM Shelf"
[ -n "$OUT" ] || OUT="$SCRIPT_DIR/$NAME.html"
mkdir -p "$(dirname "$OUT")" || die "Cannot write to $(dirname "$OUT")"
JSON_OUT="$(dirname "$OUT")/library.json"

say "Scanning: $ROOT"

# Folders where one game = one directory rather than one file
FOLDER_SYSTEMS="ps3 wiiu dos pc ports scummvm mugen openbor daphne steam epic lutris cloud moonlight remoteplay emulators kodi primehacks"

# Not games, never scanned.
SKIP_SYSTEMS="desktop generic-applications"

# Directories that never hold games
SKIP_DIRS="media images videos manuals marquees screenshots covers boxart wheels bios BIOS downloaded_media downloaded_images .git .cache themes gamelists
           cfg CFG emulator EMULATOR nvdata NVDATA pfx scripts saves savestates states cache logs tools artwork snap"

# Files that sit in a system folder without being a game. EmuDeck and RetroDECK
# drop systeminfo.txt and metadata.txt into every single folder, which is what
# makes empty systems look full.
JUNK_NAMES="systeminfo.txt metadata.txt gamelist.xml gamelist.txt desktop.ini thumbs.db .ds_store readme.txt readme.md notes.txt info.txt license.txt roms saves screenshots"

# Extensions that are never a game
SKIP_EXT="txt xml jpg jpeg png gif bmp webp mp4 mkv avi mp3 ogg wav pdf nfo dat ini cfg conf sav srm state rtc bak log db json md html htm css sfv md5 sha1 crc par2 ips bps ups xdelta url lnk desktop_bak part tmp dll msi cab ttf otf so dylib sys drv toml yml yaml patch diff"

JUNK_NAMES="$JUNK_NAMES $JUNK_EXTRA"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
RAW="$TMP/raw.tsv"
: > "$RAW"

# ------------------------------------------------------------- pass 1: files
prune=()
for d in $SKIP_DIRS; do prune+=( -iname "$d" -o ); done
for s in $SKIP_SYSTEMS; do [ -d "$ROOT/$s" ] && prune+=( -path "$ROOT/$s" -o ); done
for s in $FOLDER_SYSTEMS; do [ -d "$ROOT/$s" ] && prune+=( -path "$ROOT/$s" -o ); done
unset 'prune[${#prune[@]}-1]'   # drop trailing -o

find "$ROOT" -mindepth 1 -maxdepth 5 \
  \( -type d \( "${prune[@]}" \) -prune \) -o \
  -type f -printf '%P\t%s\t%T@\n' 2>/dev/null \
| awk -F'\t' -v skipext="$SKIP_EXT" -v junk="$JUNK_NAMES" -v keepall="$KEEP_ALL" '
  BEGIN{
    n=0
    split(skipext,a," "); for(i in a) bad[a[i]]=1
    split(junk,b," ");    for(i in b) junkname[tolower(b[i])]=1
  }
  {
    path=$1; size=$2; mt=$3
    if (path !~ /\//) next                      # loose file at the root
    m=split(path,p,"/")
    sys=p[1]; file=p[m]
    if (sys ~ /^\./ || file ~ /^\./) next
    ext=""
    if (match(file,/\.[A-Za-z0-9]{1,6}$/)) ext=tolower(substr(file,RSTART+1))
    if (!keepall && ext in bad) next
    if (!keepall && tolower(file) in junkname) next
    if (!keepall && tolower(file) ~ /\.patch(\.[a-z0-9]+)?$/) next
    if (!keepall && size+0 == 0) next
    dir=substr(path,1,length(path)-length(file))
    if (ext=="cue"||ext=="gdi"||ext=="m3u"||ext=="ccd") hascue[dir]=1
    n++
    S[n]=sys; F[n]=file; Z[n]=size; T[n]=int(mt); D[n]=dir; E[n]=ext
  }
  END{
    for(i=1;i<=n;i++){
      if (!keepall && hascue[D[i]] && (E[i]=="bin"||E[i]=="raw"||E[i]=="sub"||E[i]=="img"||E[i]=="ecm"||E[i]=="toc")) continue
      printf "%s\t%s\t%s\t%s\n", S[i], F[i], Z[i], T[i]
    }
  }' >> "$RAW"

# --------------------------------------------------- pass 2: folder-per-game
for s in $FOLDER_SYSTEMS; do
  [ -d "$ROOT/$s" ] || continue
  case " $SKIP_SYSTEMS " in *" $s "*) continue ;; esac
  while IFS= read -r -d '' entry; do
    name="$(basename "$entry")"
    case "$name" in .*) continue ;; esac

    if [ "$KEEP_ALL" -eq 0 ]; then
      lname="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
      # the same junk that clutters the file-based systems
      skip=0
      for j in $JUNK_NAMES $SKIP_DIRS; do
        [ "$lname" = "$(printf '%s' "$j" | tr '[:upper:]' '[:lower:]')" ] && { skip=1; break; }
      done
      [ "$skip" -eq 1 ] && continue
      case "$lname" in *.patch|*.patch.*) continue ;; esac
      # and the same extension rules, which pass 2 used to ignore entirely
      if [ -f "$entry" ]; then
        case "$lname" in
          *.*) lext="${lname##*.}" ;;
          *)   lext="" ;;
        esac
        for e in $SKIP_EXT; do
          [ "$lext" = "$e" ] && { skip=1; break; }
        done
        [ "$skip" -eq 1 ] && continue
      fi
    fi

    if [ -d "$entry" ]; then
      sz="$(du -sb "$entry" 2>/dev/null | cut -f1)"
      [ -n "$sz" ] || sz=$(( $(du -sk "$entry" 2>/dev/null | cut -f1) * 1024 ))
    else
      sz="$(stat -c%s "$entry" 2>/dev/null || echo 0)"
    fi
    mt="$(stat -c%Y "$entry" 2>/dev/null || echo 0)"
    [ "$KEEP_ALL" -eq 0 ] && [ "${sz:-0}" -eq 0 ] && continue
    printf '%s\t%s\t%s\t%s\n' "$s" "$name" "${sz:-0}" "${mt:-0}" >> "$RAW"
  done < <(find "$ROOT/$s" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
done

# ------------------------------------------------------- optional system list
if [ -n "$SYSFILE" ]; then
  [ -f "$SYSFILE" ] || die "No such systems file: $SYSFILE"
  awk -F'\t' 'NR==FNR{ gsub(/[ \t\r]/,"",$0); if($0!="") want[$0]=1; next } ($1 in want)' \
    "$SYSFILE" "$RAW" > "$TMP/filtered.tsv" && mv "$TMP/filtered.tsv" "$RAW"
fi

COUNT=$(wc -l < "$RAW" | tr -d ' ')
[ "$COUNT" -gt 0 ] || die "Found no games under $ROOT — is that the right folder?"

say ""
say "What was found:"
cut -f1 "$RAW" | sort | uniq -c | sort -rn | awk '{ printf "  %-24s %s\n", $2, $1 }'
say ""

# ------------------------------------------------------------------ to JSON
sort -t$'\t' -k1,1 -k2,2 "$RAW" > "$TMP/sorted.tsv"
awk -F'\t' -v root="$ROOT" -v ts="$(date +%s)" '
  function esc(s){
    gsub(/\\/,"\\\\",s); gsub(/"/,"\\\"",s)
    gsub(/\t/," ",s); gsub(/\r/,"",s)
    return s
  }
  BEGIN{
    printf "{\"v\":1,\"generated\":%s,\"root\":\"%s\",\"games\":[\n", ts, esc(root)
    first=1
  }
  {
    if(!first) printf ",\n"
    first=0
    printf "[\"%s\",\"%s\",%d,%d]", esc($1), esc($2), $3+0, $4+0
  }
  END{ printf "\n]}\n" }
' "$TMP/sorted.tsv" > "$TMP/library.json"

cp "$TMP/library.json" "$JSON_OUT"
say "Wrote $JSON_OUT  ($COUNT games)"

if [ "$JSON_ONLY" -eq 1 ]; then
  say "Done."
  exit 0
fi

# ----------------------------------------------------------- inject into HTML
if [ ! -f "$TEMPLATE" ]; then
  say ""
  say "No template found at: $TEMPLATE"
  say "Keep library-template.html next to this script, or pass -t /path/to/it."
  say "You can also just open the HTML and drag library.json onto the page."
  exit 0
fi
grep -q '__GAME_DATA_PLACEHOLDER__' "$TEMPLATE" || die "That template has no __GAME_DATA_PLACEHOLDER__ marker in it."

ESCNAME="$(printf '%s' "$NAME" | sed 's/[\\"]/\\&/g')"
{
  sed -n '1,/__GAME_DATA_PLACEHOLDER__/p' "$TEMPLATE" | sed '$d'
  echo "const GAME_DATA ="
  cat "$TMP/library.json"
  echo ";"
  sed -n '/__GAME_DATA_PLACEHOLDER__/,$p' "$TEMPLATE" | tail -n +2
} | sed "s|^const APP_NAME = .*/\*__APP_NAME_PLACEHOLDER__\*/|const APP_NAME = \"$ESCNAME\"; /*__APP_NAME_PLACEHOLDER__*/|" \
  > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"

SIZE="$(du -h "$OUT" | cut -f1)"
SYSN="$(cut -f1 "$RAW" | sort -u | wc -l | tr -d ' ')"
say "Wrote $OUT  ($SIZE, $COUNT games, $SYSN systems)"

# ------------------------------------------------------- icons and launchers
if [ "$LAUNCHERS" -eq 1 ]; then
  DEST="$(cd "$(dirname "$OUT")" && pwd)"
  BASE="$(basename "$OUT")"
  URLBASE="${BASE// /%20}"
  BATURL="${URLBASE//%/%%}"       # batch eats a lone % , so double it

  for f in romshelf.png romshelf.ico icon.svg; do
    [ -f "$SCRIPT_DIR/$f" ] && [ "$SCRIPT_DIR" != "$DEST" ] && cp -f "$SCRIPT_DIR/$f" "$DEST/$f"
  done

  # small opener: app-mode browser window if we can, plain browser if not
  cat > "$DEST/open-shelf.sh" <<OPENER
#!/usr/bin/env bash
here="\$(cd -- "\$(dirname -- "\${BASH_SOURCE[0]}")" && pwd)"
page="file://\$here/$URLBASE"
for b in google-chrome-stable google-chrome chromium chromium-browser brave-browser microsoft-edge vivaldi-stable; do
  if command -v "\$b" >/dev/null 2>&1; then exec "\$b" --app="\$page" --class="ROM-Shelf"; fi
done
if command -v flatpak >/dev/null 2>&1 && flatpak info com.google.Chrome >/dev/null 2>&1; then
  exec flatpak run com.google.Chrome --app="\$page"
fi
exec xdg-open "\$here/$BASE"
OPENER
  chmod +x "$DEST/open-shelf.sh"

  cat > "$DEST/$NAME.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=$NAME
Comment=Search the games on your Steam Deck
Exec=$DEST/open-shelf.sh
Icon=$DEST/romshelf.png
Terminal=false
Categories=Game;Utility;
StartupWMClass=ROM-Shelf
DESKTOP
  chmod +x "$DEST/$NAME.desktop"

  cat > "$DEST/$NAME.command" <<CMD
#!/bin/sh
cd "\$(dirname "\$0")"
open "$BASE"
CMD
  chmod +x "$DEST/$NAME.command"

  say "Also wrote: $NAME.desktop (Linux/Deck) · $NAME.command (macOS) · romshelf.png/.ico"
  say "On Windows, use ROM Shelf.exe instead — it needs only library.json."
fi

say ""
say "Copy the whole folder to your computer, or just \"$BASE\" on its own."
