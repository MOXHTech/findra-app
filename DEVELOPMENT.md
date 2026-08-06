# Development

## Toolchain

- macOS with Xcode 26.6 or newer.
- Swift 6.3 or newer.

Verify the local environment:

```bash
swift --version
xcodebuild -version
```

## Build

```bash
swift build
```

Package a local `.app`:

```bash
./scripts/package-local.sh
```

The package script builds `findra-daemon` from `../findra` and embeds it at:

```text
Findra.app/Contents/Resources/vendor-bin/findra-daemon
```

Set `FINDRA_REPO=/path/to/findra` when the daemon repository is not a sibling directory.

Install or remove the local app:

```bash
./scripts/install-local.sh
./scripts/uninstall-local.sh
```

The local package is ad-hoc signed and emits `.dmg`, `.zip`, and `.sha256` files under `build/`. Developer ID signing and notarization require Apple Developer credentials and are not performed by the local script.

Run the native app:

```bash
swift run Findra
```

## Test

```bash
swift test
```

The current test target covers daemon protocol wire compatibility.

## Daemon Setup

Installed packages include `findra-daemon` and start it automatically when the socket is missing:

```text
~/.findra/daemon.sock
```

During `swift run`, the app looks for a daemon binary in this order:

- `FINDRA_DAEMON_BIN`
- app resources under `vendor-bin/findra-daemon`
- `../findra/target/release/findra-daemon`
- `../findra/target/debug/findra-daemon`
- `findra-daemon` on `PATH`

## Validation Before Handoff

```bash
swift build
swift test
./scripts/package-local.sh
git diff --check
```

For documentation-only changes, also check command examples and remove stale implementation references.
