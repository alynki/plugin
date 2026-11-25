# Alynki setup in Google Antigravity

Allows the Alynki tools listed in the plugin's `tools.txt`, so they stop asking for approval. The tools in
`ask-tools.txt`, which change who has access or manage agents, still ask a person each time.

1. Run this one command, **outside the command sandbox** (it writes
   `~/.gemini/antigravity-cli/settings.json`, which the sandbox cannot), and say that this is why:

   ```
   sh ~/.gemini/config/plugins/alynki/bin/setup-antigravity.sh
   ```

2. Tell the user what it printed, and that the rules apply from a new session. Removing the plugin
   does not remove them; they are the `mcp(alynki_alynki/...)` entries in that file.

Do nothing else: do not edit any settings file yourself, and do not follow the Claude Code steps in
`SKILL.md`. If the command fails, show its output and stop.
