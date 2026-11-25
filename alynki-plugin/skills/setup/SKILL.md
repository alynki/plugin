---
name: setup
description: Allow 37 Alynki MCP tools without a prompt on this machine, so Alynki stops asking for permission in each new repository, while the seven tools that change who has access still ask a person each time
---

# Alynki setup

Adds an exact-name rule to `permissions.allow` for each of the 37 Alynki MCP tools in
`${CLAUDE_PLUGIN_ROOT}/tools.txt`, and an exact-name rule to `permissions.ask` for each of the seven
in `${CLAUDE_PLUGIN_ROOT}/ask-tools.txt`, in the user's own settings file, `settings.json` in the Claude folder (`$CLAUDE_CONFIG_DIR` when that
variable is set, `~/.claude` otherwise), so the grant applies everywhere on this machine rather than in
one repository.

The seven ask a person before each call because they change who has access to an organisation's
context or manage the agents that act in it (granting, revoking and inviting people; creating,
changing and revoking agents). Claude Code evaluates `deny`, then `ask`, then `allow`, so an ask rule
prompts even where an allow rule or an earlier version's wildcard also matches.

Both lists are files in the plugin, one tool name per line. Every setup (this skill,
`bin/setup-antigravity.sh`) reads them; this skill holds no copy of the names.

Nothing in this skill is specific to a tenant, an operator, a machine or a directory. It writes to
the invoking user's own settings file, wherever that is. There are no hardcoded hostnames, URLs,
tokens or paths.

## Why user scope

Accepting a permission prompt saves the rule to `.claude/settings.local.json` at the root of the git
repository, or, outside a repository, to the directory the session started in. Either way the grant
is local to that place, so a session started anywhere else prompts again. Alynki loads its context
at the start of every session, so a per-place grant is met repeatedly. A rule in the user's
`settings.json` is read everywhere on that machine.

## Identity, not name

A tool's MCP server segment is a normalised string with no marketplace and no provenance. A
user-defined server literally named `alynki`, or a same-named plugin installed from a different
marketplace, produces tool names indistinguishable by pattern from Alynki's own. **A rule that
matches on "looks like Alynki" would grant a stranger's server.**

So this skill recognises **exactly one server segment, by literal string equality, and nothing
else**: `plugin_alynki_alynki`.

Any MCP tool in this session whose name is not `mcp__plugin_alynki_alynki__<tool>` is out of scope,
however similar its name looks. Do not widen this, and do not infer a second form.

## Why the seven ask

With no prompt, text an agent reads (a node body, a run record) could steer an access-changing call
without a person seeing it first. The ask rules put a person in front of each of those calls; the
server's entitlement checks still bound what any call can do.

## Steps

1. **Enumerate this session's tools** and keep those matching `mcp__plugin_alynki_alynki__<tool>`,
   by literal prefix equality. If none match, stop and tell the user the Alynki plugin is not loaded
   in this session.

2. **Read both lists**, `${CLAUDE_PLUGIN_ROOT}/tools.txt` (allowed) and
   `${CLAUDE_PLUGIN_ROOT}/ask-tools.txt` (asking). If either cannot be read, stop and say so. Tell
   the user of any name in the lists that this session does not have, and any matching tool this
   session has that neither list holds; write the lists' names regardless.

3. **Find the settings file.** Run `printf '%s' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"` and use
   `settings.json` in the folder it prints: Claude Code reads its settings from `$CLAUDE_CONFIG_DIR`
   when that variable is set, so a rule written to `~/.claude/settings.json` would not apply there.
   **Read that file.** If it does not exist, treat it as `{}`. If it exists but is
   not valid JSON, stop and say so, and never overwrite a file you could not parse.

4. **Write the rules**, each `mcp__plugin_alynki_alynki__<tool>`, never a wildcard:
   - one rule in `permissions.allow` per tool in `tools.txt`;
   - one rule in `permissions.ask` per tool in `ask-tools.txt`;
   - **remove** from `permissions.allow` the exact rule of any tool in `ask-tools.txt` (version
     0.29 wrote them), and from `permissions.ask` the exact rule of any tool in `tools.txt` (an
     earlier version may have written one), and say which you removed.

   Create `permissions`, `permissions.allow` and `permissions.ask` if absent. Preserve every other
   entry and every other key. Skip a rule already present as that exact string. A wildcard
   `mcp__plugin_alynki_alynki__*` left by an earlier version stays; the ask rules outrank it.
   Running this a second time must change nothing.

5. **Check `permissions.deny` and `permissions.ask`** (in this file and, if readable, project and
   managed settings) for anything that would shadow the allow rules just granted, because those
   outrank `allow`. The seven ask rules of step 4 are this skill's own and are not a shadow. Name
   each other match and say the grant will not take effect for the tools it matches, rather than
   reporting uniform success.

6. **Show the resulting `permissions.allow` and `permissions.ask`** and apply the edit.

7. **Confirm what changed:** how many allow and ask rules were added and how many were already
   present; any rule removed; whether anything is shadowed by a deny or other ask rule; and that the
   grant is machine-wide, allows the 37 tools in `tools.txt`, asks before each call to the seven in
   `ask-tools.txt`, and takes effect in new sessions. A tool the server adds later is not covered
   until a list gains it and this command is run again.

## Constraints

- Write only to the settings file of step 3. Never touch `settings.local.json`, project settings, or
  managed settings.
- Change no key other than `permissions.allow` and `permissions.ask`, and in them add or remove only
  the exact-name rules of step 4. Never remove or rewrite any other entry.
- Match the server segment by literal equality against the form above, never a substring or
  pattern match.

## Tell the user afterwards

These rules live in their settings file, not in the plugin, so **removing the plugin does not remove
them**. They can undo the grant with `/permissions`, or by deleting the entries from
the settings file of step 3. Deleting an ask rule removes the prompt on that tool.

Running this command itself still prompts once, for its own write to that settings file: the Claude
folder is a protected path and no allow rule can suppress that. It removes every *subsequent*
Alynki prompt except the seven asking tools', not its own.
