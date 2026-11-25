#!/bin/sh
# Cursor: allows the Alynki tools in ../tools.txt without a prompt, in every project, by merging exact
# entries into mcpAllowlist in ~/.cursor/permissions.json (https://cursor.com/docs/reference/permissions).
# The tools in ../ask-tools.txt change who has access or manage agents: they are never listed, and an
# entry for this server that covers one of them is removed. Cursor has no "ask" list: what is not listed
# asks. Other keys and entries are kept; running it twice changes nothing. Needs jq. Run: sh cursor/setup.sh
set -eu
SERVER=plugin-alynki-alynki # Cursor's name for a plugin's MCP server: plugin-<plugin>-<server>
here=$(cd "$(dirname "$0")" && pwd)
list=$here/../tools.txt
asklist=$here/../ask-tools.txt
fail() { echo "setup-cursor: $*" >&2; exit 1; }
[ -r "$list" ] || fail "cannot read $list"
[ -r "$asklist" ] || fail "cannot read $asklist"
command -v jq >/dev/null 2>&1 || fail "jq is required (https://jqlang.org/download/)"
dir=${HOME:?HOME is not set}/.cursor
file=$dir/permissions.json
mkdir -p "$dir"
tmp=$(mktemp "$dir/.permissions.XXXXXX")
trap 'rm -f "$tmp"' EXIT
src=$file
[ -e "$file" ] || src=/dev/null
# Cursor accepts comments in this file; jq does not, and rewriting would drop them.
jq -s --rawfile t "$list" --rawfile a "$asklist" --arg s "$SERVER" '
  def lines: split("\n") | map(select(length > 0));
  def glob: "^" + (gsub("(?<c>[^A-Za-z0-9_*-])"; "\\" + .c) | gsub("\\*"; ".*")) + "$";
  ($a | lines) as $ask | ($t | lines | map($s + ":" + .)) as $new
  | def covers_ask: split(":") as $p
      | ($p | length) == 2 and ($p[0] | ascii_downcase) == $s
        and ($p[1] | ascii_downcase | glob) as $re | any($ask[]; test($re));
  if length > 1 then error("more than one value") else (.[0] // {}) end
  | if type != "object" or ((.mcpAllowlist // []) | type != "array" or any(.[]; type != "string"))
    then error("unexpected shape") else . end
  | ((.mcpAllowlist // []) | map(select(covers_ask | not))) as $kept
  | .mcpAllowlist = $kept + ($new - $kept)
' "$src" >"$tmp" 2>/dev/null ||
  fail "$file is not plain JSON with a string list mcpAllowlist (comments count); left untouched. Add \"$SERVER:<tool>\" for each name in $list to its mcpAllowlist by hand."
if [ -e "$file" ] && [ "$(jq -S . "$file")" = "$(jq -S . "$tmp")" ]; then
  echo "Cursor: already set up, nothing changed ($file)"
else
  if [ -e "$file" ]; then cat "$tmp" >"$file"; else cp "$tmp" "$file"; fi
  echo "Cursor: Alynki tools allowed in $file; the seven access-changing tools are not listed"
fi
# A wider entry (any server, or a wildcard) here or in the CLI's own list would also run the seven.
cli=$dir/cli-config.json
{
  jq -r '.mcpAllowlist[]' "$file"
  if [ -r "$cli" ]; then jq -r '.permissions.allow[]? | select(startswith("Mcp(")) | .[4:-1]' "$cli" 2>/dev/null || true; fi
} | while IFS= read -r entry; do
  server=${entry%%:*} tool=${entry#*:}
  while IFS= read -r t; do
    # shellcheck disable=SC2254 # the entry's parts are globs
    case $SERVER in $server) case $t in $tool) echo "WARNING: the allow entry \"$entry\" also covers $t, which then runs without asking. Remove it."; break ;; esac ;; esac
  done <"$asklist"
done
cat <<'EOT'
Two things to check:
- The seven ask only in Run Mode "Allowlist". In "Auto-review" Cursor's classifier can run them without
  asking, and "Run Everything" runs them (https://cursor.com/docs/agent/security/run-modes).
- This mcpAllowlist replaces the MCP allowlist in Cursor Settings, which becomes read-only: add your
  other MCP tools to this file.
EOT
