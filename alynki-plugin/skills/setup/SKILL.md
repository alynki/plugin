---
name: setup
description: Grant every Alynki MCP tool standing permission on this machine, so Alynki stops prompting for permission in each new repository
---

# Alynki setup

Adds **every** Alynki MCP tool to `permissions.allow` in the user's own settings file,
`~/.claude/settings.json`, so the grant applies everywhere on this machine rather than in one
repository.

Nothing in this skill is specific to a tenant, an operator, a machine or a directory. It reads the
tools this session actually exposes and writes to the invoking user's own settings file, wherever
that is. There are no hardcoded hostnames, URLs, tokens, paths or tool lists.

## Why user scope

Accepting a permission prompt saves the rule to `.claude/settings.local.json` at the root of the git
repository — or, outside a repository, to the directory the session started in. Either way the grant
is local to that place, so a session started anywhere else prompts again. Alynki loads its context
at the start of every session, so a per-place grant is met repeatedly. A rule in
`~/.claude/settings.json` is read everywhere on that machine.

## Steps

1. **Discover every Alynki tool in this session.** They are the MCP tools whose names begin with
   `mcp__` and whose server segment identifies Alynki. Enumerate them from the session's own tool
   list — do not assume a fixed set, a fixed prefix, or that this is the standard rather than the
   sealed variant. Whatever Alynki tools are present, all of them are in scope: the reads that load
   and address context and the writes that author it.

   If no Alynki tools are present, stop and tell the user the plugin is not loaded in this session.

2. **Read `~/.claude/settings.json`.** If it does not exist, treat it as `{}`. If it exists but is
   not valid JSON, stop and say so — never overwrite a file you could not parse.

3. **Add every tool discovered in step 1 to `permissions.allow`**, creating `permissions` and
   `permissions.allow` if absent. Preserve every existing entry and every other key in the file.
   Skip any tool already listed, and any tool already covered by an existing rule — running this a
   second time must change nothing.

4. **Show the resulting `permissions.allow`** and apply the edit.

5. **Confirm what changed:** which tools were added, which were already granted, and that the grant
   is machine-wide and takes effect in new sessions.

## Constraints

- Write only to `~/.claude/settings.json`. Never touch `settings.local.json`, project settings, or
  managed settings.
- Change no key other than `permissions.allow`.
- Grant exactly the Alynki tools present — never a wildcard that would also cover another server's
  tools.

## Tell the user afterwards

These rules live in their settings file, not in the plugin, so **removing the plugin does not remove
them**. They can undo the grant with `/permissions`, or by deleting the entries from
`~/.claude/settings.json`.
