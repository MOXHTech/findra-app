//! Tauri commands: the only surface the TypeScript frontend calls through.
//! Each one is a thin forward to either the daemon IPC protocol or a local
//! platform query - no business logic lives here, matching the PRD's
//! "TS 前端只管 UI 渲染...findra daemon 才是真正做事的地方" split.
//!
//! `#[specta::specta]` on every command plus `tauri_specta::Builder` in
//! `lib.rs` is what generates `../src/lib/bindings.ts` - request/response
//! types included, no hand-written `.d.ts` to keep in sync by hand.

use crate::config_file;
use crate::daemon_manager;
use crate::ipc_client;
use crate::permissions::{self, PermissionStatus};
use findra_protocol::{DaemonRequest, DaemonResponse, FileEntry, IndexStats, SearchQuery};
use tauri::AppHandle;

#[tauri::command]
#[specta::specta]
pub async fn search(query: SearchQuery) -> Result<Vec<FileEntry>, String> {
    match ipc_client::send_request(DaemonRequest::Search(query))
        .await
        .map_err(|e| e.to_string())?
    {
        DaemonResponse::SearchResults(results) => Ok(results),
        DaemonResponse::Error(msg) => Err(msg),
        other => Err(format!("unexpected daemon response: {other:?}")),
    }
}

#[tauri::command]
#[specta::specta]
pub async fn status() -> Result<IndexStats, String> {
    match ipc_client::send_request(DaemonRequest::Status)
        .await
        .map_err(|e| e.to_string())?
    {
        DaemonResponse::Status(stats) => Ok(stats),
        DaemonResponse::Error(msg) => Err(msg),
        other => Err(format!("unexpected daemon response: {other:?}")),
    }
}

/// Kicks off (or restarts) indexing for `path`. Matches the CLI's own
/// `findra index --daemon <path>` behavior of stopping and replacing any
/// daemon already running - used by the "重建索引" tray/menu action.
#[tauri::command]
#[specta::specta]
pub async fn rebuild_index(path: String) -> Result<(), String> {
    daemon_manager::rebuild_index(path).await.map_err(|e| e.to_string())
}

#[tauri::command]
#[specta::specta]
pub async fn check_permission() -> PermissionStatus {
    permissions::check().await
}

#[tauri::command]
#[specta::specta]
pub async fn ensure_daemon(app: AppHandle) -> Result<(), String> {
    daemon_manager::ensure_running(&app).await.map(|_| ()).map_err(|e| e.to_string())
}

/// Opens (or focuses) the Preferences window - the same action the tray
/// menu's "偏好设置…" triggers, exposed as a command so the in-app gear
/// button doesn't have to reimplement window lifecycle logic on the JS
/// side (see `window.rs::show_preferences`, the single place that's
/// handled).
#[tauri::command]
#[specta::specta]
pub fn open_preferences(app: AppHandle) {
    crate::window::show_preferences(&app);
}

#[tauri::command]
#[specta::specta]
pub fn get_platform() -> String {
    std::env::consts::OS.to_string()
}

#[tauri::command]
#[specta::specta]
pub async fn check_protocol_version() -> Result<ipc_client::VersionCompat, String> {
    match ipc_client::send_request(DaemonRequest::Status)
        .await
        .map_err(|e| e.to_string())?
    {
        DaemonResponse::Status(stats) => Ok(ipc_client::check_version_compat(&stats.protocol_version)),
        DaemonResponse::Error(msg) => Err(msg),
        other => Err(format!("unexpected daemon response: {other:?}")),
    }
}

// --- Preferences: excluded directories ---
// See config_file.rs's doc comment for why this edits ~/.findra/config.toml
// directly (untyped, single-key) instead of going through an IPC method
// that doesn't exist yet.

#[tauri::command]
#[specta::specta]
pub fn get_excluded_paths() -> Result<Vec<String>, String> {
    config_file::get_excluded_paths().map_err(|e| e.to_string())
}

#[tauri::command]
#[specta::specta]
pub fn add_excluded_path(path: String) -> Result<(), String> {
    config_file::add_excluded_path(path).map_err(|e| e.to_string())
}

#[tauri::command]
#[specta::specta]
pub fn remove_excluded_path(path: String) -> Result<(), String> {
    config_file::remove_excluded_path(&path).map_err(|e| e.to_string())
}

/// Restarts the daemon so a just-edited `~/.findra/config.toml` (e.g. a
/// changed excluded-directories list) takes effect - the daemon only reads
/// that file at startup. Sends `StopDaemon` and gives it a couple seconds
/// to actually exit and release its socket/database before spawning a
/// fresh one - a simplification of findra-cli's own PID-based wait-then-
/// escalate-to-SIGKILL restart logic (`stop_running_daemon` in
/// findra-cli/src/main.rs), acceptable here since a slightly slow restart
/// just delays picking up the config change rather than losing data.
#[tauri::command]
#[specta::specta]
pub async fn restart_daemon(app: AppHandle) -> Result<(), String> {
    let _ = ipc_client::send_request(DaemonRequest::StopDaemon).await;
    tokio::time::sleep(std::time::Duration::from_secs(2)).await;
    daemon_manager::ensure_running(&app).await.map(|_| ()).map_err(|e| e.to_string())
}
