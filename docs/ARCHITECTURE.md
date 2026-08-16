# Architecture

ROM Shelf has two delivery formats and one UI source.

```text
Steam Deck ROM folders
        |
        v
generate-library.sh -----> library.json
        |                       |
        |                       +----> ROM Shelf.exe / WebView2
        v
ROM Shelf.html

Both paths render library-template.html.
```

## Data format

`library.json` uses a compact, versioned envelope:

```json
{
  "v": 1,
  "generated": 0,
  "root": "/home/deck/Emulation/roms",
  "games": [
    ["snes", "Example Quest (USA).sfc", 2097152, 0]
  ]
}
```

Each game tuple is `[system, filename, bytes, modifiedUnixSeconds]`. The compact representation keeps large libraries quick to copy and parse.

## Browser build

The generator scans with `find`, filters records with `awk`, serializes the compact JSON and replaces the data marker in `library-template.html`. The result has no external network dependency. Browser preferences use `localStorage`, with an in-memory fallback when storage is blocked.

## Native build

The Windows executable embeds `library-template.html` at compile time. At startup it:

1. resolves its own directory and an optional dropped JSON path;
2. reads portable settings from `shelf-settings.json`;
3. serves the rendered page on `127.0.0.1` at a cryptographically random path;
4. creates a WebView2 window and binds `nativeSave` for preference writes;
5. reloads `library.json` and settings on each page request.

The loopback handler serves one exact random path, sends `Cache-Control: no-store` and applies a content-security policy that disallows network connections. Settings writes use a temporary file and atomic rename.

`main_windows.go` owns the Windows-specific integration: WebView2 detection, fallback browser launch, sizing, error dialogs and resource icon application. `app_windows.go` owns data and page behavior.

## Build and release

`scripts/build-windows.sh` uses Go with a MinGW-w64 CGO cross-compiler. It applies a small reviewed patch to the pinned `webview_go` source so the bridge accepts `WEBVIEW2_USER_DATA_FOLDER`; this keeps WebView2 state beside the executable instead of roaming AppData. `romshelf.rc` becomes resource `#1`, and linker flags produce a GUI subsystem executable with symbols stripped. Tagged releases rebuild the executable, package the portable files and publish SHA-256 checksums.
