# ROM Shelf

<p align="center">
  <img src="assets/icon.svg" width="112" height="112" alt="ROM Shelf cartridge icon">
</p>

<p align="center">
  A fast, private and portable catalogue for the games on your Steam Deck.
</p>

<p align="center">
  <a href="https://github.com/xEnakil/DeckShelf/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/xEnakil/DeckShelf/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/xEnakil/DeckShelf/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/xEnakil/DeckShelf"></a>
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-2323C8"></a>
</p>

ROM Shelf scans the ROM folders you already manage and turns them into a searchable, offline library. Use the native Windows app for its own window and taskbar entry, or generate a single HTML file that works in any modern browser.

> ROM Shelf is a catalogue, not an emulator or ROM downloader. It never includes, copies or launches copyrighted game data.

## Download

[Download the latest Windows release](https://github.com/xEnakil/DeckShelf/releases/latest), extract it, and keep `ROM Shelf.exe` next to the `library.json` generated on your Steam Deck.

The Windows binary is currently unsigned, so SmartScreen may show a first-run warning. Published releases include SHA-256 checksums and are rebuilt from this repository by GitHub Actions.

## How it works

| Part | Runs on | Purpose |
|---|---|---|
| `generate-library.sh` | Steam Deck / Linux | Scans your selected ROM directory and writes `library.json` or a complete HTML shelf |
| `library-template.html` | Any modern browser | Provides the complete interface, search and local browser storage |
| `ROM Shelf.exe` | Windows 10/11 | Hosts that same template in a native WebView2 window |

Both versions use one HTML template. The native app injects `library.json` when the page loads and stores preferences in `shelf-settings.json`; the browser build embeds the library and uses `localStorage`.

## Quick start

### 1. Create your library on the Steam Deck

In Desktop Mode, put `generate-library.sh`, `library-template.html` and the `assets` folder together, then run:

```bash
chmod +x generate-library.sh
./generate-library.sh --json-only
```

The scanner checks common EmuDeck and RetroDECK locations. Point it somewhere else when needed:

```bash
./generate-library.sh --roms /run/media/deck/SDCARD/Emulation/roms --json-only
```

### 2. Open it on Windows

Copy `library.json` beside `ROM Shelf.exe`, then double-click the executable. You can also drag a JSON file onto the executable or drop one into the open window.

When you update your library, replace `library.json` and press <kbd>F5</kbd>. The native app reads it from disk on every reload.

### Browser-only build

Run the generator without `--json-only`:

```bash
./generate-library.sh --name "Deck Vault"
```

This creates a self-contained HTML file plus launchers for Linux, Windows and macOS. Copy the generated folder anywhere and open the launcher for your platform.

## Scanner options

```text
-r, --roms DIR       folder to scan
-o, --out FILE       output HTML path (default: ROM Shelf.html)
-t, --template FILE  template to use
-s, --systems FILE   scan only systems listed in a file, one per line
-n, --name NAME      shelf and output name (default: ROM Shelf)
-x, --exclude NAME   ignore a file or folder name; repeat as needed
    --no-launchers   create HTML without platform launchers
    --json-only      write library.json without HTML
    --all            keep files that the normal safety filters skip
```

Names may contain letters, numbers, spaces, dots, dashes and underscores.

## What the scanner excludes

ROM Shelf removes common false positives before they reach the UI:

- EmuDeck and RetroDECK bookkeeping such as `systeminfo.txt`, `metadata.txt` and `gamelist.xml`.
- Emulator working folders, saves, states, caches, logs, artwork, manuals and videos.
- Empty files, patches, configuration files and desktop shortcuts.
- `.bin`, `.raw`, `.sub` and related tracks when a matching `.cue`, `.gdi`, `.m3u` or `.ccd` exists.
- Systems that have no remaining games.

Folder-based systems such as PS3, Wii U, DOS, ports and ScummVM are counted one top-level folder at a time, including the folder's total size. Use repeated `--exclude` options for setup-specific clutter, or `--all` when you intentionally want every entry.

## Using the shelf

- Search ignores punctuation and case: `supermetroid` can match *Super Metroid*.
- Terms can appear in any order: `zelda link past` matches the complete title.
- Filters such as `sys:snes`, `region:japan`, `ext:chd` and `fav:` mix with normal words.
- Typo suggestions help recover near matches.
- **Check a list** compares pasted titles with your shelf and copies the missing entries.
- **Export** saves the current results to a text file.
- The storage chart breaks usage down by system and doubles as a filter.
- Duplicate titles collapse into one row while preserving every file and system.
- Press <kbd>?</kbd> for the complete shortcut list.

Stars, filters, theme, recent searches and the last query survive restarts.

## Native Windows app

ROM Shelf is a genuine native executable built with Go, MinGW-w64 and [`webview_go`](https://github.com/webview/webview_go). It uses the WebView2 runtime included with current Windows 10 and Windows 11 installations and links only to Windows system libraries. There is no Electron, Node.js runtime, installer or Visual C++ redistributable.

The executable:

- owns its window, taskbar entry and icon;
- reads `library.json` from beside the executable or from a dropped path;
- writes portable preferences to `shelf-settings.json` beside the executable;
- keeps WebView2 data in the local `shelf-cache` directory;
- falls back to an installed browser when WebView2 is unavailable.

The UI is served only on `127.0.0.1` behind a random per-run path. A restrictive content-security policy prevents the page from making network requests. Nothing in your game list is uploaded.

## Build from source

The scanner and browser build require Bash, `find`, `awk` and `du`. The native build additionally needs Go 1.22+ and a MinGW-w64 cross-compiler:

```bash
sudo apt-get install mingw-w64
VERSION=dev ./scripts/build-windows.sh
```

The executable is written to `dist/ROM Shelf.exe`. The build script compiles resource `#1` from `assets/romshelf.ico`, which the application applies with `WM_SETICON`.

Run the generator regression suite with:

```bash
./tests/test-generator.sh
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the data and runtime design.

## Repository layout

```text
assets/                  shared icons
docs/                    architecture and project documentation
scripts/build-windows.sh reproducible native build
tests/                   generator regression tests
app_windows.go           data, settings and local server
main_windows.go          WebView2 window and Windows integration
generate-library.sh      Steam Deck scanner
library-template.html    the single shared UI template
```

Generated libraries, personal settings, caches and executables are ignored by Git. An intentionally fictional sample is available at [`examples/library.sample.json`](examples/library.sample.json).

## Contributing and security

Issues and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before sending a change. Report security problems privately using [GitHub's security advisory form](https://github.com/xEnakil/DeckShelf/security/advisories/new) rather than opening a public issue.

## License

ROM Shelf is available under the [MIT License](LICENSE).
