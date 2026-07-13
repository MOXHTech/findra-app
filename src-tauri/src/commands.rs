//! Tauri commands: the only surface the TypeScript frontend calls through.
//! Each one is a thin forward to either the daemon IPC protocol or a local
//! platform query - no business logic lives here, matching the PRD's
//! "TS 前端只管 UI 渲染...findra daemon 才是真正做事的地方" split.
//!
//! `#[specta::specta]` on every command plus `tauri_specta::Builder` in
//! `lib.rs` is what generates `../src/lib/bindings.ts` - request/response
//! types included, no hand-written `.d.ts` to keep in sync by hand.

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
