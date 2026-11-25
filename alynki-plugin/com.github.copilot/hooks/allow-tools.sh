#!/bin/sh
# GitHub Copilot CLI hooks for Alynki's own tools. They do what /alynki:setup's rules do in Claude Code:
#   allow-tools.sh        permissionRequest: after setup (bin/setup-copilot.sh), approve a tool in tools.txt
#   allow-tools.sh ask    preToolUse: a tool in ask-tools.txt always asks, even where an approval was saved
# Prints nothing otherwise, so Copilot does what it normally does.
# Input is one JSON object on stdin; toolName is "alynki/<tool>" (permissionRequest) or "alynki-<tool>" (preToolUse).
set -u
if [ "${1-}" = ask ]; then
  sep='-' args=',"toolArgs":' list=ask-tools.txt out='{"permissionDecision":"ask","permissionDecisionReason":"This Alynki tool changes who has access or manages agents."}'
else
  [ -f "${COPILOT_HOME:-${HOME:-}/.copilot}/alynki-allow-tools" ] || exit 0
  sep='/' args=',"toolInput":' list=tools.txt out='{"behavior":"allow"}'
fi
root=$(cd "$(dirname "$0")/../.." && pwd) || exit 0
input=$(tr -d '\n')
# Read toolName only from the text ahead of the arguments, so nothing in a call's arguments can name it.
case $input in *"$args"*) head=${input%%"$args"*} ;; *) exit 0 ;; esac
tool=$(printf '%s' "$head" | sed -n 's|.*[{,]"toolName":"alynki'"$sep"'\([a-z_]*\)".*|\1|p')
[ -n "$tool" ] || exit 0
grep -qxF -- "$tool" "$root/$list" 2>/dev/null || exit 0
printf '%s\n' "$out"
