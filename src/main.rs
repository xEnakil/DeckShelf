#![cfg_attr(target_os = "windows", windows_subsystem = "windows")]

mod app;

use app::{AppState, APP_NAME, CONTENT_SECURITY_POLICY};
use std::{borrow::Cow, error::Error};
use tao::{
    dpi::LogicalSize,
    event::{Event, WindowEvent},
    event_loop::{ControlFlow, EventLoop},
    window::{Icon, WindowBuilder},
};
use wry::{
    http::{header, Response},
    WebContext, WebViewBuilder,
};

fn main() {
    let state = match AppState::discover() {
        Ok(state) => state,
        Err(error) => {
            eprintln!("{APP_NAME}: {error}");
            return;
        }
    };

    if let Err(error) = run_native(state.clone()) {
        let fallback = state.open_browser_fallback();
        state.write_error_log(
            &error.to_string(),
            fallback
                .as_ref()
                .err()
                .map(|fallback_error| fallback_error.to_string())
                .as_deref(),
        );
    }
}

fn run_native(state: AppState) -> Result<(), Box<dyn Error>> {
    let event_loop = EventLoop::new();
    let window = WindowBuilder::new()
        .with_title(APP_NAME)
        .with_inner_size(LogicalSize::new(1280.0, 880.0))
        .with_min_inner_size(LogicalSize::new(760.0, 560.0))
        .with_window_icon(window_icon())
        .build(&event_loop)?;

    let protocol_state = state.clone();
    let ipc_state = state.clone();
    let mut web_context = WebContext::new(Some(state.cache_dir()));
    let builder = WebViewBuilder::new_with_web_context(&mut web_context)
        .with_custom_protocol(
            "deckshelf".into(),
            move |_webview_id, _request| match protocol_state.build_page() {
                Ok(page) => Response::builder()
                    .header(header::CONTENT_TYPE, "text/html; charset=utf-8")
                    .header(header::CACHE_CONTROL, "no-store")
                    .header("Content-Security-Policy", CONTENT_SECURITY_POLICY)
                    .body(page.into_bytes())
                    .expect("valid page response")
                    .map(Cow::Owned),
                Err(error) => Response::builder()
                    .status(500)
                    .header(header::CONTENT_TYPE, "text/plain; charset=utf-8")
                    .body(error.to_string().into_bytes())
                    .expect("valid error response")
                    .map(Cow::Owned),
            },
        )
        .with_initialization_script(state.initialization_script())
        .with_ipc_handler(move |request| {
            let _ = ipc_state.handle_ipc(request.body());
        })
        .with_navigation_handler(|url| {
            url.starts_with("deckshelf://")
                || url.starts_with("http://deckshelf.")
                || url.starts_with("https://deckshelf.")
        })
        .with_url("deckshelf://localhost/");

    #[cfg(any(target_os = "windows", target_os = "macos"))]
    let webview = builder.build(&window)?;

    #[cfg(target_os = "linux")]
    let webview = {
        use tao::platform::unix::WindowExtUnix;
        use wry::WebViewBuilderExtUnix;

        let container = window
            .default_vbox()
            .ok_or_else(|| std::io::Error::other("GTK window container is unavailable"))?;
        builder.build_gtk(container)?
    };

    #[allow(unreachable_code)]
    {
        event_loop.run(move |event, _, control_flow| {
            let _keep_alive = (&webview, &web_context);
            *control_flow = ControlFlow::Wait;

            if let Event::WindowEvent {
                event: WindowEvent::CloseRequested,
                ..
            } = event
            {
                *control_flow = ControlFlow::Exit;
            }
        });
        Ok(())
    }
}

fn window_icon() -> Option<Icon> {
    let image = image::load_from_memory(include_bytes!("../assets/deck-shelf.png")).ok()?;
    let rgba = image.into_rgba8();
    let (width, height) = rgba.dimensions();
    Icon::from_rgba(rgba.into_raw(), width, height).ok()
}
