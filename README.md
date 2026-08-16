# ROM Shelf

Two files. One scans your Steam Deck, the other is the searchable library you open on your PC.

| File | Where it runs | What it does |
|---|---|---|
| `generate-library.sh` | Steam Deck (Desktop Mode terminal) | Walks your ROM folders and writes the library |
| `library-template.html` | stays next to the script | The app itself, waiting for data |
| `ROM Shelf.exe` | your Windows PC | Double-click app that opens the shelf |
| `icon.svg` / `romshelf.png` / `romshelf.ico` | copied next to the output | The shelf icon, in every size you need |

## Run it on the Deck

Put both files in the same folder, then:

```bash
chmod +x generate-library.sh
./generate-library.sh
```

It looks for your ROMs in the usual places (`~/Emulation/roms`, RetroDECK's folder, `/run/media/*/Emulation/roms`). If it guesses wrong:

```bash
./generate-library.sh -r /run/media/deck/SDCARD/Emulation/roms
```

You get a folder containing:

- **`ROM Shelf.html`** — the whole library in one self-contained file. This is the only file that actually matters.
- **`ROM Shelf.desktop`** — double-click launcher for Linux and the Deck's Desktop Mode
- **`Launch ROM Shelf.bat`** — double-click launcher for Windows
- **`ROM Shelf.command`** — double-click launcher for macOS
- `romshelf.png`, `romshelf.ico`, `icon.svg` — the icon
- `open-shelf.sh` — what the Linux launcher calls

Copy the folder to your computer (USB, Syncthing, Warpinator, whatever). The launchers open the shelf in a clean window with no address bar and no tabs, so it behaves like a real app. Nothing needs internet.

### Want a different name?

```bash
./generate-library.sh -n "Deck Vault"
```

That renames the window, the wordmark in the header, the file, and every launcher.

### Other options

```
-r, --roms DIR       folder to scan
-o, --out FILE       where the HTML goes (default: MyGameLibrary.html)
-s, --systems FILE   only scan systems listed in a file, one per line
-n, --name NAME      what the app calls itself (default: ROM Shelf)
-x, --exclude NAME   ignore a file or folder name; repeat as needed
    --no-launchers   just the HTML, no shortcuts
    --json-only      write library.json and stop
    --all            skip all filtering, keep every file found
```

## What the scan skips

- **EmuDeck / RetroDECK bookkeeping.** `systeminfo.txt` and `metadata.txt` land in every system folder whether or not it has games. Without filtering, all 80-odd of your empty systems look like they hold two games each.
- **Emulator working folders.** `CFG`, `EMULATOR`, `NVDATA`, `pfx`, `scripts`, `saves`, `states`, `cache`, `logs`.
- Artwork and scraper folders: `media`, `images`, `videos`, `manuals`, `downloaded_media`, gamelists.
- Save files and game patches, including the `something.patch.toml` files Xenia leaves next to Xbox 360 roms.
- Empty (0-byte) files.
- `.bin` files that already have a `.cue` beside them, so a PS1 game counts once rather than twice.

Systems that end up with nothing simply don't appear.

`ps3`, `wiiu`, `dos`, `pc`, `ports`, `scummvm`, `steam`, `mugen`, `openbor` and friends are one-folder-per-game, with folder sizes added up. Sega Model 2 and Model 3 are not — their games live in a `roms` subfolder next to the emulator itself, so those are scanned as files.

The scan prints what it found, per system, so anything odd is easy to spot. Something still slipping through?

```bash
./generate-library.sh -x "weird-file.bin" -x "somefolder"
```

Repeat `-x` as many times as you need.

## Two builds, one app

| | `ROM Shelf.exe` | `ROM Shelf.html` |
|---|---|---|
| Window | Native, its own taskbar entry and icon | A browser tab |
| Needs | Windows 10/11 | Any browser, any OS |
| Data | `library.json` beside the exe | Baked into the file, or dropped on the page |
| Settings | `shelf-settings.json`, portable | Browser storage, per machine |

Same interface, same search, same everything. Use whichever suits the machine.

The exe is a real desktop application — it draws its own window through WebView2, which ships with Windows 10 and 11. No browser is launched, nothing appears in your tabs, and there is nothing to install. It links only against Windows system libraries: no runtime, no Visual C++ redistributable, no Node, no Electron. That is why it is 5 MB rather than 150 MB.

If WebView2 is somehow missing (a stripped-down Windows install), it quietly falls back to opening in your default browser rather than failing.

## The Windows app

The everyday loop is two steps.

**On the Deck**, export just the data:

```bash
./generate-library.sh --json-only
```

That writes `library.json` and nothing else.

**On the PC**, put `library.json` in the same folder as `ROM Shelf.exe` and double-click it. A real window opens, with the cartridge icon in the taskbar.

Stars, filters, theme and your last search are written to `shelf-settings.json` next to the exe. Copy the folder to a USB stick and it all travels with you — nothing lives in a browser profile.

You can also drag a `library.json` straight onto the exe from anywhere, or drop one onto the window once it's open.

Updated your ROMs? Copy the new `library.json` over the old one and press F5. The exe re-reads it from disk on every page load.

Notes:

- Windows may show a SmartScreen warning the first time, because the exe is not code-signed (signing costs a few hundred a year). Click *More info* → *Run anyway*.
- `shelf-cache/` appears next to the exe on first run. That is WebView2's own cache, kept local so the app stays portable. Deleting it is harmless.

## Making it a real app elsewhere

**Steam Deck / Linux.** Right-click `ROM Shelf.desktop` → Properties → Permissions → tick *Is executable*. Drop it in `~/.local/share/applications/` for the app menu, or right-click → *Add to Steam* to get it in Game Mode with the cartridge icon.

**macOS.** Double-click `ROM Shelf.command`. First run may need right-click → Open.

**Phone or tablet.** Open the HTML in Safari or Chrome and use *Add to Home Screen*.

## Using the shelf

Type. That's the whole thing — the banner up top says **You have it** or **Not on the shelf** before you finish the word.

- Punctuation and case don't matter: `supermetroid` finds *Super Metroid*
- Words can be in any order: `zelda link past` finds *The Legend of Zelda - A Link to the Past*
- `sys:snes` · `region:japan` · `ext:chd` · `fav:` narrow things down, and mix with normal words
- Typos get caught: search `castlevaina` and it offers *Castlevania - Symphony of the Night* as a close match
- Filenames are searched too, so serials like `BLES00932` or arcade names like `mslug3` land
- **Check a list** takes a pasted block of names and tells you which ones are new to you — copy the missing ones straight out
- **Export** saves whatever you are currently looking at as a text file
- **Space used** — a donut of storage per system in the sidebar. Nothing selected shows your whole library; click systems (in the list or in the donut itself) and it narrows to just those. Hover any slice for its size and share. Launchers and shortcuts (Desktop apps, Steam, Epic, Cloud, Moonlight, Remote Play, Lutris, Kodi) stay out of it, since they are not really storage
- Same title on several systems collapses into one row; click it to see each file
- Press `?` for the shortcut list

Stars, filters, theme and your last search survive a reload. Nothing leaves your machine.

## Re-scanning later

Run the script again after you add games. If you'd rather not re-copy the whole HTML every time, use `--json-only` and drag the fresh `library.json` onto the page you already have — it remembers it.
