# DuoReady

DuoReady is an open-source static analyzer that finds adaptive-layout and resizability problems in
SwiftUI and UIKit code. It flags assumptions such as "the app always fills one known screen" or
"landscape means wide" before they ship.

<!-- TODO before release: confirm Apple's official name and supported configurations for the
     target device, and update this paragraph to match. -->
DuoReady is built for iPhone Duo and for any device or configuration where an app's window can
change size. Its rules check general adaptive-layout practice, not a specific device identifier.

- **Runs locally.** Nothing is uploaded and there is no telemetry. A scan makes no network calls.
- **No app changes.** DuoReady reads source files. It doesn't add a runtime dependency to your app,
  and it never builds, runs or modifies your code.
- **Made for CI.** It produces compiler-style text, JSON and GitHub pull-request annotations, with
  separate exit codes for findings and for scanner failures.

> **Status:** early development (`0.1.0-dev`). Six rules ship today; more are planned. See
> [RULES.md](RULES.md).

## Quick start

DuoReady requires macOS and Swift 6.0 or later.

```sh
git clone https://github.com/YOUR_ORG/duoready.git
cd duoready
swift build -c release
.build/release/duoready scan /path/to/YourApp
```

Example output:

```
Views/GalleryViewController.swift:8:25: warning: [DR001] UIScreen.main.bounds assumes a single, fixed screen.
    Fix: Use the size of the containing view or window (view.bounds, view.window?.bounds) in UIKit, or GeometryReader / containerRelativeFrame in SwiftUI.

Scanned 4 files: 1 warning.
```

## Commands

| Command | Purpose |
| --- | --- |
| `duoready scan [path]` | Scan a directory or `.swift` file (default `.`) |
| `duoready scan . --format json` | Machine-readable output (`text`, `json`, `github`) |
| `duoready scan . --severity warning` | Fail on findings at or above a severity |
| `duoready scan . --config path.json` | Use a specific configuration file |
| `duoready scan . --output report.json` | Write the report to a file |
| `duoready scan . --explain` | Include each rule's rationale in text output |
| `duoready scan . --no-baseline` | Report every finding, ignoring the baseline |
| `duoready baseline [path]` | Record current findings so scans report only new ones |
| `duoready rules [ID]` | List rules, or show one rule in detail |
| `duoready config init` | Write a starter `.duoready.json` |
| `duoready config validate` | Check a configuration file |
| `duoready version` | Print the version |

### Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Scan completed. No findings at or above the failure threshold. |
| `1` | Scan completed. Findings crossed the threshold. |
| `2` | Invalid arguments or configuration. |
| `3` | The project could not be scanned. |

## Configuration

DuoReady reads `.duoready.json` from the scanned directory if it exists.

```json
{
  "version": 1,
  "exclude": ["Pods/**", "build/**", "Vendor/**"],
  "rules": {
    "DR001": { "enabled": true, "severity": "warning" },
    "DR002": { "severity": "error" }
  },
  "failOn": "error"
}
```

- `exclude` takes globs relative to the scanned directory. `**` matches any depth, and a pattern
  without `/` matches at any depth. `.build`, `.git`, `DerivedData`, `Pods`, `Carthage`, `build`
  and `node_modules` are always skipped.
- `rules` can enable or disable a rule and change its severity. An unknown rule ID is an error, so
  typos don't fail silently.
- `failOn` sets the default failure threshold. `--severity` overrides it.
- `baseline` (optional) sets the baseline file's path, relative to the configuration file. The
  default is `.duoready-baseline.json` in the scanned directory.

To suppress a single finding, add a comment:

```swift
let scale = UIScreen.main.scale // duoready:ignore DR001

// duoready:ignore DR002
if UIDevice.current.orientation.isLandscape { … }
```

## Adopting DuoReady in an existing project

A large app may have dozens of findings on day one. Instead of fixing them all before you can
turn on CI, record them in a baseline:

```sh
duoready baseline .          # writes .duoready-baseline.json
git add .duoready-baseline.json
```

From then on, `duoready scan` hides findings the baseline covers. It reports and fails only on
new ones, and the summary says how many existing findings it hid.

- **Matching ignores line numbers.** Each finding has a fingerprint built from its rule, its file
  and the text of the flagged line, with whitespace ignored. Adding or removing code elsewhere in
  the file doesn't break the match. Editing the flagged line or renaming the file makes the
  finding new again, which is usually what you want.
- **Fixed findings are reported as stale.** Rerun `duoready baseline` to remove them, and commit
  the smaller file. The baseline should only ever shrink.
- **Duplicates still count.** Each baseline entry hides one finding. If you copy a baselined
  problem onto a second, identical line, the copy is reported.
- **Scan the same root.** Paths in the baseline are relative to the scanned directory, so create
  and use it with the same `path`.
- `duoready scan --no-baseline` shows everything, including baselined findings.

## GitHub Action

```yaml
name: DuoReady
on: [pull_request]
permissions:
  contents: read
jobs:
  scan:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: YOUR_ORG/duoready@v0.1.0
        with:
          path: .
          severity: error
```

| Input | Default | Purpose |
| --- | --- | --- |
| `path` | `.` | Directory or file to scan |
| `config` | | Configuration file |
| `severity` | config `failOn` | Failure threshold |
| `format` | `github` | `github`, `text` or `json` |
| `upload-report` | `false` | Upload a JSON report as an artifact |

The action applies a committed baseline automatically, the same way `duoready scan` does. It
builds the CLI from the commit you reference, so the scanner version always matches the
action version. It needs only `contents: read`, and it never builds or runs the scanned project.

## How it works

DuoReady parses each Swift file with [SwiftSyntax](https://github.com/swiftlang/swift-syntax) and
runs each rule over the syntax tree. Rules are pure functions from a parsed file to findings, and
reporters handle presentation. A new rule therefore doesn't need changes to the CLI or the CI
integration. See [CONTRIBUTING.md](CONTRIBUTING.md).

```
Sources/
  DuoReadyCore/       Finding model, rule protocol, file discovery, configuration, scanner
  DuoReadyRules/      Built-in rules (UIKit/, SwiftUI/, Shared/)
  DuoReadyReporters/  Text, JSON and GitHub output
  DuoReadyCLI/        The duoready command
```

## What DuoReady is not

- A guarantee that an app works in every configuration. It finds common, recognizable risks.
- An automatic rewriter. The right fix depends on context, so DuoReady explains it instead.
- A replacement for testing on real devices and in the simulator at different window sizes.

## License

MIT. See [LICENSE](LICENSE).
