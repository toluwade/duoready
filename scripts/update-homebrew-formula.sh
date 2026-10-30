#!/usr/bin/env bash
# Renders the Homebrew formula for a tagged release.
#
#   scripts/update-homebrew-formula.sh 0.1.0 [output-file]
#
# Downloads the tag's source archive from GitHub, computes its SHA-256 and
# writes the formula (default: ./duoready.rb). The tag must be pushed and the
# repository public, because Homebrew downloads the same archive.
set -euo pipefail

version="${1:?usage: $0 VERSION [OUTPUT_FILE]}"
version="${version#v}"
output="${2:-duoready.rb}"
url="https://github.com/toluwade/duoready/archive/refs/tags/v${version}.tar.gz"
template="$(cd "$(dirname "$0")/.." && pwd)/packaging/homebrew/duoready.rb.template"

archive="$(mktemp)"
trap 'rm -f "$archive"' EXIT

if ! curl --fail --silent --show-error --location --output "$archive" "$url"; then
  echo "error: could not download $url" >&2
  echo "Check that tag v${version} is pushed and the repository is public." >&2
  exit 1
fi

sha256="$(shasum -a 256 "$archive" | cut -d ' ' -f 1)"
sed -e "s|{{VERSION}}|${version}|g" -e "s|{{SHA256}}|${sha256}|g" "$template" > "$output"
echo "Wrote $output for v${version} (sha256 ${sha256})"
