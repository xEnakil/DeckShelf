//go:build windows

package main

import (
	"context"
	"crypto/rand"
	_ "embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

const (
	appName       = "ROM Shelf"
	settingsName  = "shelf-settings.json"
	defaultData   = "library.json"
	gameDataToken = "const GAME_DATA = null; /*__GAME_DATA_PLACEHOLDER__*/"
)

// The native executable and generated HTML intentionally share this template.
//
//go:embed library-template.html
var templateHTML string

var (
	applicationDir string
	libraryPath    string
	settingsPath   string

	settingsMu sync.RWMutex
	settings   = map[string]string{}
)

var allowedSettings = map[string]struct{}{
	"shelf.data":   {},
	"shelf.favs":   {},
	"shelf.recent": {},
	"shelf.state":  {},
	"shelf.theme":  {},
}

func initPaths() error {
	executable, err := os.Executable()
	if err != nil {
		return err
	}
	applicationDir = filepath.Dir(executable)
	settingsPath = filepath.Join(applicationDir, settingsName)
	libraryPath = filepath.Join(applicationDir, defaultData)
	if err := os.Setenv("WEBVIEW2_USER_DATA_FOLDER", filepath.Join(applicationDir, "shelf-cache")); err != nil {
		return err
	}

	if len(os.Args) > 1 && strings.EqualFold(filepath.Ext(os.Args[1]), ".json") {
		path, err := filepath.Abs(os.Args[1])
		if err != nil {
			return err
		}
		libraryPath = path
	}
	return nil
}

func settingsLoad() {
	data, err := os.ReadFile(settingsPath)
	if err != nil {
		return
	}

	loaded := map[string]string{}
	if json.Unmarshal(data, &loaded) != nil {
		return
	}

	settingsMu.Lock()
	settings = loaded
	settingsMu.Unlock()
}

func settingsSet(key, value string) error {
	if _, ok := allowedSettings[key]; !ok {
		return errors.New("unsupported setting")
	}

	settingsMu.Lock()
	defer settingsMu.Unlock()

	if value == "" {
		delete(settings, key)
	} else {
		settings[key] = value
	}

	data, err := json.MarshalIndent(settings, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')

	temporary, err := os.CreateTemp(applicationDir, ".shelf-settings-*.tmp")
	if err != nil {
		return err
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)

	if _, err = temporary.Write(data); err == nil {
		err = temporary.Sync()
	}
	if closeErr := temporary.Close(); err == nil {
		err = closeErr
	}
	if err != nil {
		return err
	}
	return os.Rename(temporaryPath, settingsPath)
}

func settingsJSON() string {
	settingsMu.RLock()
	defer settingsMu.RUnlock()
	data, err := json.Marshal(settings)
	if err != nil {
		return "{}"
	}
	return string(data)
}

func loadJSON() []byte {
	data, err := os.ReadFile(libraryPath)
	if err != nil {
		return nil
	}

	var payload any
	decoder := json.NewDecoder(strings.NewReader(string(data)))
	decoder.UseNumber()
	if decoder.Decode(&payload) != nil {
		return nil
	}
	if decoder.Decode(&struct{}{}) != io.EOF {
		return nil
	}

	// Re-encoding both validates the document and HTML-escapes names that could
	// otherwise terminate the inline script element.
	clean, err := json.Marshal(payload)
	if err != nil {
		return nil
	}
	return clean
}

func buildPage(native bool) string {
	page := templateHTML
	if data := loadJSON(); len(data) > 0 {
		replacement := "const GAME_DATA =\n" + string(data) + "\n; /*__GAME_DATA_PLACEHOLDER__*/"
		page = strings.Replace(page, gameDataToken, replacement, 1)
	}

	if native {
		bootstrap := "<script>window.__NATIVE=true;window.__SETTINGS=" + settingsJSON() + ";</script>\n"
		page = strings.Replace(page, "<script>", bootstrap+"<script>", 1)
	}
	return page
}

type localServer struct {
	url      string
	loaded   <-chan struct{}
	shutdown func()
}

func serve(native bool) (*localServer, error) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return nil, err
	}

	tokenBytes := make([]byte, 16)
	if _, err := rand.Read(tokenBytes); err != nil {
		listener.Close()
		return nil, err
	}
	path := "/" + hex.EncodeToString(tokenBytes)

	loaded := make(chan struct{})
	var loadedOnce sync.Once
	mux := http.NewServeMux()
	mux.HandleFunc(path, func(response http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodGet && request.Method != http.MethodHead {
			response.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		response.Header().Set("Cache-Control", "no-store")
		response.Header().Set("Content-Security-Policy", "default-src 'none'; img-src data: blob:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; font-src data:; connect-src 'none'; object-src 'none'; base-uri 'none'; frame-src 'none'")
		response.Header().Set("Content-Type", "text/html; charset=utf-8")
		if request.Method == http.MethodGet {
			_, _ = io.WriteString(response, buildPage(native))
		}
		loadedOnce.Do(func() { close(loaded) })
	})

	server := &http.Server{
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		IdleTimeout:       30 * time.Second,
	}
	go func() {
		_ = server.Serve(listener)
	}()

	var shutdownOnce sync.Once
	shutdown := func() {
		shutdownOnce.Do(func() {
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()
			_ = server.Shutdown(ctx)
		})
	}

	return &localServer{
		url:      "http://" + listener.Addr().String() + path,
		loaded:   loaded,
		shutdown: shutdown,
	}, nil
}
