# Findra (Desktop App)

The graphical front end for [findra](https://github.com/findra/findra) - the same background daemon and index the CLI uses, with a menu-bar/tray-resident search window on top. See `findra`'s `prd-app/findra_完整需求设计说明书.md` for the full product spec.

This repo is intentionally decoupled from `findra`'s source: it depends only on [`findra-protocol`](https://github.com/findra/findra/tree/main/crates/findra-protocol), the versioned IPC contract crate, not on the core engine/CLI. See `src-tauri/src/ipc_client.rs` for why, and `findra`'s `prd-app/findra-app_独立仓库开发设计文档.md` / `findra_命令行库App整洁架构设计.md` for the design rationale.

## Stack

Tauri 2 (Rust shell) + React + TypeScript + Vite + Tailwind CSS v4. TS types and typed `invoke()` wrappers (`src/lib/bindings.ts`) are generated directly from the Rust command signatures via `tauri-specta`/`specta` - no hand-written `.d.ts`, no JSON-Schema/codegen middleman.

## Development

```bash
npm install
npm run tauri dev
```

The daemon (`findra-daemon`, a separate binary from the `findra` CLI) must be reachable for search results to appear - this app finds one already running, or looks for `findra-daemon` on PATH / bundled under `vendor-bin/` and spawns it (see `src-tauri/src/daemon_manager.rs`). Building `findra-daemon` from the sibling `findra` repo and putting it on PATH is the easiest way to develop against a real daemon.

Regenerate `src/lib/bindings.ts` without launching the GUI (e.g. after changing a command signature, or on a fresh clone before the frontend can typecheck):

```bash
cd src-tauri && cargo run --example export_bindings
```

## Project structure

```
src/
├── App.tsx                    Main window root: onboarding gate -> SearchWindow
├── preferences-main.tsx       Separate entry for the Preferences window
├── features/
│   ├── search/                Main window: toolbar, sidebar filters, results table, status bar
│   ├── onboarding/            Full-disk-access / admin / CAP_BPF permission onboarding screen
│   └── preferences/           Preferences window: General/Search/Excluded Directories/Shortcuts/About tabs
└── lib/
    ├── bindings.ts             Generated - do not hand-edit (see above)
    ├── ipc.ts                  Thin unwrap-Result-into-throw wrapper over bindings.ts, for React Query
    ├── fileType.ts / format.ts  Small client-side helpers (category classification, byte/date formatting)

src-tauri/src/
├── ipc_client.rs        Daemon socket/pipe transport, built on findra_protocol's types + frame codec
├── daemon_manager.rs    Daemon discovery (CLI-enhanced vs. standalone) + spawn/restart
├── config_file.rs       Reads/writes only the `excluded_paths` key of ~/.findra/config.toml
├── permissions/         Per-platform (macOS/Windows/Linux) permission status heuristics
├── tray.rs / window.rs  Tray icon+menu, window show/hide/create
└── commands.rs          Every #[tauri::command] the frontend calls (all #[specta::specta]-annotated)

src-tauri/examples/export_bindings.rs   Standalone bindings regeneration, no GUI needed - a Cargo
                                          *example*, not a second [[bin]], deliberately: Tauri's
                                          bundler picks up every [[bin]] target and got confused
                                          about which one was "the app" when there were two (see
                                          ROADMAP.md's packaging section for the bug this caused).
```

## Packaging

`tauri.conf.json`'s `bundle.targets` covers macOS (`.app`/`.dmg`), Windows (`.msi`/`.exe` via NSIS), and Linux (`.deb`/`.rpm`/`.AppImage`). `.github/workflows/release.yml` builds all of these across a `macos-latest`/`windows-latest`/`ubuntu-22.04` matrix on a `v*` tag push, using `tauri-apps/tauri-action`.

Code signing/notarization (macOS) and EV code signing (Windows) are **not** configured - `tauri-action`'s signing inputs are simply omitted, so CI produces unsigned/unnotarized artifacts today. Follow-up before a real public release.

## Auto-update

`tauri-plugin-updater` is wired up (`src-tauri/src/lib.rs`, `tauri.conf.json`'s `plugins.updater`) against a real signing keypair (generated via `tauri signer generate`, private key kept outside this repo). CI's `release.yml` expects `TAURI_SIGNING_PRIVATE_KEY`/`TAURI_SIGNING_PRIVATE_KEY_PASSWORD` as GitHub Actions secrets - add the private key's contents and its password there before relying on CI to produce a working signed update artifact. The update manifest endpoint (`plugins.updater.endpoints` in `tauri.conf.json`) points at `github.com/findra/findra-app`'s latest release - update this once the real remote exists.

## What's not done yet

- No real app icon (`src-tauri/icons/*` are still the default Tauri template icons) - `prd/findra_macos_appicon.svg` in the `findra` repo needs to go through `tauri icon` once it's rendered to a source PNG.
- No `config.*` IPC method on the daemon yet - the Excluded Directories preference edits `~/.findra/config.toml` directly (see `config_file.rs`'s doc comment) and asks the user to restart the daemon, rather than a live IPC round trip.
- Code signing/notarization (see Packaging, above).
- No automated test suite for the frontend or the Rust shell yet.
