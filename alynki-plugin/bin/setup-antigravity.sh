#!/bin/sh
# Allows the Alynki tools that need no person's approval in Antigravity CLI's global settings.
# Reads the tool names from ../tools.txt and ../ask-tools.txt (the lists every setup shares) and merges into
# ~/.gemini/antigravity-cli/settings.json one mcp(alynki_alynki/<tool>) rule in permissions.allow per tool in
# tools.txt and one in permissions.ask per tool in ask-tools.txt. The latter change who has access or manage
# agents, so Antigravity asks a person each time; any allow rule for one of them is removed.
# alynki_alynki is <plugin>_<server>, the name Antigravity gives a plugin's MCP server.
# A permissions.deny rule is kept and reported, and so is an allow rule left by an older setup under the global server
# name alynki (or a wildcard) that lets one of the seven run unprompted: it is not this plugin's to remove. Other keys and entries are kept; running it twice leaves the
# file byte-identical. Needs jq. Run: sh bin/setup-antigravity.sh
set -eu
SERVER=alynki_alynki
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
  | .permissions.ask = ((.permissions.ask // []) as $old | ($old - $new) + ($gated - $old))
' "$file" >"$tmp"
if cmp -s "$file" "$tmp"; then
  echo "Antigravity: already set up, nothing changed ($file)"
else
  cat "$tmp" >"$file"
  echo "Antigravity: Alynki tools allowed in $file; the seven access-changing tools ask each time; start a new session"
fi
denied=$(jq -r --arg s "$SERVER" '.permissions.deny // [] | .[] | select(startswith("mcp(" + $s + "/") or . == "mcp(*)")' "$file")
[ -z "$denied" ] || printf 'Antigravity: these deny rules still block Alynki tools and were left in place:\n%s\n' "$denied"
leftover=$(jq -r --rawfile a "$asklist" '($a | split("\n") | map(select(length > 0))) as $g
  | .permissions.allow // [] | .[] | select(. == "mcp(*)" or . == "mcp(alynki/*)" or . == "mcp(alynki_alynki/*)"
      or (startswith("mcp(alynki/") and (.[11:-1] as $n | $g | index($n) != null)))' "$file")
[ -z "$leftover" ] || printf 'Antigravity: these allow rules (from an older setup of the global alynki server, or a wildcard) let tools that change who has access run without asking; remove them from permissions.allow in %s:\n%s\n' "$file" "$leftover"
