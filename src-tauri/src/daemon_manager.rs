//! Daemon discovery/bootstrap for the two distribution modes from the PRD
//! (`findra_完整需求设计说明书.md` §6.1, `findra-app` design doc §4.1):
//!
//! - **CLI-enhanced**: the user already has the `findra` CLI installed and
//!   its daemon is running. We must never touch its service registration
//!   (`launchd`/systemd/Windows service) - only read the socket.
//! - **Standalone**: no CLI present. This app's own bundled daemon binary
//!   (a Tauri sidecar resource under `vendor-bin/`) is spawned and managed
//!   by this app.
//!
//! Detection is by outcome, not installer bookkeeping: whichever binary
//! ends up serving the socket, `is_running`/`send_request` don't need to
//! know or care which mode produced it.

use crate::ipc_client;
use findra_protocol::DaemonRequest;
use std::path::PathBuf;
use std::process::Stdio;

#[derive(Debug, Clone)]
pub enum DaemonSource {
    /// A `findra` binary already on PATH - the CLI-enhanced case. Reusing
    /// the user's own install means the daemon and any `findra` command
    /// they run themselves can never drift to different versions.
    ExistingCliInstall(PathBuf),
    /// This app's bundled sidecar binary - the standalone case.
    BundledBinary(PathBuf),
}

fn locate(app: &tauri::AppHandle) -> anyhow::Result<DaemonSource> {
    if let Ok(path) = which::which("findra") {
        return Ok(DaemonSource::ExistingCliInstall(path));
    }

    use tauri::Manager;
    let resource_dir = app.path().resource_dir()?;
    let bundled = resource_dir.join("vendor-bin").join(if cfg!(windows) {
        "findra.exe"
    } else {
        "findra"
    });
    if bundled.exists() {
        return Ok(DaemonSource::BundledBinary(bundled));
    }

    anyhow::bail!(
        "no findra binary found on PATH or bundled at {}",
        bundled.display()
    )
}

/// Spawns `findra index --daemon`, detached from this app's process group
/// so the daemon outlives the app (PRD: "App 退出后 daemon 继续运行" - CLI
/// users may depend on the same daemon staying up). Doesn't wait for the
/// scan to finish; `ipc_client::send_request` already retries/waits for
/// the socket to appear.
fn spawn(source: &DaemonSource) -> anyhow::Result<()> {
    let binary = match source {
        DaemonSource::ExistingCliInstall(path) | DaemonSource::BundledBinary(path) => path,
    };

    let mut cmd = std::process::Command::new(binary);
    cmd.args(["index", "--daemon"])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());

    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        cmd.process_group(0);
    }

    cmd.spawn()?;
    Ok(())
}

/// Starts the daemon if nothing answers yet. Called once at app startup;
/// safe to call again (e.g. before a "rebuild index" action).
pub async fn ensure_running(app: &tauri::AppHandle) -> anyhow::Result<DaemonSource> {
    let source = locate(app)?;
    if !ipc_client::is_running().await {
        spawn(&source)?;
    }
    Ok(source)
}

pub async fn rebuild_index(path: String) -> Result<(), ipc_client::DaemonError> {
    match ipc_client::send_request(DaemonRequest::Index(path)).await? {
        findra_protocol::DaemonResponse::IndexStarted => Ok(()),
        other => Err(ipc_client::DaemonError::Io(std::io::Error::other(format!(
            "unexpected daemon response to Index: {other:?}"
        )))),
    }
}
