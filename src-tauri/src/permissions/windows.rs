//! Windows: the daemon needs administrator privilege to start an ETW
//! session (`SeSystemProfilePrivilege`). There's no same-process proxy for
//! "will a *separate* elevated process be able to start", so this assumes
//! granted on first launch and lets the real daemon-reported
//! `watch_status` (see `super::check`) correct it once indexing starts.

pub fn heuristic_granted() -> bool {
    true
}
