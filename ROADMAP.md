# Findra macOS Roadmap

Findra for macOS is the native desktop front end for the shared `findra` daemon. The app does not implement its own search engine. It starts or reuses a compatible local daemon, renders fast indexed search results, and exposes macOS-native workflows around indexing, filtering, permissions, and distribution.

## Product Principles

- Search, sorting, filtering, global hotkey, menu-bar access, and index performance remain free.
- The daemon is the source of truth for indexing, query execution, watched paths, status, and protocol version.
- The app owns macOS UI, preferences, packaging, daemon supervision, and user-facing workflows.
- The app must never create a second index or silently diverge from CLI state.
- macOS native quality takes priority over cross-platform UI ambitions.
- The app does not do file-content search by default; the privacy promise is path and metadata indexing only.

## Current Baseline

- Native SwiftUI app shell is active.
- Legacy WebView, Node, and Tauri runtime paths are removed from the app build path.
- App bundles `findra-daemon` and starts it automatically when needed.
- App and daemon currently use version `1.0.0`.
- Main window supports search, file type filtering, excluded path filtering, sortable file list, owner display, indexed path management, status subscription, and local packaging.
- Local `.app`, `.dmg`, `.zip`, and checksum packaging works with ad-hoc signing.

## Milestones

| Phase | Status | Scope | Acceptance | Notes |
|---|---|---|---|---|
| M1 Search Table Quality | Partial | Everything-style dense table, aligned columns, column header sorting, row actions, keyboard navigation | Sorting does not freeze UI; rows stay aligned; open/reveal/copy work | Dense table, sorting, and row context actions are implemented. Keyboard-first navigation, Enter open, Space Quick Look, and Cmd-C path copy remain open. |
| M2 Index Visibility | Partial | Live daemon status stream, indexed count, database size/path, watched path state, indexing progress | File count changes update without manual refresh; database path can be revealed | Status subscription, indexed count, database size/path, and reveal are implemented. Rich scan progress still needs daemon support. |
| M3 Filtering Workflow | Mostly done | File type filters, extension filters, path filter, regex/exact/case/pinyin options | Selecting a type constrains search predictably and updates search affordance | File type, extension, path, regex, exact, case, pinyin, and excluded-result filtering are wired. Folder and excluded filters are currently app-side filters. |
| M4 Permissions and Trust | Partial | Full Disk Access guidance, per-path warning suppression, clear daemon/app permission wording | Missing permission is visible, actionable, and not repeatedly disruptive | Full Disk Access guidance and per-path warning suppression are implemented. Permission-state tests and deeper diagnostics remain open. |
| M5 Preferences | Partial | Indexed paths, excluded paths, common build/cache directory excludes, shortcut settings, about/version | Settings persist and update daemon behavior without manual restarts where protocol supports it | Excluded paths and permission warning preferences persist. Indexed paths go through daemon IPC. Login item, shortcut editing, daemon-side excluded paths, and auto-excludes remain open. |
| M6 Daemon Lifecycle | Partial | Bundled daemon supervision, compatible daemon reuse, graceful restart/update, protocol mismatch handling | Pure App install and CLI coexistence both work without duplicate daemons | Bundled daemon startup and compatible socket reuse are implemented. Graceful daemon update/restart and compatibility matrix tests remain open. |
| M7 Performance | Partial | Large index browsing, query cancellation, paging/cursor protocol if needed, table rendering benchmarks | Search input remains responsive on million-file indexes | Debounce, stale-response guards, result caps, and background owner lookup are implemented. Cursor/paging and formal million-file benchmarks remain open. |
| M8 Packaging and Release | Mostly done | GitHub release workflow, DMG/ZIP assets, checksums, release notes, install/uninstall path | Tagged release produces downloadable open-source macOS artifacts | Local DMG/ZIP/checksum packaging and release workflow are implemented. Developer ID signing and notarization remain release-hardening work. |
| M9 Hardening | Open | Compatibility matrix, old daemon/new app tests, app restart tests, permission-state tests | Release candidate passes documented local and CI validation | Basic protocol and preference tests exist. Full release-candidate hardening remains open. |

## Protocol Backlog

These require daemon/protocol changes and should not be patched only in the app:

- Paged search or cursor API for true full-index scrolling.
- Config API for indexed paths, excluded paths, and common auto-excludes.
- Status events with richer scan progress, not only total count and database size.
- Optional file metadata fields if owner/group should come from daemon instead of app-side lookup.
- Saved search and event subscription primitives for future smart folders.

## UX Backlog

- Column width persistence and show/hide columns.
- Keyboard-first navigation: arrow selection, Enter open, Space quick look, Cmd-C copy path.
- Context menu expansion: Quick Look, copy name, copy parent path, reveal database.
- Empty/loading states that distinguish indexing, no results, and permission-limited results.
- Menu-bar panel with compact daemon/index summary and primary actions.
- Preferences cleanup: indexed paths, ignored permission warnings, excluded paths, shortcuts, versions.

## Release Readiness

A release is considered ready when:

- App launches cleanly after fresh install.
- Existing stale installs do not create duplicate app copies or daemon instances.
- Bundled daemon starts without the user running a separate service.
- Search works against a real local index.
- Sorting/filtering does not block UI.
- Status bar reports app version, daemon version, daemon health, index database size/path.
- DMG/ZIP artifacts are signed, checksummed, and attached to GitHub Releases.
- Release notes include tag, changes, known limitations, and download assets.

## Future Product Options

These are outside the free core search path and should only be considered after the base app is stable:

- Saved searches and smart folders.
- iCloud sync for preferences and saved searches.
- Duplicate file finder with explicit local content hashing.
- Batch operations and macOS Shortcuts integration.
- Natural language query as an optional service-backed feature.

## Archived PRD Notes

Earlier PRD drafts mixed useful product ideas with obsolete WebView/Tauri/cross-platform implementation plans. Their useful content has been consolidated here. This roadmap is the current source of truth for app planning; legacy PRD material should not be used directly for implementation decisions without revalidating it against the native macOS architecture.
