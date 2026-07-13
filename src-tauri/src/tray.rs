//! Menu bar (macOS) / system tray (Windows, Linux) icon and dropdown,
//! matching `findra_mockup_menubar.png`: index summary header, "打开搜索窗"
//! (Open search window), "重建索引" (Rebuild index), "偏好设置…"
//! (Preferences), "退出 findra" (Quit).
//!
//! Same menu structure on all three platforms per PRD §7.5 - only the
//! surrounding chrome (macOS menu bar vs. Windows/Linux tray) differs, and
//! that's the OS's rendering, not something this code varies.

use crate::ipc_client;
use crate::window;
use findra_protocol::{DaemonRequest, DaemonResponse};
use tauri::menu::{Menu, MenuItem, PredefinedMenuItem};
use tauri::tray::TrayIconBuilder;
use tauri::AppHandle;

const OPEN_SEARCH: &str = "open_search";
const REBUILD_INDEX: &str = "rebuild_index";
const PREFERENCES: &str = "preferences";

pub fn build(app: &AppHandle) -> tauri::Result<()> {
    let menu = rebuild_menu(app, None)?;

    let _tray = TrayIconBuilder::with_id("main-tray")
        .icon(app.default_window_icon().unwrap().clone())
        .icon_as_template(true)
        .menu(&menu)
        .tooltip("Findra")
        .on_menu_event(move |app, event| match event.id.as_ref() {
            OPEN_SEARCH => window::show_main(app),
            REBUILD_INDEX => {
                let app = app.clone();
                tauri::async_runtime::spawn(async move {
                    let _ = ipc_client::send_request(DaemonRequest::Index(dirs_home_or_root())).await;
                    let _ = app; // reserved for a toast/notification on completion
                });
            }
            PREFERENCES => window::show_preferences(app),
            _ => {}
        })
        .build(app)?;

    Ok(())
}

/// Rebuilds the tray menu with a fresh "已索引 N 个文件" header - called on
/// tray click as well as build time so the count doesn't go stale while the
/// dropdown is closed (PRD calls this the highest-frequency entry point,
/// so it's worth keeping current rather than only refreshing on app focus).
pub fn rebuild_menu(app: &AppHandle, indexed_count: Option<u64>) -> tauri::Result<Menu<tauri::Wry>> {
    let header_text = match indexed_count {
        Some(n) => format!("已索引 {n} 个文件"),
        None => "索引状态未知".to_string(),
    };
    let header = MenuItem::with_id(app, "header", header_text, false, None::<&str>)?;
    let open_search = MenuItem::with_id(app, OPEN_SEARCH, "打开搜索窗", true, Some("Alt+Space"))?;
    let rebuild = MenuItem::with_id(app, REBUILD_INDEX, "重建索引", true, None::<&str>)?;
    let prefs = MenuItem::with_id(app, PREFERENCES, "偏好设置…", true, Some("CmdOrCtrl+,"))?;
    let separator = PredefinedMenuItem::separator(app)?;
    let quit = PredefinedMenuItem::quit(app, Some("退出 findra"))?;

    Menu::with_items(
        app,
        &[&header, &open_search, &rebuild, &prefs, &separator, &quit],
    )
}

pub async fn refresh_header(app: &AppHandle) {
    let count = match ipc_client::send_request(DaemonRequest::Status).await {
        Ok(DaemonResponse::Status(stats)) => Some(stats.total_files),
        _ => None,
    };
    if let (Ok(menu), Some(tray)) = (rebuild_menu(app, count), app.tray_by_id("main-tray")) {
        let _ = tray.set_menu(Some(menu));
    }
}

fn dirs_home_or_root() -> String {
    std::env::var("HOME").unwrap_or_else(|_| "/".to_string())
}
