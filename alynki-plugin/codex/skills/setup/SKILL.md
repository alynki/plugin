---
name: setup
description: Allow Alynki's MCP tools in Codex on this machine without an approval prompt, while the tools that change who has access or manage agents still ask a person each time. Use only when the user asks for Alynki setup.
---

# Alynki setup for Codex

Writes the Alynki plugin's tool policy into the user's `config.toml`: each tool in the plugin's
`tools.txt` runs without asking, and each tool in `ask-tools.txt` asks a person before every call,
because it changes who has access to an organisation's context or manages the agents that act in it.
A tool neither list names is left to Codex's own default.

## Steps

1. Run `sh <this skill's folder>/../../setup.sh`, with the absolute path. It writes
   `$CODEX_HOME/config.toml` (`~/.codex/config.toml` when unset), which is outside the workspace
   sandbox, so request escalated permissions for exactly that command. The user approves it once.
2. Report the script's output as it is. If it fails, stop: do not edit the file yourself and do not
   try another way.
3. Tell the user: the setting takes effect in a new session; removing the plugin does not remove it;
   to undo it, delete the `[plugins."alynki@alynki-marketplace".mcp_servers.alynki...]` tables from
   that file. Hook trust is separate and stays theirs: Codex asks them to review the plugin's hooks.

## Constraints

- Change nothing but what the script changes. Never trust hooks, change the sandbox or the approval
  policy, or touch another server or plugin.
