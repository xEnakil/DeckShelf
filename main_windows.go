//go:build windows

package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"time"
	"unsafe"

	webview "github.com/webview/webview_go"
)

var version = "dev"

const webView2ClientState = `SOFTWARE\Microsoft\EdgeUpdate\ClientState\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}`

func main() {
	if err := initPaths(); err != nil {
		showError(err)
		return
	}
	settingsLoad()

	if !webView2Available() {
		if err := fallbackToBrowser(); err != nil {
			showError(err)
		}
		return
	}

	local, err := serve(true)
	if err != nil {
		showError(err)
		return
	}
	defer local.shutdown()

	window := webview.New(false)
	defer window.Destroy()
	window.SetTitle(appName)
	window.SetSize(1280, 880, webview.HintNone)
	applyIcon(uintptr(window.Window()))
	if err := window.Bind("nativeSave", func(key, value string) error {
		return settingsSet(key, value)
	}); err != nil {
		showError(err)
		return
	}
	window.Navigate(local.url)
	window.Run()
}

func webView2Available() bool {
	for _, root := range []syscall.Handle{
		syscall.Handle(syscall.HKEY_LOCAL_MACHINE),
		syscall.Handle(syscall.HKEY_CURRENT_USER),
	} {
		keyName, _ := syscall.UTF16PtrFromString(webView2ClientState)
		var key syscall.Handle
		err := syscall.RegOpenKeyEx(root, keyName, 0, syscall.KEY_QUERY_VALUE|syscall.KEY_WOW64_32KEY, &key)
		if err != nil {
			continue
		}
		valueName, _ := syscall.UTF16PtrFromString("EBWebView")
		var valueType uint32
		var size uint32
		err = syscall.RegQueryValueEx(key, valueName, nil, &valueType, nil, &size)
		_ = syscall.RegCloseKey(key)
		if err == nil && size > 2 {
			return true
		}
	}
	return false
}

func fallbackToBrowser() error {
	local, err := serve(false)
	if err != nil {
		return err
	}
	defer local.shutdown()

	if err := openBrowser(local.url); err != nil {
		return err
	}
	select {
	case <-local.loaded:
		// The response is self-contained. Give the browser a moment to finish
		// consuming it before the temporary loopback server is closed.
		time.Sleep(2 * time.Second)
	case <-time.After(30 * time.Second):
	}
	return nil
}

func openBrowser(url string) error {
	for _, browser := range browsers() {
		if _, err := os.Stat(browser); err != nil {
			continue
		}
		command := exec.Command(browser, "--app="+url, "--window-size=1280,880")
		return command.Start()
	}
	return exec.Command("rundll32.exe", "url.dll,FileProtocolHandler", url).Start()
}

func browsers() []string {
	programFiles := os.Getenv("ProgramFiles")
	programFilesX86 := os.Getenv("ProgramFiles(x86)")
	localAppData := os.Getenv("LOCALAPPDATA")
	return []string{
		filepath.Join(programFilesX86, "Microsoft", "Edge", "Application", "msedge.exe"),
		filepath.Join(programFiles, "Microsoft", "Edge", "Application", "msedge.exe"),
		filepath.Join(localAppData, "Microsoft", "Edge", "Application", "msedge.exe"),
		filepath.Join(programFiles, "Google", "Chrome", "Application", "chrome.exe"),
		filepath.Join(programFilesX86, "Google", "Chrome", "Application", "chrome.exe"),
		filepath.Join(localAppData, "Google", "Chrome", "Application", "chrome.exe"),
		filepath.Join(programFiles, "BraveSoftware", "Brave-Browser", "Application", "brave.exe"),
		filepath.Join(programFilesX86, "BraveSoftware", "Brave-Browser", "Application", "brave.exe"),
		filepath.Join(localAppData, "BraveSoftware", "Brave-Browser", "Application", "brave.exe"),
	}
}

var (
	user32           = syscall.NewLazyDLL("user32.dll")
	kernel32         = syscall.NewLazyDLL("kernel32.dll")
	loadImageW       = user32.NewProc("LoadImageW")
	sendMessageW     = user32.NewProc("SendMessageW")
	messageBoxW      = user32.NewProc("MessageBoxW")
	getModuleHandleW = kernel32.NewProc("GetModuleHandleW")
)

func applyIcon(window uintptr) {
	const (
		imageIcon = 1
		wmSetIcon = 0x0080
		iconSmall = 0
		iconBig   = 1
	)
	module, _, _ := getModuleHandleW.Call(0)
	if module == 0 || window == 0 {
		return
	}
	big, _, _ := loadImageW.Call(module, 1, imageIcon, 32, 32, 0)
	small, _, _ := loadImageW.Call(module, 1, imageIcon, 16, 16, 0)
	if big != 0 {
		_, _, _ = sendMessageW.Call(window, wmSetIcon, iconBig, big)
	}
	if small != 0 {
		_, _, _ = sendMessageW.Call(window, wmSetIcon, iconSmall, small)
	}
}

func showError(err error) {
	if err == nil {
		return
	}
	message, messageErr := syscall.UTF16PtrFromString(err.Error())
	title, titleErr := syscall.UTF16PtrFromString(appName)
	if messageErr != nil || titleErr != nil {
		return
	}
	_, _, _ = messageBoxW.Call(0, uintptr(unsafePointer(message)), uintptr(unsafePointer(title)), 0x10)
}

// unsafePointer is kept tiny and local so the Win32 plumbing does not leak
// into the rest of the application.
func unsafePointer(value *uint16) unsafe.Pointer {
	return unsafe.Pointer(value)
}
