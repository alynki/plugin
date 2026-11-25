#!/bin/sh
# Codex only: the same grant as Claude Code's /alynki:setup, written as the plugin's tool policy in the user's
# own config.toml ($CODEX_HOME/config.toml, else ~/.codex/config.toml):
# https://learn.chatgpt.com/docs/extend/mcp (Plugin-provided MCP servers).
# Each tool in ../tools.txt gets approval_mode "approve"; each tool in ../ask-tools.txt gets "prompt", replacing
# any "approve" an earlier run or an "always allow" wrote. A server default of "approve" is removed, so a tool
# neither list names is not allowed by it. Touches nothing else; a second run changes nothing.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
config=${CODEX_HOME:-$HOME/.codex}/config.toml
[ -f "$config" ] || { echo "No $config: install the plugin with 'codex plugin add alynki@alynki-marketplace' first." >&2; exit 1; }
for list in "$here/tools.txt" "$here/ask-tools.txt"; do
  [ -s "$list" ] || { echo "Nothing written. Cannot read $list." >&2; exit 1; }
done
new=$(mktemp "${TMPDIR:-/tmp}/alynki-codex.XXXXXX")
trap 'rm -f "$new"' EXIT

awk -v allow="$(tr "\n" " " <"$here/tools.txt")" -v ask="$(tr "\n" " " <"$here/ask-tools.txt")" '
function stop(why) { print "Nothing written. " why " (line " NR "). Edit it by hand: https://learn.chatgpt.com/docs/extend/mcp" > "/dev/stderr"; failed = 1; exit 1 }
BEGIN {
  plugin = "plugins.\"alynki@alynki-marketplace\""
  server = "[" plugin ".mcp_servers.alynki]"
  prefix = "[" plugin ".mcp_servers.alynki.tools."
  a = split(allow, A); for (i = 1; i <= a; i++) { mode[A[i]] = "approve"; order[++count] = A[i] }
  b = split(ask, B); for (i = 1; i <= b; i++) { mode[B[i]] = "prompt"; order[++count] = B[i] }
}
index($0, "\"\"\"") || index($0, "\047\047\047") { stop("The file holds a multi-line string, which this script does not parse") }
/^[ \t]*#/ { print; next }
/^[ \t]*\[/ {
  h = $0; sub(/^[ \t]*/, "", h); sub(/[ \t]*(#.*)?$/, "", h); section = ""; listed = 0
  if (h == "[" plugin "]") { section = "plugin"; installed = 1 }
  else if (h == server) section = "server"
  else if (index(h, prefix) == 1) {
    section = "tool"; name = substr(h, length(prefix) + 1); sub(/\]$/, "", name); gsub(/["\047]/, "", name)
    if (name in mode) { seen[name] = 1; listed = 1; print; print "approval_mode = \"" mode[name] "\""; next }
  }
  else if (index(h, "alynki@alynki-marketplace")) stop("An Alynki plugin table has a form this script does not edit")
  print; next
}
index($0, "alynki@alynki-marketplace") { stop("An Alynki plugin setting has a form this script does not edit") }
section == "plugin" && /^[ \t]*["\047]?mcp_servers/ { stop("The plugin table sets mcp_servers inline") }
section == "server" && /^[ \t]*["\047]?tools/ { stop("The server table sets tools inline") }
section == "server" && /^[ \t]*["\047]?default_tools_approval_mode["\047]?[ \t]*=[ \t]*["\047]approve["\047]/ { next }
section == "tool" && listed && /^[ \t]*["\047]?approval_mode["\047]?[ \t]*=/ { next }
{ print }
END {
  if (failed) exit 1
  if (!installed) { print "Nothing written. The plugin alynki@alynki-marketplace is not in this config." > "/dev/stderr"; exit 1 }
  for (i = 1; i <= count; i++) if (!(order[i] in seen)) {
    print ""; print prefix order[i] "]"; print "approval_mode = \"" mode[order[i]] "\""
  }
}
' "$config" > "$new"

allowed=$(grep -c . "$here/tools.txt"); asking=$(grep -c . "$here/ask-tools.txt")
if cmp -s "$new" "$config"; then
  echo "Unchanged: $allowed Alynki tools already run without asking and $asking ask each time ($config)."
else
  removed=$(diff "$config" "$new" | grep -c '^<' || true)
  cat "$new" > "$config"
  echo "Done ($config): $allowed Alynki tools now run without asking; $asking, which change who has access or manage agents, ask each time. Lines replaced or removed: $removed. Start a new Codex session."
fi
