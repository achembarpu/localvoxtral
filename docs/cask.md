# Homebrew cask

`Casks/localvoxtral.rb` is a Homebrew cask pinned to the current release —
exact `version` + `sha256` + download URL. It lets you install, upgrade, and
uninstall localvoxtral with `brew`, alongside the installer script and DMG.

## Install

```bash
brew install --cask https://raw.githubusercontent.com/T0mSIlver/localvoxtral/main/Casks/localvoxtral.rb
```

This reads the cask straight from the repo's `main` branch; the sha256 inside
the cask pins the exact release artifact. (If a `homebrew-localvoxtral` tap
is ever published upstream, the install becomes `brew install
T0mSIlver/localvoxtral/localvoxtral`.)

Requires an Apple Silicon Mac on macOS 15+. First launch still runs the setup
wizard (microphone + Accessibility permissions, one-time engine download).

## What the cask does

- Downloads `localvoxtral-v<version>.zip` from the release and verifies its
  SHA-256 before install.
- Clears quarantine and ad-hoc re-signs the bundle in `postflight`. Releases
  are ad-hoc signed, not notarized (see [roadmap](roadmap.md)), so the cask
  performs the same Gatekeeper handling as `scripts/install.sh` — including
  the macOS 26 first-launch hang that `xattr -cr` alone does not fix.
- `brew uninstall --cask --zap localvoxtral` also removes app data
  (`~/Library/Application Support/localvoxtral` and the preferences plist).

## Not in homebrew-cask yet

The cask is not submitted to [homebrew/homebrew-cask](https://github.com/Homebrew/homebrew-cask).
New-cask admission there requires a notarized app (releases are ad-hoc
signed) and a "notable" repository. Revisit once notarization ships on the
roadmap.

## Keeping the cask current

After each release, sync the pin and commit:

```bash
./scripts/update-cask.sh            # pin the latest release
./scripts/update-cask.sh v0.8.5     # pin a specific tag
git add Casks/localvoxtral.rb && git commit
```

With the just-built artifact (what a release pipeline would use — no
network, sha comes from the local zip):

```bash
./scripts/update-cask.sh v0.8.5 dist/localvoxtral-v0.8.5.zip
```

Verify before pushing:

```bash
brew style Casks/localvoxtral.rb
brew install --cask --dry-run ./Casks/localvoxtral.rb
```

## Caveat

Because releases are ad-hoc signed, macOS may silently drop the
Accessibility grant after an upgrade replaces the bundle. If the dictation
hotkey stops working, toggle localvoxtral off and on in **System Settings →
Privacy & Security → Accessibility**.
