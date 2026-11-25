#!/bin/sh
# Cursor beforeMCPExecution hook: answers "ask" for the Alynki tools in ../ask-tools.txt, printing {} otherwise
# (https://cursor.com/docs/hooks). Cursor's CLI 2026.11.22 ignores this "ask"; the allowlist is what decides there.
# Needs jq; without it, or on any error, Cursor's own approval applies.
set -u
here=$(cd "$(dirname "$0")" && pwd)
tool=$(jq -r 'select(.mcp_server_name == "plugin-alynki-alynki") | .tool_name // empty' 2>/dev/null) || tool=
if [ -n "$tool" ] && grep -qx -- "$tool" "$here/../ask-tools.txt" 2>/dev/null; then
  printf '{"permission": "ask", "user_message": "This Alynki tool changes who has access or manages agents.", "agent_message": "This Alynki tool asks a person each time."}\n'
else
  printf '{}\n'
fi
