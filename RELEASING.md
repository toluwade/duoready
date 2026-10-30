# Releasing DuoReady

This is the checklist for publishing a version, using `0.1.0` as the example.

Homebrew, Mint and the GitHub Action all download DuoReady from GitHub, so **the repository
must be public** before a release is usable.

## 1. Prepare

- [ ] CI passes on `main`.
- [ ] Every rule in the release has positive, negative and edge-case tests, and a section in
      `RULES.md`.
- [ ] You have run DuoReady on a few real apps and fixed noisy rules.
- [ ] `Sources/DuoReadyCore/DuoReady.swift`: set `version` to `"0.1.0"` (drop `-dev`).
      The Homebrew test checks that `duoready version` matches the tag.
- [ ] `CHANGELOG.md`: rename `[Unreleased]` to `[0.1.0] - YYYY-MM-DD` and add a new, empty
      `[Unreleased]` section above it.

Commit these changes as "Release 0.1.0".

## 2. Tag and publish on GitHub

```sh
git tag -a v0.1.0 -m "DuoReady 0.1.0"
git push origin main v0.1.0
gh release create v0.1.0 --title "DuoReady 0.1.0" --notes-file <(sed -n '/## \[0.1.0\]/,/## \[/p' CHANGELOG.md | sed '1d;$d')
```

Mint and the GitHub Action (`uses: toluwade/duoready@v0.1.0`) work as soon as the tag is
public. Mint installs the latest tag by default.

## 3. Publish to Homebrew

DuoReady is distributed through a personal tap, `toluwade/homebrew-tap`. Users install it with
`brew install toluwade/tap/duoready`.

**First release only:** create the tap repository.

```sh
gh repo create toluwade/homebrew-tap --public --description "Homebrew formulae for toluwade's tools"
```

**Every release:** render the formula, test it, then push it to the tap.

```sh
git clone https://github.com/toluwade/homebrew-tap.git ../homebrew-tap   # first time only
mkdir -p ../homebrew-tap/Formula
scripts/update-homebrew-formula.sh 0.1.0 ../homebrew-tap/Formula/duoready.rb

brew install --build-from-source toluwade/tap/duoready
brew test toluwade/tap/duoready
brew audit --strict --online toluwade/tap/duoready

cd ../homebrew-tap
git add Formula/duoready.rb
git commit -m "duoready 0.1.0"
git push
```

The script downloads the tag's source archive, computes its SHA-256 and fills in
`packaging/homebrew/duoready.rb.template`. The formula builds from source, which needs Xcode
16 or later and takes a few minutes on first install.

## 4. Start the next version

- [ ] Set `version` to `"0.2.0-dev"` and commit.
