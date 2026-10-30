#!/usr/bin/env bash
# Used by action.yml: decides how the action gets the duoready binary.
#
# For a version tag (uses: toluwade/duoready@v0.1.0) it downloads the
# prebuilt binary published by .github/workflows/release.yml and checks its
# SHA-256. Otherwise it prints a cache key so the action can reuse a binary it
# built earlier for the same source and toolchain.
#
# Inputs (environment):
#   ACTION_PATH  the action's checkout
#   ACTION_REF   the ref the workflow used, e.g. v0.1.0 (empty for `uses: ./`)
#   ACTION_REPO  owner/name of the action repository
#   BIN_DIR      where the binary should end up
#   OUTPUT       file to append step outputs to (GITHUB_OUTPUT)
#   RELEASES_URL optional; replaces https://github.com in download URLs, for testing
#
# Outputs: source=prebuilt|build, and cache-key when source=build.
set -euo pipefail

: "${ACTION_PATH:?}" "${BIN_DIR:?}" "${OUTPUT:?}"
mkdir -p "$BIN_DIR"
asset="duoready-macos-universal.zip"

if [[ "${ACTION_REF:-}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]] && [ -n "${ACTION_REPO:-}" ]; then
  url="${RELEASES_URL:-https://github.com}/$ACTION_REPO/releases/download/$ACTION_REF/$asset"
  download="$(mktemp -d)"
  if curl --fail --silent --show-error --location --retry 2 --output "$download/$asset" "$url" \
    && curl --fail --silent --show-error --location --retry 2 --output "$download/$asset.sha256" "$url.sha256"; then
    expected="$(cut -d ' ' -f 1 "$download/$asset.sha256")"
    actual="$(shasum -a 256 "$download/$asset" | cut -d ' ' -f 1)"
    if [ "$expected" = "$actual" ]; then
      unzip -oq "$download/$asset" -d "$BIN_DIR"
      echo "Using prebuilt DuoReady $ACTION_REF."
      echo "source=prebuilt" >> "$OUTPUT"
      exit 0
    fi
    echo "::warning::The prebuilt DuoReady binary failed its checksum check. Building from source instead."
  else
    echo "No prebuilt DuoReady binary for $ACTION_REF. Building from source instead."
  fi
fi

# The key covers everything that affects the binary: the source, the
# resolved dependencies, the Swift toolchain and the CPU architecture.
key="$(
  {
    swift --version 2>&1
    uname -m
    cd "$ACTION_PATH" && find Package.swift Package.resolved Sources -type f -print0 | sort -z | xargs -0 shasum
  } | shasum | cut -d ' ' -f 1
)"
echo "source=build" >> "$OUTPUT"
echo "cache-key=duoready-$key" >> "$OUTPUT"
