mod commands;
mod daemon_manager;
mod ipc_client;
mod permissions;
mod tray;
mod window;

use tauri::Manager;
use tauri_plugin_global_shortcut::{GlobalShortcutExt, Shortcut, ShortcutState};

/// `⌥Space` (Alt+Space) on all three platforms, matching the mockup and
/// deliberately avoiding `⌘Space`/`Win+Space`, which are the OS's own
/// Spotlight/search shortcuts (PRD §6.5).
const TOGGLE_SEARCH_SHORTCUT: &str = "Alt+Space";

fn specta_builder() -> tauri_specta::Builder {
    tauri_specta::Builder::<tauri::Wry>::new().commands(tauri_specta::collect_commands![
        commands::search,
        commands::status,
        commands::rebuild_index,
        commands::check_permission,
        commands::ensure_daemon,
        commands::get_platform,
        commands::check_protocol_version,
    ])
}

/// Writes `../src/lib/bindings.ts` from the command/type signatures above -
/// no hand-written `.d.ts`, no JSON-Schema/codegen middleman (see
/// `commands.rs`'s doc comment). Callable standalone via the
/// `export_bindings` bin target (`cargo run --bin export_bindings`, no GUI
/// needed) for CI/fresh-checkout use, and also invoked from `run()` on
/// every debug build so local `tauri dev` keeps it current automatically.
pub fn export_bindings() {
    // u64/i64 fields (FileEntry::id/size, IndexStats::total_files, mtime/
    // ctime timestamps, ...) export as TS `number` rather than `bigint`.
    // Loses precision above 2^53 - not reachable for these fields in
    // practice (file counts/sizes/unix timestamps), and matches how the
    // JSON wire format already represents them (serde_json has the same
    // f64-based limit for these values today, so this isn't a new
    // constraint the TS binding introduces).
    let ts = specta_typescript::Typescript::default()
        .bigint(specta_typescript::BigIntExportBehavior::Number);
    specta_builder()
        .export(ts, "../src/lib/bindings.ts")
        .expect("failed to export TypeScript bindings");
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let builder = specta_builder();

    // Kept current automatically on every local `tauri dev`/debug run;
    // release builds skip this (no dev toolchain assumption at bundle
    // time) and rely on the committed file instead - see
    // `export_bindings()`'s doc comment for the CI-facing path.
    #[cfg(debug_assertions)]
    export_bindings();

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            None,
        ))
        .plugin(
            tauri_plugin_global_shortcut::Builder::new()
                .with_handler(|app, shortcut, event| {
                    let toggle: Shortcut = TOGGLE_SEARCH_SHORTCUT.parse().expect("valid shortcut");
                    if event.state() == ShortcutState::Pressed && *shortcut == toggle {
                        window::toggle_main(app);
                    }
                })
                .build(),
        )
        .invoke_handler(builder.invoke_handler())
        .setup(move |app| {
            builder.mount_events(app);

            let handle = app.handle().clone();

            tray::build(&handle)?;

            let shortcut: Shortcut = TOGGLE_SEARCH_SHORTCUT.parse()?;
            app.global_shortcut().register(shortcut)?;

            // Daemon bootstrap + the first tray-header refresh happen after
            // startup rather than blocking `setup` - a cold daemon can take
            // a while to finish its initial scan, and the window/tray
            // should be interactive immediately (the search UI shows its
            // own "daemon starting…" state via `status`/`ensure_daemon`).
            tauri::async_runtime::spawn({
                let app = handle.clone();
                async move {
                    let _ = daemon_manager::ensure_running(&app).await;
                    tray::refresh_header(&app).await;
                }
            });

            if let Some(main) = app.get_webview_window("main") {
                let _ = main.show();
            }

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
