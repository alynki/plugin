---
name: alynki-setup
description: Allow 37 Alynki MCP tools without a prompt in Cursor on this machine, while the seven tools that change who has access or manage agents are left to ask
disable-model-invocation: true
---

# Alynki setup for Cursor

Run this one command with the shell tool, where `<plugin>` is the folder two levels above this file's
`skills` folder (the one holding `tools.txt`):

```sh
sh "<plugin>/cursor/setup.sh"
```

It merges exact entries into `mcpAllowlist` in the user's `~/.cursor/permissions.json`. Run it even if
`load_context` was refused for permission: this is what allows it.

- Edit no file yourself, and never use Run Everything or `--force` to get around a prompt.
- Cursor may ask the person to approve the command, because it writes outside the project. That is theirs to answer.
- Then tell the person exactly what the script printed, including every warning and both notes, and that
  a new chat picks up the change. If it failed, give them its message and change nothing.
- To undo, they delete the `plugin-alynki-alynki:` entries from `~/.cursor/permissions.json` (and the
  `mcpAllowlist` key if nothing else is left, which returns the list in Cursor Settings).
