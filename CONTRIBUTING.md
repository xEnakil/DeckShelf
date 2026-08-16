# Contributing to ROM Shelf

Thanks for helping improve ROM Shelf. Small fixes, platform testing, scanner rules, accessibility improvements and focused feature proposals are all welcome.

## Before opening a change

- Search the existing issues and pull requests.
- Keep the project offline-first and dependency-light.
- Never commit ROMs, BIOS files, a real `library.json`, `shelf-settings.json`, `shelf-cache` or built executables.
- Use fictional game names and paths in tests, screenshots and bug reports.
- Keep the browser and native versions on the shared `library-template.html` rather than forking the interface.

## Development setup

The generator needs Bash, GNU `find`, `awk` and `du`. Git Bash works for its regression suite on Windows.

```bash
./tests/test-generator.sh
```

For the native Windows build, install Go 1.22 or newer and MinGW-w64 on Linux or WSL:

```bash
sudo apt-get update
sudo apt-get install mingw-w64
VERSION=dev ./scripts/build-windows.sh
```

The native build uses CGO because `webview_go` includes a small C/C++ WebView2 bridge. The build script applies the reviewed patch in `patches/webview-portable-cache.patch` to make the dependency honor the app's portable cache directory. The resulting application remains a single self-contained executable and has no third-party runtime redistributable.

## Pull requests

1. Create a focused branch.
2. Add or update tests for behavior changes.
3. Run the generator tests and the native build when your change affects them.
4. Explain what changed, why it is useful and how you validated it.
5. Keep commits reviewable; Conventional Commit-style subjects are encouraged.

By contributing, you agree that your work may be distributed under the repository's MIT License.
