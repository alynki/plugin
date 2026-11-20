#!/bin/sh
# Prints the "call load_context first" wording as a client's hook output.
#   session-start.sh <shape> <event>
#   shape: claude (Claude Code and Codex), antigravity, copilot
#   event: session, subagent
# The wording lives only in load-first.md beside this script. Reads no stdin,
# makes no network call. Needs only sh, sed and awk.
set -eu

shape=${1:?usage: session-start.sh <claude|antigravity|copilot> <session|subagent>}
event=${2:?usage: session-start.sh <claude|antigravity|copilot> <session|subagent>}
here=$(cd "$(dirname "$0")" && pwd)

# $(...) drops the file's trailing newline, so the text ends where the wording ends.
text=$(cat "$here/load-first.md")
# JSON string body: escape \ and ", turn newlines into \n, write the em dash as —.
body=$(printf '%s' "$text" |
  sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/—/\\u2014/g' |
  awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }')

case "$shape:$event" in
  claude:session)
    printf '{"hookSpecificOutput": {"hookEventName": "SessionStart", "initialUserMessage": "%s", "additionalContext": "%s"}}\n' "$body" "$body" ;;
  claude:subagent)
    printf '{"hookSpecificOutput": {"hookEventName": "SubagentStart", "additionalContext": "%s"}}\n' "$body" ;;
  antigravity:session)
    printf '{"injectSteps": [{"systemMessage": {"systemMessage": "%s"}}]}\n' "$body" ;;
  antigravity:subagent)
    # Antigravity has no subagent-start event; nothing to inject.
    printf '{}\n' ;;
  copilot:session | copilot:subagent)
    printf '{"additionalContext": "%s"}\n' "$body" ;;
  *)
    echo "session-start.sh: unknown shape/event: $shape $event" >&2
    exit 2 ;;
esac
