# Security policy

DuoReady often runs in CI on pull-request code, which is untrusted input. Its design rules are:

- It reads source files only. It never builds, runs or loads code from the scanned project, and it
  never installs that project's dependencies.
- It makes no network calls and sends no telemetry.
- It doesn't follow symbolic links while discovering files, and it skips files larger than 4 MB.
- The GitHub Action passes inputs through environment variables, never by interpolating them into
  scripts, and it needs only `contents: read`.
- When the action downloads a prebuilt binary, it checks the binary's SHA-256 against the checksum
  published with the release, and builds from source instead if they don't match.

## Reporting a vulnerability

Please don't open a public issue. Report vulnerabilities privately through GitHub's
**Security → Report a vulnerability** form on this repository. We aim to acknowledge reports
within five working days.
