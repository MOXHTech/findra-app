//! Window show/hide/create helpers shared by the tray menu and the global
//! shortcut handler - both need "bring the search window to front" and
//! "open (or focus) preferences" as one-liners.

use tauri::{AppHandle, Manager, WebviewUrl, WebviewWindowBuilder};

pub fn show_main(app: &AppHandle) {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.show();
        let _ = window.set_focus();
    }
}

pub fn toggle_main(app: &AppHandle) {
    if let Some(window) = app.get_webview_window("main") {
        let visible = window.is_visible().unwrap_or(false);
        if visible {
            let _ = window.hide();
        } else {
            let _ = window.show();
            let _ = window.set_focus();
        }
    }
}

/// Preferences (`findra_mockup_preferences.png`) is a distinct window
/// rather than a tab/modal in the main search window, matching the mockup's
/// own title bar and the platform convention (macOS `Cmd+,` opens a
/// separate Settings window, not an in-window panel).
pub fn show_preferences(app: &AppHandle) {
    if let Some(window) = app.get_webview_window("preferences") {
        let _ = window.show();
        let _ = window.set_focus();
        return;
    }

    let _ = WebviewWindowBuilder::new(app, "preferences", WebviewUrl::App("preferences.html".into()))
        .title("偏好设置")
        .inner_size(640.0, 520.0)
        .resizable(false)
        .build();
}
