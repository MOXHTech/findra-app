//! Linux: the daemon's preferred watch mechanism needs `CAP_BPF`+
//! `CAP_PERFMON` (or root), with a fanotify/inotify degrade-chain below
//! that. No same-process proxy for a separate process's capabilities, so
//! this assumes granted on first launch and lets the real daemon-reported
//! `watch_status` (see `super::check`) correct it once indexing starts.

pub fn heuristic_granted() -> bool {
    true
}
