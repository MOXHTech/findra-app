//! Transport for talking to the findra daemon: this app's own Unix-socket/
//! named-pipe client, built on `findra_protocol`'s wire types and frame
//! codec. Deliberately *not* a dependency on `findra::ipc::IpcClient` - per
//! `findra/prd-app`'s "findra-app 独立仓库开发设计文档" §1.2, this repo
//! doesn't depend on the core engine/CLI's source at all, only on the
//! versioned protocol crate. The transport code below (~60 lines) is the
//! price of that decoupling; the parts most prone to silent drift - the
//! request/response shapes and the length-prefix framing - come from
//! `findra_protocol` instead of being hand-copied, which is what actually
//! matters for staying in sync with the daemon.

use findra_protocol::{codec, DaemonRequest, DaemonResponse};
use tokio::io::{AsyncReadExt, AsyncWriteExt};

#[derive(thiserror::Error, Debug)]
pub enum DaemonError {
    #[error("findra daemon is not running (no socket at {0})")]
    NotRunning(String),
    #[error("request to findra daemon timed out")]
    Timeout,
    #[error(transparent)]
    Codec(#[from] codec::CodecError),
    #[error(transparent)]
    Io(#[from] std::io::Error),
}

/// Must match `findra::ipc::get_socket_path()` exactly - the one part of
/// talking to the daemon that's a filesystem convention rather than
/// something `findra_protocol` can express as a serde type.
pub fn socket_path() -> String {
    #[cfg(unix)]
    {
        format!(
            "{}/.findra/daemon.sock",
            std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string())
        )
    }
    #[cfg(windows)]
    {
        r"\\.\pipe\findra_daemon".to_string()
    }
}

const WRITE_TIMEOUT: std::time::Duration = std::time::Duration::from_secs(30);
/// 120s: a freshly (re)started daemon can spend a while deserializing a
/// large persisted index before its accept loop is ready to reply, even
/// though the connection itself lands immediately.
const READ_TIMEOUT: std::time::Duration = std::time::Duration::from_secs(120);

async fn write_frame<W: AsyncWriteExt + Unpin>(writer: &mut W, request: &DaemonRequest) -> Result<(), DaemonError> {
    let framed = codec::encode(request)?;
    writer.write_all(&framed).await?;
    writer.flush().await?;
    Ok(())
}

async fn read_frame<R: AsyncReadExt + Unpin>(reader: &mut R) -> Result<DaemonResponse, DaemonError> {
    let mut len_buf = [0u8; 4];
    reader.read_exact(&mut len_buf).await?;
    let len = codec::frame_len(len_buf)?;
    let mut data = vec![0u8; len as usize];
    reader.read_exact(&mut data).await?;
    Ok(codec::decode(&data)?)
}

/// Connects, sends one request, and returns the response. A fresh
/// connection per call (rather than a held-open one) matches the daemon's
/// own expectation - the CLI talks to it the same way, one connection per
/// `findra search`/`findra status` invocation.
pub async fn send_request(request: DaemonRequest) -> Result<DaemonResponse, DaemonError> {
    let path = socket_path();

    #[cfg(unix)]
    {
        if !std::path::Path::new(&path).exists() {
            return Err(DaemonError::NotRunning(path));
        }
        let mut stream = tokio::net::UnixStream::connect(&path).await?;
        tokio::time::timeout(WRITE_TIMEOUT, write_frame(&mut stream, &request))
            .await
            .map_err(|_| DaemonError::Timeout)??;
        tokio::time::timeout(READ_TIMEOUT, read_frame(&mut stream))
            .await
            .map_err(|_| DaemonError::Timeout)?
    }

    #[cfg(windows)]
    {
        use tokio::net::windows::named_pipe::ClientOptions;
        let mut client = match ClientOptions::new().open(&path) {
            Ok(c) => c,
            Err(_) => return Err(DaemonError::NotRunning(path)),
        };
        tokio::time::timeout(WRITE_TIMEOUT, write_frame(&mut client, &request))
            .await
            .map_err(|_| DaemonError::Timeout)??;
        tokio::time::timeout(READ_TIMEOUT, read_frame(&mut client))
            .await
            .map_err(|_| DaemonError::Timeout)?
    }
}

/// True if a daemon is already listening and answers a `Status` request -
/// the only signal `daemon_manager` uses to decide whether to spawn one.
pub async fn is_running() -> bool {
    matches!(send_request(DaemonRequest::Status).await, Ok(DaemonResponse::Status(_)))
}

/// Compares the daemon's reported `IndexStats::protocol_version` against
/// the version of `findra_protocol` this app was built against. An empty
/// string means a pre-versioning daemon (treat as unknown, not fatal - see
/// `findra_protocol::IndexStats::protocol_version`'s doc comment). Mismatch
/// is surfaced to the UI as a prompt to upgrade rather than silently
/// pressing on with a daemon that might not understand new request shapes.
pub fn check_version_compat(daemon_version: &str) -> VersionCompat {
    if daemon_version.is_empty() {
        VersionCompat::Unknown
    } else if daemon_version == findra_protocol::PROTOCOL_VERSION {
        VersionCompat::Match
    } else {
        VersionCompat::Mismatch {
            daemon: daemon_version.to_string(),
            app: findra_protocol::PROTOCOL_VERSION.to_string(),
        }
    }
}

#[derive(Debug, Clone, serde::Serialize, specta::Type)]
#[serde(tag = "kind")]
pub enum VersionCompat {
    Match,
    Unknown,
    Mismatch { daemon: String, app: String },
}
