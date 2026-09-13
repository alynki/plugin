---
name: setup
description: Grant every Alynki MCP tool standing permission on this machine, so Alynki stops prompting for permission in each new repository — while the six tools that change who has access still ask each time
---

# Alynki setup

Adds **every** Alynki MCP tool to `permissions.allow` in the user's own settings file,
`~/.claude/settings.json`, so the grant applies everywhere on this machine rather than in one
repository — and adds six exact-name rules to `permissions.ask` so the tools that change who has
access, or create credentials, still prompt before each call.

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

## The human gate — six tools that always ask

These six tools change who has access to an organisation's context, or create a credential. Each
gets an exact-name rule in `permissions.ask`, under every server segment found in step 1:

- `grant_principal`
- `revoke_principal`
- `invite_principal`
- `revoke_principal_invite`
- `create_principal_agent`
- `revoke_principal_agent`

For the standard plugin that is `mcp__plugin_alynki_alynki__grant_principal` and so on; for the
sealed plugin, `mcp__plugin_alynki-sealed_alynki__grant_principal` and so on. The sealed plugin gets
all six too, `create_principal_agent` included, although the server refuses that tool on a sealed
tenant — the two plugins carry the same gate.

Claude Code evaluates `deny`, then `ask`, then `allow`, so a matching ask rule prompts even though
the wildcard allow also matches. The list is exactly these six: do not add to it, drop from it, or
write it as a pattern.

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

   **Then, for the same server segments, add the six ask rules** of *The human gate* to
   `permissions.ask` — exact names, `mcp__<segment>__<tool>`, never a wildcard.

   Create `permissions`, `permissions.allow` and `permissions.ask` if absent. Preserve every existing
   entry and every other key in the file. Skip a server whose wildcard rule is already present, or
   already covered by an existing rule; skip each ask rule already present as that exact string. A
   machine holding only the wildcard from an earlier run is missing its ask rules: add them — that
   machine is upgraded, not reported as already done. Running this a second time must change nothing.

4. **Check `permissions.deny` and `permissions.ask`** (in this file and, if readable, project and
   managed settings) for anything that would shadow the wildcard just granted — those outrank
   `allow`. **Exempt exactly the six ask rules of *The human gate*, for the server segments found in
   step 1**: they are this skill's own, and prompting on those tools is their purpose, not a failed
   grant. Any other matching deny or ask rule — including an ask rule on a different Alynki tool, or
   one written as a pattern — name it and say the grant will not take effect for the tools it
   matches, rather than reporting uniform success.

5. **Show the resulting `permissions.allow` and `permissions.ask`** and apply the edit.

6. **Confirm what changed:** which server wildcards were added and which were already present;
   which ask rules were added and which were already present; whether anything is shadowed by a
   deny or ask rule other than the six exempted in step 4; and that the grant is machine-wide,
   covers every current and future Alynki tool, prompts before each call to the six gated tools, and
   takes effect in new sessions.

## Constraints

- Write only to `~/.claude/settings.json`. Never touch `settings.local.json`, project settings, or
  managed settings.
- Change no key other than `permissions.allow` and `permissions.ask`, and within `permissions.ask`
  add only the six rules of *The human gate*. Never remove or rewrite an existing entry in either.
- Match server segments by literal equality against the two forms above. Never a substring or
  pattern match — the wildcard's safety depends entirely on this match being exact.
- The wildcard's scope ends at `__`: write `mcp__plugin_alynki_alynki__*`, never a rule that could
  also match a different server segment.

## Tell the user afterwards

These rules live in their settings file, not in the plugin, so **removing the plugin does not remove
them**. They can undo the grant with `/permissions`, or by deleting the entries from
`~/.claude/settings.json`. Deleting an ask rule removes the prompt on that tool.

The ask rules are a gate in this client, and no more than Claude Code documents: a tool matched by
an explicit ask rule is one no permission mode auto-approves, `bypassPermissions` included;
`dontAsk` auto-denies every call that would otherwise prompt; and a non-interactive `-p` run without
`--permission-prompt-tool` has no prompt to answer. Another MCP client, or a machine that has not
run this command, has no gate.

Running this command itself still prompts once, for its own write to `~/.claude/settings.json` —
`~/.claude` is a protected path and no allow rule can suppress that. It removes every *subsequent*
Alynki prompt except the six gated tools', not its own.
