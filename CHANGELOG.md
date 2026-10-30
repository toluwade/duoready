# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-10-30

### Added

- `duoready scan` with text, JSON and GitHub annotation output and documented exit codes.
- `duoready rules`, `duoready config init|validate` and `duoready version`.
- `.duoready.json` configuration: excludes, per-rule enable/severity, `failOn`.
- Inline suppressions with `// duoready:ignore DRxxx`.
- Baselines: `duoready baseline` records existing findings, and `scan` reports only new ones.
  Matching uses line-independent fingerprints. `--baseline`, `--no-baseline` and a `baseline`
  configuration key are supported.
- Findings in JSON output include a `fingerprint`. The JSON summary includes
  `baselineSuppressed` and `staleBaselineEntries`.
- DR001: `UIScreen.main` usage.
- DR002: Layout decisions based on orientation.
- DR003: Device-type checks used to select layout dimensions.
- DR004: Fixed screen dimensions used for layout decisions.
- DR005: Constraints that pin content to screen-sized constants.
- DR006: SwiftUI frames with screen-sized fixed dimensions.
- Composite GitHub Action.
- Test code is skipped by default. `--include-tests` and the `includeTests` configuration key
  scan it too.
- Fewer false positives, tuned against three open-source apps: DR003 looks for layout names
  in branch bodies only, skips conditions that also check a size class and reports once per
  condition. DR004 only compares the sizes of views, windows, screens and geometry proxies.
  DR005 recognizes a priority lowered later in the same block. DR006 reports once per
  `.frame` call.
- The GitHub Action starts in seconds: it downloads the prebuilt binary for a release tag
  (checksum verified), and otherwise caches the binary it builds. A release workflow publishes
  the universal binary when a version tag is pushed.
- swift-syntax 604, so DuoReady parses the newest Swift syntax. Versions 601 to 604 are
  supported.
- iPhone Duo and iOS 27 rules: DR007 custom bars, DR008 title-only bar items, DR009
  `ArrangementView` placement, DR010 `UIRequiresFullScreen`, DR011 scene life cycle and DR012
  app-wide window lookups.
- Project-level rules that read `.plist` files and Xcode build settings.
- SARIF output for GitHub code scanning, and Markdown output. The Action can write SARIF and
  writes a job summary.
- `// duoready:ignore-file` suppresses a rule for a whole Swift file.
- Installation with Mint, and a Homebrew formula template and release script for the
  `toluwade/tap` tap.

[Unreleased]: https://github.com/toluwade/duoready/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/toluwade/duoready/releases/tag/v0.1.0
