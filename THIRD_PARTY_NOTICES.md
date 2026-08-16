# Third-party notices

ROM Shelf's native Windows build uses the following source dependencies:

- [`github.com/webview/webview_go`](https://github.com/webview/webview_go), MIT License.
- [`webview/webview`](https://github.com/webview/webview), MIT License, included by `webview_go`.
- Microsoft WebView2 SDK interface headers, distributed with `webview_go` under Microsoft's WebView2 SDK license terms.

The exact Go dependency version and integrity hashes are recorded in `go.mod` and `go.sum`. The build applies `patches/webview-portable-cache.patch` so the pinned WebView bridge honors ROM Shelf's per-executable WebView2 data directory. No third-party runtime is bundled with the executable; Windows supplies WebView2 and the imported system libraries.
