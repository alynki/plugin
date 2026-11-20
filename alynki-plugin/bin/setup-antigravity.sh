#!/bin/sh
# Allows every Alynki tool, without a prompt, in Antigravity CLI's global settings.
# Reads the tool names from ../tools.txt (the one list every setup shares) and merges
# mcp(alynki/<tool>) rules into permissions.allow of ~/.gemini/antigravity-cli/settings.json.
# Other keys and entries are kept; running it twice leaves the file byte-identical.
# Needs jq. Run: sh bin/setup-antigravity.sh
set -eu
SERVER=alynki
here=$(cd "$(dirname "$0")" && pwd)
list=$here/../tools.txt
[ -r "$list" ] || { echo "setup-antigravity: cannot read $list" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "setup-antigravity: jq is required" >&2; exit 1; }
dir=${HOME:?HOME is not set}/.gemini/antigravity-cli
file=$dir/settings.json
mkdir -p "$dir"
[ -e "$file" ] || printf '{}\n' >"$file"
jq -e 'type == "object"' "$file" >/dev/null 2>&1 || { echo "setup-antigravity: $file is not a JSON object; left untouched" >&2; exit 1; }
tmp=$(mktemp "$dir/.settings.XXXXXX")
trap 'rm -f "$tmp"' EXIT
jq --rawfile t "$list" --arg s "$SERVER" '
  ($t | split("\n") | map(select(length > 0) | "mcp(" + $s + "/" + . + ")")) as $new
  | .permissions = (.permissions // {})
  | .permissions.allow = ((.permissions.allow // []) as $old | $old + ($new - $old))
' "$file" >"$tmp"
if cmp -s "$file" "$tmp"; then
  echo "Antigravity: already allowed, nothing changed ($file)"
else
  cat "$tmp" >"$file"
  echo "Antigravity: every Alynki tool allowed in $file"
fi
