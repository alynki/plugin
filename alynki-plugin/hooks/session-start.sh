#!/bin/sh
# Prints the "call load_context first" wording as a client's hook output.
#   session-start.sh <shape> <event>
#   shape: claude (Claude Code), codex, antigravity, copilot, cursor
#   event: session, subagent
# The wording lives only in load-first.md beside this script. Reads no stdin,
# makes no network call. Needs only sh, sed and awk.
set -eu

shape=${1:?usage: session-start.sh <claude|codex|antigravity|copilot|cursor> <session|subagent>}
event=${2:?usage: session-start.sh <claude|codex|antigravity|copilot|cursor> <session|subagent>}
here=$(cd "$(dirname "$0")" && pwd)

# $(...) drops the file's trailing newline, so the text ends where the wording ends.
text=$(cat "$here/load-first.md")
# GitHub Copilot only: its CLI has a setup command (alynki/alynki#3487). The sentence is swapped here, so
# load-first.md and every other client's wording stay as they are.
if [ "$shape" = copilot ]; then
  text=$(printf '%s' "$text" |
    sed -e "s#In GitHub Copilot (VS Code or CLI): allow Alynki's tools in that client's tool permissions\.#In GitHub Copilot CLI: run /alynki:setup, which allows $(grep -c . "$here/../tools.txt") of Alynki's tools once for this machine. In GitHub Copilot in VS Code: allow Alynki's tools in that client's tool permissions.#")
fi
# JSON string body: escape \ and ", turn newlines into \n, write the em dash as —.
body=$(printf '%s' "$text" |
  sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/—/\\u2014/g' |
  awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }')

case "$shape:$event" in
  claude:session)
    printf '{"hookSpecificOutput": {"hookEventName": "SessionStart", "initialUserMessage": "%s", "additionalContext": "%s"}}\n' "$body" "$body" ;;
  codex:session)
    # Codex drops a SessionStart output carrying a field it does not know, so initialUserMessage is left out.
    printf '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "%s"}}\n' "$body" ;;
  claude:subagent | codex:subagent)
    printf '{"hookSpecificOutput": {"hookEventName": "SubagentStart", "additionalContext": "%s"}}\n' "$body" ;;
  antigravity:session)
    printf '{"injectSteps": [{"systemMessage": {"systemMessage": "%s"}}]}\n' "$body" ;;
  antigravity:subagent)
    # Antigravity has no subagent-start event; nothing to inject.
    printf '{}\n' ;;
  cursor:session | cursor:subagent)
    printf '{"additional_context": "%s"}\n' "$body" ;;
  copilot:session | copilot:subagent)
    printf '{"additionalContext": "%s"}\n' "$body" ;;
  *)
    echo "session-start.sh: unknown shape/event: $shape $event" >&2
    exit 2 ;;
esac
