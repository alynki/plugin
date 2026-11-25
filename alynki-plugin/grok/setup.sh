#!/bin/sh
# Grok Build only: the same grant as Claude Code's /alynki:setup, written into the user's own Grok folder
# ($GROK_HOME, else ~/.grok):
#   config.toml                    one [[permission.rules]] entry per tool: allow each tool in ../tools.txt,
#                                  ask for each in ../ask-tools.txt (https://docs.x.ai/build/features/permissions)
#   rules/alynki-load-context.md   ../hooks/load-first.md, which every session and subagent reads
#                                  (https://docs.x.ai/build/features/project-rules)
# Grok's MCP result limit (max_output_bytes, 20,000 bytes by default, for every MCP server) is left as it is:
# an Alynki page is at most 20,000 bytes (alynki/alynki#3672).
# Everything else is kept; a second run changes nothing. `setup.sh --undo` removes both.
# The entries are found by their content: Grok drops comments when it rewrites config.toml.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
home=${GROK_HOME:-${HOME:?HOME is not set}/.grok}
config=$home/config.toml
rules=$home/rules/alynki-load-context.md
note='# Alynki setup (/alynki:setup)'
fail() { echo "Nothing written. $1" >&2; exit 1; }
case ${1-} in '' | --undo) ;; *) fail "Unknown option: $1" ;; esac
for f in "$here/tools.txt" "$here/ask-tools.txt" "$here/hooks/load-first.md"; do
  [ -s "$f" ] || fail "Cannot read $f."
done
tmp=$(mktemp -d "${TMPDIR:-/tmp}/alynki-grok.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
if [ -f "$config" ]; then cat "$config" >"$tmp/old"; else : >"$tmp/old"; fi

# $tmp/base: the file without the entries for the listed tools (a deny of yours is kept).
# $tmp/state: "set" when each tool already has exactly its one entry.
awk -v allow="$(tr '\n' ' ' <"$here/tools.txt")" -v ask="$(tr '\n' ' ' <"$here/ask-tools.txt")" \
  -v note="$note" -v state="$tmp/state" '
function stop(why) { print "Nothing written. " why " (line " NR "). Add the rules by hand: https://docs.x.ai/build/features/permissions" > "/dev/stderr"; failed = 1; exit 1 }
function value(line) { sub(/^[^=]*=[ \t]*["\047]/, "", line); sub(/["\047].*$/, "", line); return line }
function emit(s) { if (s ~ /^[ \t\r]*$/) { blank = blank s "\n"; return } printf "%s", blank; blank = ""; print s }
# Ends a [[permission.rules]] entry: its lines up to the last key are the entry, the rest belong to what follows.
function flush(   i, act, tool, pat, key) {
  if (!n) return
  for (i = 1; i <= last; i++) {
    if (L[i] ~ /^[ \t]*action[ \t]*=/) act = value(L[i])
    if (L[i] ~ /^[ \t]*tool[ \t]*=/) tool = value(L[i])
    if (L[i] ~ /^[ \t]*pattern[ \t]*=/) pat = value(L[i])
  }
  if (tool == "mcp" && (pat in want) && (act == "allow" || act == "ask")) {
    if (act == want[pat] && !(pat in seen)) { seen[pat] = 1; good++ } else bad++
  } else for (i = 1; i <= last; i++) emit(L[i])
  for (i = last + 1; i <= n; i++) emit(L[i])
  n = 0; last = 0
}
BEGIN {
  a = split(allow, A, " "); for (i = 1; i <= a; i++) want["alynki__" A[i]] = "allow"
  b = split(ask, B, " "); for (i = 1; i <= b; i++) want["alynki__" B[i]] = "ask"
}
index($0, "\"\"\"") || index($0, "\047\047\047") { stop("config.toml holds a multi-line string, which this script does not parse") }
$0 == note { next }
/^[ \t]*\[/ {
  flush(); table = $0; sub(/#.*$/, "", table); gsub(/[ \t\r"\047]/, "", table)
  if (table == "[permission.rules]") stop("config.toml defines permission.rules as one table")
  if (table == "[[permission.rules]]") { n = 1; last = 1; L[1] = $0; next }
}
/^[ \t]*["\047]?permission["\047]?[ \t]*[.=]/ && table == "" { stop("config.toml sets permission inline") }
/^[ \t]*["\047]?rules["\047]?[ \t]*[.=]/ && table == "[permission]" { stop("config.toml sets permission rules inline") }
n { L[++n] = $0; if ($0 !~ /^[ \t\r]*(#.*)?$/) last = n; next }
{ emit($0) }
END { if (failed) exit 1; flush(); if (!bad && good == a + b) print "set" > state; else print "unset" > state }
' "$tmp/old" >"$tmp/base"

if [ "${1-}" = --undo ]; then
  if ! cmp -s "$tmp/base" "$tmp/old"; then cat "$tmp/base" >"$config"; fi
  rm -f "$rules"
  echo "Undone: removed the Alynki permission rules from $config, and $rules."
  exit 0
fi
{
  cat "$tmp/base"
  [ ! -s "$tmp/base" ] || echo
  echo "$note"
  for pair in allow:tools.txt ask:ask-tools.txt; do
    while IFS= read -r tool || [ -n "$tool" ]; do
      [ -n "$tool" ] || continue
      printf '[[permission.rules]]\naction = "%s"\ntool = "mcp"\npattern = "alynki__%s"\n' "${pair%%:*}" "$tool"
    done <"$here/${pair#*:}"
  done
} >"$tmp/new"
{
  cat "$here/hooks/load-first.md"
  printf '\nIn Grok Build: run /alynki:setup, which allows the same 37 for this machine. Call load_context through use_tool as alynki__load_context.\n'
} >"$tmp/rules"

allowed=$(grep -c . "$here/tools.txt"); asking=$(grep -c . "$here/ask-tools.txt")
changed=
mkdir -p "$home/rules"
if [ "$(cat "$tmp/state")" != set ]; then
  cat "$tmp/new" >"$config"; changed=" $config"
fi
if ! cmp -s "$tmp/rules" "$rules"; then cat "$tmp/rules" >"$rules"; changed="$changed $rules"; fi
if [ -z "$changed" ]; then
  echo "Unchanged: $allowed Alynki tools already run without asking, $asking ask each time, and sessions load context first."
else
  echo "Done (wrote$changed): $allowed Alynki tools now run without asking; $asking, which change who has access or manage agents, ask each time; every new session and subagent is told to call load_context first. Start a new Grok session."
fi
if grep -q -E 'alynki(__|\*)' "$tmp/base"; then
  echo "Note: $config holds other rules naming alynki; a deny or ask among them still applies."
fi
