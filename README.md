# Deck Shelf

<p align="center">
  <img src="assets/icon.svg" width="112" height="112" alt="Deck Shelf cartridge icon">
</p>

<p align="center">
  A fast, private, portable catalogue for the games you already manage.
</p>

<p align="center">
  <a href="https://github.com/xEnakil/DeckShelf/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/xEnakil/DeckShelf/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/xEnakil/DeckShelf/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/xEnakil/DeckShelf"></a>
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-2323C8"></a>
</p>

Deck Shelf scans the ROM folders you already manage and turns them into a searchable offline library. It does not include an emulator, download games, launch games, or upload your library.

The same interface ships in two forms:

- a small Rust desktop application using the webview already provided by the operating system;
- a self-contained HTML file that opens in any modern browser.

No Electron. No Node.js runtime. No account, server, telemetry, or installer.

## Download

Download the archive for your system from the [latest release](https://github.com/xEnakil/DeckShelf/releases/latest):

| Platform | Native engine | Release |
|---|---|---|
| Windows 10/11 x64 | WebView2 | `windows-x64` |
| macOS Apple Silicon | WKWebView | `macos-arm64` |
| macOS Intel | WKWebView | `macos-x64` |
| Linux x64 | WebKitGTK 4.1 | `linux-x64` |
| Any modern browser | Browser engine | Generate `Deck Shelf.html` |

Keep the native executable beside `library.json`. Windows preferences and webview data remain portable in `deck-shelf-settings.json` and `deck-shelf-cache` beside the executable. Linux requires the system WebKitGTK 4.1 package. Published binaries are unsigned and releases include SHA-256 checksums.

## Quick start

### 1. Build the library index

In Steam Deck Desktop Mode, keep `generate-library.sh`, `library-template.html`, and `assets` together. Then run:

```bash
chmod +x generate-library.sh
./generate-library.sh --json-only
```

The scanner detects common EmuDeck and RetroDECK locations. An explicit path also works:

```bash
./generate-library.sh --roms /run/media/deck/SDCARD/Emulation/roms --json-only
```

### 2. Open Deck Shelf

Copy the resulting `library.json` beside the native application and launch it. A JSON path can also be passed as the first command-line argument. Replace `library.json` and refresh the window after rescanning.

If the Windows WebView2 runtime cannot initialize, Deck Shelf writes a self-contained browser fallback beside the executable and opens it instead of crashing.

### Browser-only mode

Run the generator without `--json-only`:

```bash
./generate-library.sh
```

This writes `Deck Shelf.html` plus small launchers for Linux, Windows, and macOS. The generated page embeds the library, works offline, and stores preferences in browser `localStorage`.

## Scanner options

```text
-r, --roms DIR       folder to scan
-o, --out FILE       output HTML path (default: Deck Shelf.html)
-t, --template FILE  template to use
-s, --systems FILE   scan only systems listed in a file, one per line
-n, --name NAME      app and output name (default: Deck Shelf)
-x, --exclude NAME   ignore a file or folder name; repeat as needed
    --no-launchers   create HTML without platform launchers
    --json-only      write library.json without HTML
    --all            keep files the normal safety filters skip
```

The scanner removes common false positives before they reach the UI:

- EmuDeck and RetroDECK bookkeeping, metadata, artwork, manuals, videos, saves, states, caches, and logs;
- empty files, patches, configuration files, and desktop shortcuts;
- duplicate disc tracks when a matching `.cue`, `.gdi`, `.m3u`, or `.ccd` exists;
- systems with no remaining games.

Folder-based systems such as PS3, Wii U, DOS, ports, and ScummVM are counted one top-level folder at a time. Use repeated `--exclude` flags for setup-specific clutter or `--all` to keep every entry.

## Search and library tools

- Punctuation-insensitive, case-insensitive title search.
- Terms in any order and filters such as `sys:snes`, `region:japan`, `ext:chd`, and `fav:`.
- Typo suggestions, favourites, recent searches, theme persistence, and keyboard shortcuts.
- A list checker for comparing wanted titles against the shelf.
- Text export, storage breakdowns, system filters, and duplicate-title collapsing.

## Native design

The desktop shell is written in Rust with [Wry](https://github.com/tauri-apps/wry) and [Tao](https://github.com/tauri-apps/tao). It embeds `library-template.html` at compile time and adds only four native responsibilities:

1. own the window, taskbar entry, and icon;
2. load and validate `library.json`;
3. persist an allowlisted set of preferences beside the executable;
4. host the page through a private custom protocol with a restrictive content-security policy.

Rust release builds use optimization level 3, thin LTO, one code-generation unit, stripped symbols, and abort-on-panic. The Windows target statically links its C runtime; dependency verification rejects Visual C++ redistributable imports. The current optimized Windows build is about 1.2 MB and imports Windows system libraries only.

Most search and rendering work still happens in the shared JavaScript interface, so Rust is not presented as a magic speed switch. Its value here is a small, memory-safe native layer, strong release builds, and one implementation across Windows, macOS, and Linux.

## Build and test

Install Rust 1.97.1 or let `rustup` use the checked-in toolchain file.

Windows needs Visual Studio Build Tools with the Desktop development with C++ workload. macOS needs Xcode Command Line Tools. Debian and Ubuntu need WebKitGTK headers:

```bash
sudo apt install libwebkit2gtk-4.1-dev
```

Then run:

```bash
cargo fmt --all -- --check
cargo test --locked --all-targets
cargo clippy --locked --all-targets -- -D warnings
cargo build --locked --release
./tests/test-generator.sh
```

GitHub Actions repeats those checks on Windows x64, Linux x64, macOS Apple Silicon, and macOS Intel. Tags build all four release archives and publish a single checksum manifest.

## Repository

```text
src/                       Rust native shell and portable storage
assets/                    shared application icons
scripts/                   release packaging and Windows dependency checks
tests/                     scanner regression tests
generate-library.sh        Steam Deck and Linux scanner
library-template.html      the single shared interface
examples/library.sample.json
```

Personal libraries, settings, caches, generated pages, and binaries are ignored by Git. The sample library is intentionally fictional.

`@xEnakil` is the sole maintainer and project decision-maker. Anyone can use the public [issue tracker](https://github.com/xEnakil/DeckShelf/issues) for reproducible bugs or focused feature requests. Security problems should use the repository's [private advisory form](https://github.com/xEnakil/DeckShelf/security/advisories/new).

## License

Deck Shelf is available under the [MIT License](LICENSE). Third-party dependency information is recorded in [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt) and `Cargo.lock`.
