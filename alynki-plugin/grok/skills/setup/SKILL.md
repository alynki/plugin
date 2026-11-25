---
name: setup
description: Set Alynki up in Grok Build on this machine, so its MCP tools run without an approval prompt, the tools that change who has access or manage agents still ask a person each time, and every session loads Alynki's context first. Use only when the user asks for Alynki setup.
disable-model-invocation: true
---

# Alynki setup for Grok Build

Runs the plugin's script, which writes two things in the user's Grok folder (`$GROK_HOME`, else
`~/.grok`): permission rules in `config.toml` (each tool in the plugin's `tools.txt` runs without
asking; each in `ask-tools.txt` asks a person before every call, because it changes who has access to
an organisation's context or manages the agents that act in it), and
`rules/alynki-load-context.md`, which tells every session and subagent to call `load_context` first.
It leaves Grok's `max_output_bytes` as it is: an Alynki page fits Grok's default limit.

## Steps

1. Run `sh "${GROK_PLUGIN_ROOT}/alynki-plugin/grok/setup.sh"`. The user approves that one command.
2. Report the script's output as it is. If it fails, stop: do not edit the files yourself and do not
   try another way.
3. Tell the user: it takes effect in a new session; removing the plugin does not remove it; to undo
   it, run the same command with `--undo`. The rules match any MCP server named `alynki`. The seven
   asking tools are also held by the plugin's hook, which Grok runs only in a trusted folder; without
   it, "Always allow" or always-approve mode stops those seven asking.

## Constraints

- Change nothing but what the script changes. Never turn on always-approve, trust a folder, or touch
  another server, rule or plugin.
