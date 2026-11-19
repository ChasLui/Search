# Search

Search is a native macOS browser built with SwiftUI, AppKit, and WebKit.
Read [CONTRIBUTING.md](CONTRIBUTING.md) for project conventions and
[README.md](README.md#building-it) for build and architecture details.

## Build and test

- Use macOS 14 or later with Xcode 16 or newer and Swift 6. Keep macOS 14
  compatibility and guard API calls that require a newer OS.
- Run `swift build` for a development build and
  `swift test --filter <SuiteOrTest>` for focused Swift tests in
  `Tests/SearchTests/`.
- Run `python3 Tests/run-ci-tests.py` for the full Swift test suite. It runs
  WebKit download cases in separate processes to avoid shared native state.
- For an app bundle, run `SEARCH_DEV=1 ./build.sh debug`.
  Open the built app for manual testing with `SEARCH_PROBE=codex ./fresh.sh again`
  so it uses a separate browser profile. Running `fresh.sh` without `again`
  clears the selected probe profile. Reserve notarization and publishing for
  explicit release work.

## Fork branches and upstream sync

- Use `ChasLui/Search:chaslui-dev` as the default development and fork PR
  base branch. Keep `ChasLui/Search:main` as the mirror of
  `driceroland/Search:main`.
- Sync upstream into the fork's `main` first and verify that the two remote
  `main` refs point to the same commit. Fast-forward the mirror when possible.
  If the refs have diverged, report the divergence before rewriting any branch.
- Review the commits introduced by that sync one by one against `chaslui-dev`.
  Port each applicable change with any adaptations needed for the fork. Record
  which changes were ported, already present, or deferred and why. Validate the
  affected behavior before integrating each change into `chaslui-dev`.

- When syncing upstream, review the [horizontal tab bar performance spec](docs/specs/tab-bar-grouping-performance.md)
  and preserve or revalidate its behavior and benchmarks.
- When syncing upstream, review the [interface localization spec](docs/specs/interface-localization-upstream.md)
  and preserve or revalidate language switching, resources, and translations.
- When syncing or contributing extension changes upstream, use the
  [extension performance spec](docs/specs/extension-performance-upstream.md)
  to check CRX3 verification, shim generation, and external messaging.
- When syncing or contributing upstream, or changing window, title bar, tab
  dragging, or system window management, review the
  [window drag and tiling spec](docs/specs/window-drag-tiling-upstream.md)
  and preserve or revalidate its behavior.

## Where to work

- Browser features live in `Sources/Search/`, with Swift tests in
  `Tests/SearchTests/` and live browser probes under `Tests/`.
- For visual changes, start with the shared appearance values in
  `Sources/Search/Design.swift` and check the result in both light and dark mode.
- For changes to WebKit, AppKit, or browser profile behavior, report which
  macOS version and live scenarios were verified.
