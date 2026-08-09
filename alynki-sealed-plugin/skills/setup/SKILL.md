---
name: setup
description: Grant every Alynki MCP tool standing permission on this machine, so Alynki stops prompting for permission in each new repository
---

# Alynki setup

Adds **every** Alynki MCP tool to `permissions.allow` in the user's own settings file,
`~/.claude/settings.json`, so the grant applies everywhere on this machine rather than in one
repository.

Nothing in this skill is specific to a tenant, an operator, a machine or a directory. It writes to
the invoking user's own settings file, wherever that is. There are no hardcoded hostnames, URLs,
tokens or paths.

## Why user scope

Accepting a permission prompt saves the rule to `.claude/settings.local.json` at the root of the git
repository — or, outside a repository, to the directory the session started in. Either way the grant
is local to that place, so a session started anywhere else prompts again. Alynki loads its context
at the start of every session, so a per-place grant is met repeatedly. A rule in
`~/.claude/settings.json` is read everywhere on that machine.

## ⚠️ Identity, not name

A tool's MCP server segment is a normalised string with no marketplace and no provenance. A
user-defined server literally named `alynki`, or a same-named plugin installed from a different
marketplace, produces tool names indistinguishable by pattern from Alynki's own. **A rule that
matches on "looks like Alynki" would grant a stranger's server.**

So this skill recognises **exactly two server segments, by literal string equality, and nothing
else**:

- `plugin_alynki_alynki` — the standard plugin
- `plugin_alynki-sealed_alynki` — the sealed plugin

Any MCP tool in this session whose name is not `mcp__plugin_alynki_alynki__<tool>` or
`mcp__plugin_alynki-sealed_alynki__<tool>` is out of scope, however similar its name looks. Do not
widen this list, and do not infer a third form.

## Steps

1. **Enumerate this session's tools** and keep exactly those matching one of the two forms above,
   by literal prefix equality. If a session has both (unusual, but possible), both are in scope.

   If none match, stop and tell the user neither Alynki plugin is loaded in this session.

2. **Read `~/.claude/settings.json`.** If it does not exist, treat it as `{}`. If it exists but is
   not valid JSON, stop and say so — never overwrite a file you could not parse.

3. **For each server segment found in step 1, add one wildcard entry to `permissions.allow`**:
   `mcp__plugin_alynki_alynki__*` for the standard plugin, `mcp__plugin_alynki-sealed_alynki__*` for
   the sealed plugin. One rule per server present, not one per tool — a tool the server adds later is
   covered without this skill needing to run again. This is a deliberate choice: the server-segment
   match in step 1 is what stops the rule ever reaching a server that is not Alynki's; within that
   boundary, a future Alynki tool is granted the moment it exists rather than reviewed individually.

   Creating `permissions` and `permissions.allow` if absent. Preserve every existing entry and every
   other key in the file. Skip a server whose wildcard rule is already present, or already covered by
   an existing rule — running this a second time must change nothing.

4. **Check `permissions.deny` and `permissions.ask`** (in this file and, if readable, project and
   managed settings) for anything that would shadow the wildcard just granted — those outrank
   `allow`. If a matching deny or ask rule exists, name it and say the grant will not take effect,
   rather than reporting uniform success.

5. **Show the resulting `permissions.allow`** and apply the edit.

6. **Confirm what changed:** which server wildcards were added, which were already present, whether
   any is shadowed by a deny or ask rule, and that the grant is machine-wide, covers every current
   and future Alynki tool, and takes effect in new sessions.

## Constraints

- Write only to `~/.claude/settings.json`. Never touch `settings.local.json`, project settings, or
  managed settings.
- Change no key other than `permissions.allow`.
- Match server segments by literal equality against the two forms above. Never a substring or
  pattern match — the wildcard's safety depends entirely on this match being exact.
- The wildcard's scope ends at `__`: write `mcp__plugin_alynki_alynki__*`, never a rule that could
  also match a different server segment.

## Tell the user afterwards

These rules live in their settings file, not in the plugin, so **removing the plugin does not remove
them**. They can undo the grant with `/permissions`, or by deleting the entries from
`~/.claude/settings.json`.

Running this command itself still prompts once, for its own write to `~/.claude/settings.json` —
`~/.claude` is a protected path and no allow rule can suppress that. It removes every *subsequent*
Alynki prompt, not its own.
