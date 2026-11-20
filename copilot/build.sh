#!/usr/bin/env bash
# Builds the Microsoft 365 Copilot agent package (the zip an admin uploads in the
# Microsoft 365 admin centre, or a Partner Center offer carries).
#
#   copilot/build.sh <registration-id> [out.zip]
#
# <registration-id> is the OAuth client registration ID from the Teams Developer
# Portal (Tools, OAuth client registration). It replaces ${ALYNKI_COPILOT_REGISTRATION_ID}
# in alynki-plugin.json as the OAuthPluginVault reference_id. It is never committed.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
PLACEHOLDER='${ALYNKI_COPILOT_REGISTRATION_ID}'
id=${1-}
out=${2:-$here/alynki-copilot.zip}

die() { echo "build.sh: $*" >&2; exit 1; }

[ -n "$id" ] || die "a registration id is required: copilot/build.sh <registration-id> [out.zip]"
case "$id" in
  *'${'* | *ALYNKI_COPILOT_REGISTRATION_ID* | *[[:space:]]* | *'"'* | *'\'*) die "the registration id is empty, a placeholder or has characters that do not belong in an id" ;;
esac

for f in manifest.json declarativeAgent.json alynki-plugin.json; do
  [ -s "$here/$f" ] || die "missing $f"
  jq -e . "$here/$f" >/dev/null || die "$f is not valid JSON"
done

png_size() { sips -g pixelWidth -g pixelHeight "$1" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w "x" h}'; }
if command -v sips >/dev/null 2>&1; then
  [ "$(png_size "$here/color.png")" = 192x192 ] || die "color.png must be 192x192"
  [ "$(png_size "$here/outline.png")" = 32x32 ] || die "outline.png must be 32x32"
else
  # IHDR width and height: big-endian 32-bit words at bytes 16 and 20.
  dims() { printf '%sx%s' "$(od -An -tu1 -j16 -N4 "$1" | awk 'NF {print $1*16777216+$2*65536+$3*256+$4}')" "$(od -An -tu1 -j20 -N4 "$1" | awk 'NF {print $1*16777216+$2*65536+$3*256+$4}')"; }
  [ "$(dims "$here/color.png")" = 192x192 ] || die "color.png must be 192x192"
  [ "$(dims "$here/outline.png")" = 32x32 ] || die "outline.png must be 32x32"
fi

work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT
cp "$here/manifest.json" "$here/declarativeAgent.json" "$here/color.png" "$here/outline.png" "$work/"
# Substitute through jq so the id is always a JSON string, whatever it holds.
jq --arg id "$id" --arg ph "$PLACEHOLDER" '
  if .runtimes[0].auth.reference_id == $ph then .runtimes[0].auth.reference_id = $id else error("placeholder not found in alynki-plugin.json") end
' "$here/alynki-plugin.json" >"$work/alynki-plugin.json" || die "could not substitute the registration id"
jq -e --arg id "$id" '.runtimes[0].auth.reference_id == $id' "$work/alynki-plugin.json" >/dev/null || die "substitution failed"

mkdir -p "$(dirname "$out")"
out=$(cd "$(dirname "$out")" && pwd)/$(basename "$out")
rm -f "$out"
(cd "$work" && zip -q -X "$out" manifest.json declarativeAgent.json alynki-plugin.json color.png outline.png) || die "zip failed"
echo "wrote $out"
