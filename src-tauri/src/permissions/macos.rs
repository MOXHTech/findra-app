//! macOS: Full Disk Access (TCC). No public API exists to query another
//! process's TCC grant, so this same-process heuristic is only used before
//! the daemon has reported anything real (see `super::check`) - it reads a
//! file that requires Full Disk Access as a proxy, which is not
//! authoritative for the *daemon's* own grant (a separate binary can have
//! a different TCC decision).

pub fn heuristic_granted() -> bool {
    let Some(home) = std::env::var_os("HOME").map(std::path::PathBuf::from) else {
        return false;
    };
    std::fs::metadata(home.join("Library/Application Support/com.apple.TCC/TCC.db")).is_ok()
}
