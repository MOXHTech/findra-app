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
//!
//! `findra`'s daemon is a separate binary, `findra-daemon`, that takes no
//! arguments and just loads `~/.findra/config.toml` (defaulting to
//! scanning `$HOME` if that file doesn't exist yet) - it is *not* the same
//! `findra` binary the CLI's `index`/`search`/`status` subcommands live in.
//! This app never writes that config file itself (doing so would duplicate
//! `findra-core::config::Config`'s TOML shape here, which is exactly the
//! kind of protocol-vs-source-dependency this repo is trying to avoid) -
//! `rebuild_index` asks an already-running daemon to scan a specific path
//! over IPC instead, and first-launch standalone users get the same
//! `$HOME` default a fresh CLI install would.

use crate::ipc_client;
use findra_protocol::DaemonRequest;
use std::path::PathBuf;
use std::process::Stdio;

const DAEMON_BIN_NAME: &str = if cfg!(windows) { "findra-daemon.exe" } else { "findra-daemon" };

#[derive(Debug, Clone)]
pub enum DaemonSource {
    /// `findra-daemon` found on PATH, or next to a `findra` CLI binary on
    /// PATH - the CLI-enhanced case. Reusing the user's own install means
    /// the daemon and any `findra` command they run themselves can never
    /// drift to different versions.
    ExistingCliInstall(PathBuf),
    /// This app's bundled sidecar binary - the standalone case.
    BundledBinary(PathBuf),
}

fn locate(app: &tauri::AppHandle) -> anyhow::Result<DaemonSource> {
    if let Ok(path) = which::which(DAEMON_BIN_NAME) {
        return Ok(DaemonSource::ExistingCliInstall(path));
    }

    // `findra-daemon` may not itself be on PATH even when the CLI is -
    // findra-cli's own install looks for it as a sibling of its own
    // executable rather than requiring a second PATH entry, so mirror that
    // lookup here instead of only checking PATH directly.
    if let Ok(cli_path) = which::which("findra") {
        if let Some(dir) = cli_path.parent() {
            let sibling = dir.join(DAEMON_BIN_NAME);
            if sibling.exists() {
                return Ok(DaemonSource::ExistingCliInstall(sibling));
            }
        }
    }

    use tauri::Manager;
    let resource_dir = app.path().resource_dir()?;
    let bundled = resource_dir.join("vendor-bin").join(DAEMON_BIN_NAME);
    if bundled.exists() {
        return Ok(DaemonSource::BundledBinary(bundled));
    }

    anyhow::bail!(
        "no {} binary found on PATH or bundled at {}",
        DAEMON_BIN_NAME,
        bundled.display()
    )
}

/// Spawns `findra-daemon` with no arguments, detached from this app's
/// process group so it outlives the app (PRD: "App 退出后 daemon 继续运行" -
/// CLI users may depend on the same daemon staying up). Doesn't wait for
/// the scan to finish; `ipc_client::send_request` already retries/waits
/// for the socket to appear.
fn spawn(source: &DaemonSource) -> anyhow::Result<()> {
    let binary = match source {
        DaemonSource::ExistingCliInstall(path) | DaemonSource::BundledBinary(path) => path,
    };

    let mut cmd = std::process::Command::new(binary);
    cmd.stdin(Stdio::null()).stdout(Stdio::null()).stderr(Stdio::null());

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

/// Asks the (already-running) daemon to scan `path` on demand - the
/// "重建索引" (rebuild index) tray/menu action. Does not touch
/// `~/.findra/config.toml`; see this module's doc comment for why.
pub async fn rebuild_index(path: String) -> Result<(), ipc_client::DaemonError> {
    match ipc_client::send_request(DaemonRequest::Index(path)).await? {
        findra_protocol::DaemonResponse::IndexStarted => Ok(()),
        other => Err(ipc_client::DaemonError::Io(std::io::Error::other(format!(
            "unexpected daemon response to Index: {other:?}"
        )))),
    }
}
