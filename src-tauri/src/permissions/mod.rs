//! Full-disk/indexing permission status, surfaced to the onboarding screen
//! (`findra_mockup_permission_onboarding.png`).
//!
//! The permission that matters is granted to the **daemon binary**, not
//! this app (PRD §八: "操作系统权限授予的是 daemon 二进制而不是 App 图标本身").
//! `findra_protocol`'s `IndexStats.watch_status` (per-path real-time-vs-
//! periodic, which degrades when a path couldn't be watched/scanned for
//! permission reasons) is the one live signal a daemon actually reports
//! today, so it's preferred whenever the daemon is reachable. Each
//! platform submodule supplies only the pre-daemon heuristic used on first
//! launch, before anything has scanned anything to report a signal at all.

#[cfg(target_os = "macos")]
mod macos;
#[cfg(target_os = "linux")]
mod linux;
#[cfg(target_os = "windows")]
mod windows;

use crate::ipc_client;
use findra_protocol::{DaemonRequest, DaemonResponse};
use serde::Serialize;
use specta::Type;

#[derive(Debug, Clone, Copy, Serialize, Type)]
#[serde(rename_all = "lowercase")]
pub enum Platform {
    Macos,
    Windows,
    Linux,
}

impl Platform {
    fn current() -> Self {
        if cfg!(target_os = "macos") {
            Platform::Macos
        } else if cfg!(target_os = "windows") {
            Platform::Windows
        } else {
            Platform::Linux
        }
    }
}

#[derive(Debug, Clone, Serialize, Type)]
pub struct PermissionStatus {
    pub platform: Platform,
    pub granted: bool,
    /// True once this is a real daemon-reported signal rather than the
    /// pre-scan heuristic - the onboarding UI uses this to distinguish
    /// "confirmed missing" from "haven't checked yet".
    pub confirmed: bool,
    /// Paths the daemon could only watch periodically rather than in real
    /// time, when `confirmed` is true - lets the UI name what's degraded
    /// instead of a blanket warning.
    pub degraded_paths: Vec<String>,
}

pub async fn check() -> PermissionStatus {
    let platform = Platform::current();

    if let Ok(DaemonResponse::Status(stats)) = ipc_client::send_request(DaemonRequest::Status).await {
        let degraded_paths: Vec<String> = stats
            .watch_status
            .iter()
            .filter(|(_, live)| !live)
            .map(|(path, _)| path.display().to_string())
            .collect();
        return PermissionStatus {
            platform,
            granted: degraded_paths.is_empty(),
            confirmed: true,
            degraded_paths,
        };
    }

    PermissionStatus {
        platform,
        granted: platform_heuristic_granted(),
        confirmed: false,
        degraded_paths: Vec::new(),
    }
}

#[cfg(target_os = "macos")]
fn platform_heuristic_granted() -> bool {
    macos::heuristic_granted()
}

#[cfg(target_os = "windows")]
fn platform_heuristic_granted() -> bool {
    windows::heuristic_granted()
}

#[cfg(target_os = "linux")]
fn platform_heuristic_granted() -> bool {
    linux::heuristic_granted()
}
