use serde::Deserialize;
use serde_json::Value;
use std::{
    collections::BTreeMap,
    ffi::OsStr,
    fs::{self, File},
    io::{self, Write},
    path::{Path, PathBuf},
    sync::{Arc, Mutex},
};

pub const APP_NAME: &str = "Deck Shelf";
pub const CONTENT_SECURITY_POLICY: &str = "default-src 'none'; img-src data: blob:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; font-src data:; connect-src 'none'; object-src 'none'; base-uri 'none'; frame-src 'none'";

const TEMPLATE_HTML: &str = include_str!("../library-template.html");
const GAME_DATA_TOKEN: &str = "const GAME_DATA = null; /*__GAME_DATA_PLACEHOLDER__*/";
const SETTINGS_NAME: &str = "deck-shelf-settings.json";
const LEGACY_SETTINGS_NAME: &str = "shelf-settings.json";
const CACHE_NAME: &str = "deck-shelf-cache";
const DEFAULT_LIBRARY_NAME: &str = "library.json";
const FALLBACK_NAME: &str = "Deck Shelf (browser fallback).html";
const MAX_SETTING_BYTES: usize = 6 * 1024 * 1024;

#[derive(Clone)]
pub struct AppState {
    application_dir: PathBuf,
    library_path: PathBuf,
    settings_path: PathBuf,
    settings: Arc<Mutex<BTreeMap<String, String>>>,
}

#[derive(Deserialize)]
struct SaveMessage {
    key: String,
    value: String,
}

impl AppState {
    pub fn discover() -> io::Result<Self> {
        let executable = std::env::current_exe()?;
        let application_dir = executable
            .parent()
            .ok_or_else(|| io::Error::other("the executable has no parent directory"))?
            .to_path_buf();

        let library_path = std::env::args_os()
            .nth(1)
            .filter(|path| {
                Path::new(path)
                    .extension()
                    .and_then(OsStr::to_str)
                    .is_some_and(|extension| extension.eq_ignore_ascii_case("json"))
            })
            .map(PathBuf::from)
            .map(|path| path.canonicalize())
            .transpose()?
            .unwrap_or_else(|| application_dir.join(DEFAULT_LIBRARY_NAME));

        let settings_path = application_dir.join(SETTINGS_NAME);
        let settings = if settings_path.exists() {
            load_settings(&settings_path)
        } else {
            load_settings(&application_dir.join(LEGACY_SETTINGS_NAME))
        };

        Ok(Self {
            application_dir,
            library_path,
            settings_path,
            settings: Arc::new(Mutex::new(settings)),
        })
    }

    pub fn cache_dir(&self) -> PathBuf {
        self.application_dir.join(CACHE_NAME)
    }

    pub fn initialization_script(&self) -> String {
        let settings = self
            .settings
            .lock()
            .map(|values| serde_json::to_string(&*values).unwrap_or_else(|_| "{}".into()))
            .unwrap_or_else(|_| "{}".into());

        format!(
            "window.__NATIVE=true;window.__SETTINGS={settings};window.nativeSave=(key,value)=>window.ipc.postMessage(JSON.stringify({{key,value}}));"
        )
    }

    pub fn build_page(&self) -> io::Result<String> {
        let Ok(raw) = fs::read(&self.library_path) else {
            return Ok(TEMPLATE_HTML.to_owned());
        };

        let value: Value = serde_json::from_slice(&raw)
            .map_err(|error| io::Error::new(io::ErrorKind::InvalidData, error))?;
        let encoded = escape_inline_json(serde_json::to_string(&value).map_err(io::Error::other)?);
        let replacement = format!("const GAME_DATA =\n{encoded}\n; /*__GAME_DATA_PLACEHOLDER__*/");

        Ok(TEMPLATE_HTML.replacen(GAME_DATA_TOKEN, &replacement, 1))
    }

    pub fn handle_ipc(&self, body: &str) -> io::Result<()> {
        if body.len() > MAX_SETTING_BYTES {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "settings message is too large",
            ));
        }

        let message: SaveMessage = serde_json::from_str(body)
            .map_err(|error| io::Error::new(io::ErrorKind::InvalidData, error))?;
        if !allowed_setting(&message.key) {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "unsupported settings key",
            ));
        }

        let bytes = {
            let mut settings = self
                .settings
                .lock()
                .map_err(|_| io::Error::other("settings lock is poisoned"))?;
            if message.value.is_empty() {
                settings.remove(&message.key);
            } else {
                settings.insert(message.key, message.value);
            }
            let mut bytes = serde_json::to_vec_pretty(&*settings).map_err(io::Error::other)?;
            bytes.push(b'\n');
            bytes
        };

        write_settings(&self.settings_path, &bytes)
    }

    pub fn open_browser_fallback(&self) -> io::Result<PathBuf> {
        let output = self.application_dir.join(FALLBACK_NAME);
        fs::write(&output, self.build_page()?)?;
        open::that(&output).map_err(io::Error::other)?;
        Ok(output)
    }

    pub fn write_error_log(&self, native_error: &str, fallback_error: Option<&str>) {
        let mut message =
            format!("Deck Shelf could not start its native webview:\n{native_error}\n");
        if let Some(error) = fallback_error {
            message.push_str("\nThe browser fallback also failed:\n");
            message.push_str(error);
            message.push('\n');
        }
        let _ = fs::write(self.application_dir.join("deck-shelf-error.log"), message);
    }
}

fn load_settings(path: &Path) -> BTreeMap<String, String> {
    fs::read(path)
        .ok()
        .and_then(|bytes| serde_json::from_slice(&bytes).ok())
        .unwrap_or_default()
}

fn allowed_setting(key: &str) -> bool {
    matches!(
        key,
        "shelf.data" | "shelf.favs" | "shelf.recent" | "shelf.state" | "shelf.theme"
    )
}

fn escape_inline_json(mut json: String) -> String {
    for (character, escaped) in [
        ('&', "\\u0026"),
        ('<', "\\u003c"),
        ('>', "\\u003e"),
        ('\u{2028}', "\\u2028"),
        ('\u{2029}', "\\u2029"),
    ] {
        json = json.replace(character, escaped);
    }
    json
}

fn write_settings(path: &Path, bytes: &[u8]) -> io::Result<()> {
    let temporary = path.with_extension(format!("json.{}.tmp", std::process::id()));
    let mut file = File::create(&temporary)?;
    file.write_all(bytes)?;
    file.sync_all()?;

    if path.exists() {
        fs::remove_file(path)?;
    }
    fs::rename(&temporary, path)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    #[test]
    fn inline_json_cannot_close_the_script_element() {
        let encoded = escape_inline_json("{\"name\":\"</script>&\"}".into());
        assert_eq!(encoded, "{\"name\":\"\\u003c/script\\u003e\\u0026\"}");
    }

    #[test]
    fn settings_allowlist_is_exact() {
        assert!(allowed_setting("shelf.theme"));
        assert!(!allowed_setting("shelf.theme.extra"));
        assert!(!allowed_setting("__proto__"));
    }

    #[test]
    fn settings_round_trip_through_the_portable_file() {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("system clock is before the Unix epoch")
            .as_nanos();
        let directory = std::env::temp_dir().join(format!(
            "deck-shelf-settings-test-{}-{nonce}",
            std::process::id()
        ));
        fs::create_dir(&directory).expect("create test directory");
        let settings_path = directory.join(SETTINGS_NAME);
        let state = AppState {
            application_dir: directory.clone(),
            library_path: directory.join(DEFAULT_LIBRARY_NAME),
            settings_path: settings_path.clone(),
            settings: Arc::new(Mutex::new(BTreeMap::new())),
        };

        state
            .handle_ipc(r#"{"key":"shelf.theme","value":"dark"}"#)
            .expect("save setting");
        assert_eq!(
            load_settings(&settings_path).get("shelf.theme"),
            Some(&"dark".to_owned())
        );

        state
            .handle_ipc(r#"{"key":"shelf.theme","value":""}"#)
            .expect("delete setting");
        assert!(!load_settings(&settings_path).contains_key("shelf.theme"));
        fs::remove_dir_all(directory).expect("remove test directory");
    }
}
