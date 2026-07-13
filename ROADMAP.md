# Findra Desktop App — Roadmap

Status snapshot as of this doc's last edit. Scope is the Desktop App only (`findra-app`); the core engine/CLI's own roadmap (including the eBPF-based Linux provider upgrade described in `findra/prd/findra_eBPF-ETW增强设计文档.md`) lives in the `findra` repo and is out of scope here.

## Done

| Area | What shipped |
|---|---|
| Protocol decoupling | Depends only on `findra-protocol` (git+tag pinned), never on `findra`'s core/CLI source - see README's "Stack" section and `src-tauri/src/ipc_client.rs` |
| IPC transport | `ipc_client.rs`: own Unix-socket/named-pipe client built on `findra_protocol::codec`, with `NotRunning`/`Timeout` error handling |
| Daemon lifecycle | `daemon_manager.rs`: detects an already-running daemon, or locates/spawns `findra-daemon` (PATH, sibling-of-CLI, or bundled `vendor-bin/`) - covers both "CLI-enhanced" and "standalone" distribution modes |
| Protocol version check | `commands::check_protocol_version`, surfaced in the About tab |
| Main window | Table view: search box (debounced, search-as-you-type), sidebar category filters with live counts, 5-column sortable table (name/path/size/created/modified), status bar (match count, index freshness, daemon health) |
| Tray/menu bar | Native tray icon + dropdown (index count header, open search window, rebuild index, preferences, quit) - `tray.rs` |
| Global shortcut | `⌥Space` toggles the search window - `lib.rs` |
| Permission onboarding | Platform-conditional copy (macOS Full Disk Access / Windows admin+ETW / Linux CAP_BPF+CAP_PERFMON), "open settings" deep link on macOS, skippable with a clear cost warning |
| Preferences window | Separate window, 5 tabs: General (autostart toggle), Search (informational), Excluded Directories (functional: list/add via native folder picker/remove, restart-daemon action), Shortcuts (read-only display), About (version/platform/protocol status) |
| TS bindings | Generated end-to-end from Rust command/type signatures via `tauri-specta`/`specta` - verified via `cargo run --example export_bindings` and a full `npm run build` |
| Packaging config | `tauri.conf.json` bundle targets for macOS/Windows/Linux; `.github/workflows/release.yml` matrix build (macOS arm64+x64, Windows, Linux) on `v*` tag push |
| **Packaging, actually verified** | `npm run tauri build` produces a working `Findra.app` + `Findra_0.1.0_aarch64.dmg` on macOS (arm64) and the built app launches and stays running - not just a config file that's never been exercised. Caught and fixed a real bug in the process: a second Cargo `[[bin]]` target (`export_bindings`, for regenerating TS bindings without launching the GUI) made Tauri's bundler bundle *that* binary under the `Findra.app`'s main-executable name instead of the actual app, even with `mainBinaryName` set - it silently printed "Wrote bindings.ts" and exited instead of showing a window. Fixed by moving that target to a Cargo `[[example]]` (`examples/export_bindings.rs`, run via `cargo run --example export_bindings`), which Tauri's bundler never considers - see git history for the full before/after. Windows/Linux bundle targets are configured but unverified (this dev environment is macOS-only) - the CI matrix build is the only thing that will exercise them, so watch its first real run closely. |
| Auto-update | `tauri-plugin-updater` wired up against a real (password-protected) signing keypair (private key at `~/.tauri/findra-app-updater.key` on this machine, outside the repo); `src/lib/useAutoUpdate.ts` checks once per launch, downloads silently, and surfaces a dismissible "restart to update" banner in the main window rather than auto-relaunching out from under the user |

## Known gaps / next up

1. **App icon.** Still the default Tauri template icon - needs `findra/prd/findra_macos_appicon.svg` rendered to a 1024×1024 PNG (a design tool pass, not an engineering task) and run through `tauri icon`.
2. **Code signing & notarization.** `release.yml` has no Apple Developer / EV certificate wiring yet - CI currently produces unsigned artifacts. Needed before any real distribution (macOS Gatekeeper will block an unsigned/unnotarized `.app` on another machine).
3. **`config.*` IPC method.** Excluded Directories currently edits `~/.findra/config.toml` directly from the Rust shell (see `config_file.rs`) because the daemon has no dedicated config-read/write IPC method - functional, but requires a manual daemon restart to take effect. Adding `DaemonRequest::Config{Get,Set,Exclude,Include}` to `findra-protocol` (and implementing it in `findra-daemon`) would let this become a live round trip with no restart - a `findra`-repo change, tracked here since it's this app's own UX that benefits.
4. **Result virtualization.** The results table renders every returned row directly (no `react-virtual`/windowing) - fine at the current `limit: 300`, would need revisiting if that cap is raised for very large indexes.
5. **Category filter is approximate.** Sidebar counts/filtering are computed client-side from the already-limited result page, except for document/image/application (which could be pushed server-side via `SearchQuery.extensions` but aren't yet) - a large true result set beyond the fetch limit won't be reflected in the counts.
6. **No automated tests.** Neither the Rust shell nor the React frontend has a test suite yet.
7. **Three-column preview layout (§7.2 of the main PRD)** is documented as an alternate/optional main-window layout, not built - the table view is the PRD's stated default/recommended layout.

## Milestones this repo has already passed (for historical context)

Matches `findra/prd-app/findra-app_独立仓库开发设计文档.md`'s milestone table (M0–M8): M0 (protocol dependency wired up) through M6 (Preferences + persistence) are functionally done, ahead of that doc's original estimate, because M2 (daemon lifecycle) and M3–M6 (frontend) were built in parallel rather than strictly sequenced. M7 (packaging CI) has a working matrix build; signing/notarization (part of M7) and M8 (protocol-compatibility/distribution-matrix testing) remain.
