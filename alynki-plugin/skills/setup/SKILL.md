---
name: setup
description: Allow every Alynki MCP tool, all 44, without a prompt on this machine, so Alynki stops asking for permission in each new repository
---

# Alynki setup

Adds an exact-name rule for **every** Alynki MCP tool to `permissions.allow` in the user's own
settings file, `~/.claude/settings.json`, so the grant applies everywhere on this machine rather
than in one repository. All 44 tools are allowed, the seven that change who has access included.

The list of tools is one file, `${CLAUDE_PLUGIN_ROOT}/tools.txt` in the plugin: one tool name per
line. Every setup (this skill, `bin/setup-antigravity.sh`) reads that file; this skill holds no copy
of the names.

Nothing in this skill is specific to a tenant, an operator, a machine or a directory. It writes to
the invoking user's own settings file, wherever that is. There are no hardcoded hostnames, URLs,
tokens or paths.

## Why user scope

Accepting a permission prompt saves the rule to `.claude/settings.local.json` at the root of the git
repository, or, outside a repository, to the directory the session started in. Either way the grant
is local to that place, so a session started anywhere else prompts again. Alynki loads its context
at the start of every session, so a per-place grant is met repeatedly. A rule in
`~/.claude/settings.json` is read everywhere on that machine.

## Identity, not name

A tool's MCP server segment is a normalised string with no marketplace and no provenance. A
user-defined server literally named `alynki`, or a same-named plugin installed from a different
marketplace, produces tool names indistinguishable by pattern from Alynki's own. **A rule that
matches on "looks like Alynki" would grant a stranger's server.**

So this skill recognises **exactly one server segment, by literal string equality, and nothing
else**: `plugin_alynki_alynki`.

Any MCP tool in this session whose name is not `mcp__plugin_alynki_alynki__<tool>` is out of scope,
however similar its name looks. Do not widen this, and do not infer a second form.

## Trade-off the user accepts

With no prompt, text an agent reads (a node body, a run record) can steer an access-changing call
without a person seeing it first. The server's entitlement checks still
bound what that call can do. Say so when you report.

## Steps

1. **Enumerate this session's tools** and keep those matching `mcp__plugin_alynki_alynki__<tool>`,
   by literal prefix equality. If none match, stop and tell the user the Alynki plugin is not loaded
   in this session.

2. **Read the list**, `${CLAUDE_PLUGIN_ROOT}/tools.txt`. If it cannot be read, stop and say so. Tell
   the user of any name in the list that this session does not have, and any matching tool this
   session has that the list lacks; write the list's names regardless.

3. **Read `~/.claude/settings.json`.** If it does not exist, treat it as `{}`. If it exists but is
   not valid JSON, stop and say so, and never overwrite a file you could not parse.

4. **Add one exact-name rule per listed tool to `permissions.allow`**:
   `mcp__plugin_alynki_alynki__<tool>`, never a wildcard. Create `permissions` and
   `permissions.allow` if absent. Preserve every existing entry and every other key. Skip a rule
   already present as that exact string. A machine set up by an earlier version holds the wildcard
   `mcp__plugin_alynki_alynki__*` and exact-name ask rules: leave the wildcard in place and **remove
   every `permissions.ask` entry equal to `mcp__plugin_alynki_alynki__<tool>` for a tool in the
   list** (it would still prompt, because ask outranks allow), and say you did. Running this a second time must change nothing.

5. **Check `permissions.deny` and `permissions.ask`** (in this file and, if readable, project and
   managed settings) for anything that would shadow the rules just granted, because those outrank
   `allow`. Name each match and say the grant will not take effect for the tools it matches, rather
   than reporting uniform success.

6. **Show the resulting `permissions.allow`** and apply the edit.

7. **Confirm what changed:** how many rules were added and how many were already present; any ask
   rule removed; whether anything is shadowed by a deny or ask rule; and that the grant is
   machine-wide, covers the 44 tools in the list, and takes effect in new sessions. A tool the
   server adds later is not covered until the list gains it and this command is run again.

## Constraints

- Write only to `~/.claude/settings.json`. Never touch `settings.local.json`, project settings, or
  managed settings.
- Change no key other than `permissions.allow` and `permissions.ask`; in `permissions.ask` remove
  only the exact-name rules of step 4. Never remove or rewrite any other entry.
- Match the server segment by literal equality against the form above, never a substring or
  pattern match.

## Tell the user afterwards

These rules live in their settings file, not in the plugin, so **removing the plugin does not remove
them**. They can undo the grant with `/permissions`, or by deleting the entries from
`~/.claude/settings.json`.

Running this command itself still prompts once, for its own write to `~/.claude/settings.json`:
`~/.claude` is a protected path and no allow rule can suppress that. It removes every *subsequent*
Alynki prompt, not its own.
