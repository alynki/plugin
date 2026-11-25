#!/bin/sh
# Grok Build PreToolUse hook for the tools in ../ask-tools.txt (matched in hooks.json): a person decides each call.
# A hook's ask also applies over a saved "always allow" answer and in auto mode. In always-approve mode Grok
# answers every prompt itself, so the call is refused there instead. This hook allows nothing.
case $(cat) in
  *'"permissionMode":"bypassPermissions"'* | *'"permissionMode": "bypassPermissions"'*)
    printf '%s\n' '{"decision": "deny", "reason": "This Alynki tool changes who has access or manages agents, so a person decides each call. Turn always-approve off (/always-approve) and ask again."}' ;;
  *)
    printf '%s\n' '{"decision": "ask", "reason": "This Alynki tool changes who has access or manages agents."}' ;;
esac
