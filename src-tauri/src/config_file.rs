//! Reads/writes just the `excluded_paths` key of `~/.findra/config.toml` -
//! the file `findra_core::config::Config::save`/`load_or_default` also
//! read and write, but there is no IPC method for it yet (`DaemonRequest`
//! only has `Status`/`Search`/`Index`/`StopDaemon` today - see
//! `findra-protocol`). Rather than depend on `findra-core` just to get its
//! `Config` struct (which this app deliberately doesn't do - see
//! `ipc_client.rs`'s doc comment), this treats the file as an untyped TOML
//! document and only ever touches the one key it needs, leaving every
//! other key (`index_paths`, `sync_interval_secs`, ...) exactly as it found
//! them - so it can never go stale relative to `Config`'s actual field set
//! evolving on the findra side.
//!
//! The daemon only reads this file at startup, so a change here needs a
//! daemon restart to take effect - the same is already true of editing it
//! by hand alongside the CLI (see findra's README: "Editing this file
//! directly and restarting the daemon... is the fastest way").

use std::path::PathBuf;

fn config_path() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    PathBuf::from(format!("{home}/.findra/config.toml"))
}

fn load_document() -> anyhow::Result<toml::Table> {
    let path = config_path();
    if !path.exists() {
        return Ok(toml::Table::new());
    }
    let content = std::fs::read_to_string(&path)?;
    Ok(content.parse::<toml::Table>()?)
}

fn save_document(doc: &toml::Table) -> anyhow::Result<()> {
    let path = config_path();
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    std::fs::write(&path, toml::to_string_pretty(doc)?)?;
    Ok(())
}

pub fn get_excluded_paths() -> anyhow::Result<Vec<String>> {
    let doc = load_document()?;
    Ok(doc
        .get("excluded_paths")
        .and_then(|v| v.as_array())
        .map(|arr| arr.iter().filter_map(|v| v.as_str().map(String::from)).collect())
        .unwrap_or_default())
}

fn with_excluded_paths(mutate: impl FnOnce(&mut Vec<String>)) -> anyhow::Result<()> {
    let mut doc = load_document()?;
    let mut paths = doc
        .get("excluded_paths")
        .and_then(|v| v.as_array())
        .map(|arr| arr.iter().filter_map(|v| v.as_str().map(String::from)).collect())
        .unwrap_or_else(Vec::new);

    mutate(&mut paths);

    doc.insert(
        "excluded_paths".to_string(),
        toml::Value::Array(paths.into_iter().map(toml::Value::String).collect()),
    );
    save_document(&doc)
}

pub fn add_excluded_path(path: String) -> anyhow::Result<()> {
    with_excluded_paths(|paths| {
        if !paths.contains(&path) {
            paths.push(path);
        }
    })
}

pub fn remove_excluded_path(path: &str) -> anyhow::Result<()> {
    with_excluded_paths(|paths| paths.retain(|p| p != path))
}
