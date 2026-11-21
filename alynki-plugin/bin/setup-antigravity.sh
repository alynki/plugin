#!/bin/sh
# Allows the Alynki tools that need no person's approval in Antigravity CLI's global settings.
# Reads the tool names from ../tools.txt (the list every setup shares) and merges
# mcp(alynki/<tool>) rules into permissions.allow of ~/.gemini/antigravity-cli/settings.json.
# The seven tools in ../ask-tools.txt change who has access or manage agents: any allow rule for
# one of them (an earlier version wrote them) is removed, so Antigravity asks a person each time.
# Other keys and entries are kept; running it twice leaves the file byte-identical.
# Needs jq. Run: sh bin/setup-antigravity.sh
set -eu
SERVER=alynki
here=$(cd "$(dirname "$0")" && pwd)
list=$here/../tools.txt
asklist=$here/../ask-tools.txt
[ -r "$list" ] || { echo "setup-antigravity: cannot read $list" >&2; exit 1; }
[ -r "$asklist" ] || { echo "setup-antigravity: cannot read $asklist" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "setup-antigravity: jq is required" >&2; exit 1; }
dir=${HOME:?HOME is not set}/.gemini/antigravity-cli
file=$dir/settings.json
mkdir -p "$dir"
[ -e "$file" ] || printf '{}\n' >"$file"
jq -e 'type == "object"' "$file" >/dev/null 2>&1 || { echo "setup-antigravity: $file is not a JSON object; left untouched" >&2; exit 1; }
tmp=$(mktemp "$dir/.settings.XXXXXX")
trap 'rm -f "$tmp"' EXIT
jq --rawfile t "$list" --rawfile a "$asklist" --arg s "$SERVER" '
  def rules($x): $x | split("\n") | map(select(length > 0) | "mcp(" + $s + "/" + . + ")");
  rules($t) as $new | rules($a) as $gated
  | .permissions = (.permissions // {})
  | .permissions.allow = ((.permissions.allow // []) as $old | ($old - $gated) + ($new - $old))
' "$file" >"$tmp"
if cmp -s "$file" "$tmp"; then
  echo "Antigravity: already set up, nothing changed ($file)"
else
  cat "$tmp" >"$file"
  echo "Antigravity: Alynki tools allowed in $file; the seven access-changing tools ask each time"
fi
