#!/usr/bin/env bash
set -euo pipefail

# Sync Casks/localvoxtral.rb with a release: rewrites version, sha256, and
# download URL in place, keeping the postflight/caveats/zap stanzas intact.
#
#   ./scripts/update-cask.sh                       # pin the latest release
#   ./scripts/update-cask.sh v0.8.5                # pin a specific tag
#   ./scripts/update-cask.sh v0.8.5 dist/localvoxtral-v0.8.5.zip
#                                                  # sha from a locally built zip
#                                                  # (what the release runner uses)
#
# Run from the repo root.

REPO="T0mSIlver/localvoxtral"
CASK_FILE="Casks/localvoxtral.rb"
TAG="${1:-latest}"
ZIP_FILE="${2:-}"

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

[ -f "$CASK_FILE" ] || die "not found: $CASK_FILE (run from the repo root)"

resolve_latest_tag() {
  local json
  json="$(curl -fsSL --retry 3 "https://api.github.com/repos/${REPO}/releases/latest")" \
    || die "could not fetch latest release metadata for ${REPO}"
  printf '%s\n' "$json" | python3 -c '
import json, sys
print(json.load(sys.stdin).get("tag_name", ""))
'
}

if [ "$TAG" = "latest" ]; then
  TAG="$(resolve_latest_tag)"
  [ -n "$TAG" ] || die "could not read tag_name from latest release metadata"
fi
VERSION="${TAG#v}"

TMP_DOWNLOAD=""
if [ -n "$ZIP_FILE" ]; then
  [ -f "$ZIP_FILE" ] || die "zip not found: $ZIP_FILE"
  DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/localvoxtral-${TAG}.zip"
else
  # Select the app zip by its exact, contractual name — install.sh does the
  # same (issue #131: the API lists dSYM archives before the app zip; picking
  # by position or by "any .zip" downloads debug symbols).
  DOWNLOAD_URL="$(curl -fsSL --retry 3 "https://api.github.com/repos/${REPO}/releases/tags/${TAG}" | python3 - "$TAG" <<'PY'
import json, sys
tag = sys.argv[1]
want = "localvoxtral-%s.zip" % tag
for a in json.load(sys.stdin).get("assets", []):
    if a["name"] == want:
        print(a["browser_download_url"])
        sys.exit(0)
sys.exit(1)
PY
  )" || die "release ${TAG} has no asset named localvoxtral-${TAG}.zip"
  TMP_DOWNLOAD="$(mktemp "${TMPDIR:-/tmp}/localvoxtral-cask.XXXXXX")"
  curl -fL --retry 3 "$DOWNLOAD_URL" -o "$TMP_DOWNLOAD" || {
    rm -f "$TMP_DOWNLOAD"
    die "download failed: $DOWNLOAD_URL"
  }
  ZIP_FILE="$TMP_DOWNLOAD"
fi

SHA256="$(shasum -a 256 "$ZIP_FILE" | awk '{ print $1 }')"
[[ "$SHA256" =~ ^[[:xdigit:]]{64}$ ]] || die "could not compute sha256 of $ZIP_FILE"
[ -n "$TMP_DOWNLOAD" ] && rm -f "$TMP_DOWNLOAD"

# Exactly-two-space indent keeps these anchored to the top-level stanzas; a
# bare ` *url "` would also rewrite the livecheck's (4-space) url line.
# The cask keeps the idiomatic v#{version} interpolation; the download below
# still used the concrete DOWNLOAD_URL.
CASK_URL="https://github.com/${REPO}/releases/download/v#{version}/localvoxtral-v#{version}.zip"
sed -i.bak \
  -e 's|^\(  version "\)[^"]*\("\)|\1'"${VERSION}"'\2|' \
  -e 's|^\(  sha256 "\)[^"]*\("\)|\1'"${SHA256}"'\2|' \
  -e 's|^\(  url "\)[^"]*\("\)|\1'"${CASK_URL}"'\2|' \
  "$CASK_FILE"
rm -f "${CASK_FILE}.bak"

printf 'Updated %s -> %s (sha256 %s)\n' "$CASK_FILE" "$TAG" "$SHA256"
printf 'Verify: brew style %s && brew audit --cask localvoxtral\n' "$CASK_FILE"
