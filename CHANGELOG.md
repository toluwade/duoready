# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

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
- Installation with Mint, and a Homebrew formula template and release script for the
  `toluwade/tap` tap.
