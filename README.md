# Alynki plugin

> Knowledge is inherited, not rediscovered.

The Claude Code plugin for Alynki, the business context layer — it loads your organisation's
governed context into every session: the policy and product context that applies to the scope
your credential holds and, where that scope sits in a workstream, the steps, gates and runs that
define how the work is done. Alynki delivers to a principal only what that principal is granted;
it does not constrain what an agent obtains from other sources.

Two variants ship from this marketplace: **`alynki`** (the standard install) and
**`alynki-sealed`** (for organisations that have opted into sealing — context is decrypted
locally on your machine). Install one or the other, as your Alynki operator directs. Once
installed they behave identically: same tools, same context.

## Install — `alynki` (standard)

The MCP connection itself is **not** bundled in this plugin — a shared, static URL can't carry
a value that differs per tenant (alynki/alynki multi-tenant routing design). Two steps:

```
/plugin marketplace add alynki/plugin
/plugin install alynki@alynki-marketplace
/reload-plugins
```

This installs the skills and hooks (including `/alynki:setup` below) but no MCP tools yet — add
the connection with `claude mcp add`, which natively supports both a per-tenant URL and a custom
auth header in one command:

```
claude mcp add --transport http --scope user alynki \
  https://mcp.alynki.com/<your-tenant>/mcp \
  --header "Authorization: Bearer <your-token>"
```

- **`<your-tenant>`** — the path segment your Alynki operator gives you (it's your organisation's
  own tenant identifier, e.g. `acme`).
- **`<your-token>`** — a pinned token from your Alynki operator. **To sign in with your own
  identity instead**, omit `--header` entirely; Claude Code offers OAuth on first use.
- **`--scope user`** makes the connection available in every project on this machine, matching
  how the plugin's own hooks always load. Use `--scope project` instead to scope it to one repo.
- **Automation (CI, an agent) always uses a pinned token** — sign-in needs a human in a browser.

This is standard Claude Code functionality (`claude mcp add --help`), not plugin-specific — the
same shape as any other custom MCP connector. Revoke or rotate with `claude mcp remove alynki`
then re-add.

## Install — `alynki-sealed`

For organisations that have opted into sealing. **A local process, `alynki-local`, runs on
your machine**: Claude Code launches it for each session, it calls the same hosted Alynki
endpoint, and it decrypts your context locally. The hosted service stores and serves
ciphertext only; your organisation key never leaves this machine.

`alynki-local` must be installed and on your `PATH` before the plugin can serve context.
Your Alynki operator provides the binary for your platform — installing the plugin does not
install it. Confirm before continuing:

```sh
which alynki-local     # must print a path
```

(Building from source — `go install ./cmd/alynki-local` from an `mcp-server` checkout — is an
operator/developer path, not a colleague path; per-platform packaging and signing are tracked at
alynki/alynki#231.) Then:

```
/plugin marketplace add alynki/plugin
/plugin install alynki-sealed@alynki-marketplace
/reload-plugins
```

Installing prompts for four values — **tenant is required, the other three are optional**
(every one of the optional three can instead be set up by running `alynki-local` directly, once,
from a terminal):

- **Alynki tenant** — the path segment your Alynki operator gives you (your organisation's own
  tenant identifier, e.g. `acme`). Unlike the standard variant, this plugin *does* bundle the MCP
  connection — it spawns `alynki-local` locally and hands it this value as an environment
  variable, so the tenant lives in the same place as everything else here (Claude Code exports
  every one of these fields to the spawned process; no separate `claude mcp add` step needed for
  this variant).
- **Alynki API token** — leave blank and run `alynki-local login` instead to sign in with your
  own identity (same guidance as the standard install above: an existing colleague with a pinned
  token should keep it, not switch, until identity linking ships). If you do paste a token here,
  it is stored in this plugin's own `settings.json`, plaintext, for the same reason as the
  standard variant — `alynki-local login`'s own credential storage (your OS keychain, with a
  file fallback) is the better place for a long-lived credential when sign-in is available to
  you.
- **Alynki organisation key** and **Alynki key id** — leave both blank and run
  `alynki-local key import` instead (with `ALYNKI_KEY`/`ALYNKI_KEY_ID` set in your shell for that
  one command). The key then lives in `alynki-local`'s own credential store — your OS keychain,
  never this plugin's configuration — rather than here.

Non-interactive form, if you are pasting values directly:

```
claude plugin install alynki-sealed@alynki-marketplace --config tenant=<tenant> --config token=<token> --config key=<key> --config key_id=<key-id>
```

## What it installs

- An MCP connection exposing the Alynki tools. What a session is offered depends on the
  **class of your credential**: an agent (pinned) credential is offered `load_context` and
  `save_context` with **no address argument** — scope comes entirely from the token, so an
  injected instruction has no way to redirect it. A human (interactive) credential is offered
  all twenty-one tools: additionally `list_nodes`, `create_node`, `set_default_context`,
  `update_node`, `delete_node`, `move_node`, the workstream tools (`create_workstream`,
  `load_workstream`, `list_workstreams`, `update_workstream`, `move_workstream`,
  `delete_workstream`, `create_step`, `create_gate`) and the run tools (`create_run`,
  `save_run`, `load_run`, `list_runs`, `delete_run`); one typed prompt per tool (`/load`,
  `/save`, `/create`, `/list`, `/set-default`, `/update`, `/delete`, `/move`,
  `/create-workstream`, `/load-workstream`, `/list-workstreams`, `/update-workstream`,
  `/move-workstream`, `/delete-workstream`, `/create-step`, `/create-gate`, `/create-run`,
  `/save-run`, `/load-run`, `/list-runs`, `/delete-run`), each taking one whole-string
  argument; and the optional whole-path `address` argument (with `run` at a step or a gate).
  The tools that change structure in more than one place — creating a workstream or a run,
  reshaping, moving or deleting a workstream, deleting a run — answer a preview first and act
  only on a second call carrying the `confirm` token the preview returned.
- **Large context is handled for you — on the human (interactive) surface.** A body too large
  for one tool call is sent in chunks (`mode: stage` … `mode: commit`) and a large context is
  served in pages under a cursor the model echoes back; a pinned (agent) session receives its
  payload whole, and an oversized body is refused at the cap rather than staged. The tool descriptions and prompts carry the rules; nothing about it is
  configured here.
- In the standard variant the connection goes directly to Alynki's hosted server; in the
  sealed variant it goes to the local `alynki-local` process, which calls the hosted server,
  decrypts the result, and does the chunking and paging on this machine so the hosted service
  sees only whole ciphertext. The tool names and the rendered payload are the same either way.
- `SessionStart` and `SubagentStart` hooks that instruct every session — and every subagent —
  to call `load_context` first (`SessionStart` emits both `initialUserMessage` and
  `additionalContext`; `SubagentStart` emits `additionalContext`).

⚠️ The sealed variant requires the **`alynki-local` binary on your PATH**; installing the
plugin does not install it. A new sealed capability reaches you only with a redistributed
binary.

## After installing — grant standing permission

The plugin cannot grant its own tools permission: nothing in the plugin manifest can pre-approve
a tool call, and there is no install-time hook. Left alone, each session prompts for `load_context`
the first time it runs, and accepting the prompt saves the grant to that **repository only** — a
session started anywhere else prompts again.

Run once, in any session:

```
/alynki:setup
```

(`/alynki-sealed:setup` for the sealed variant.) It proposes adding every Alynki tool to
`permissions.allow` in your own `~/.claude/settings.json` — machine-wide, not repository-scoped —
and shows the edit before applying it.

⚠️ **This command still prompts once, for its own write.** `~/.claude` is a protected path, so no
allow rule can suppress that prompt. It removes every *subsequent* Alynki prompt, not its own.

To grant it by hand instead of running the command, add to `~/.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "mcp__plugin_alynki_alynki__*"
    ]
  }
}
```

(substitute `plugin_alynki-sealed_alynki` for the sealed variant). This grants every Alynki tool,
including ones added after you run this — the wildcard's `plugin_alynki_alynki` segment is exact,
so it can only ever match Alynki's own server. Preserve any existing `permissions.allow` entries
already in the file.

## Status

- **The hosted endpoint is per-tenant, not one shared URL** —
  `https://mcp.alynki.com/<tenant>/mcp` (multi-tenant routing, alynki/alynki#575/#581). The
  standard variant has no `.mcp.json` of its own; the tenant-scoped URL is supplied by whoever
  installs, via `claude mcp add` (see above). The sealed variant's `alynki-sealed-plugin/.mcp.json`
  builds the same URL from the `tenant` field: `ALYNKI_URL: "https://mcp.alynki.com/${user_config.tenant}/mcp"`.
  For local development against a local server, override with an **uncommitted** working-copy
  change (or, for the standard variant, `claude mcp add` your own local URL directly) — `main`
  only ever carries production.
- **Visibility:** this repository is **private**. Making it public is a deliberate founder
  decision, taken separately. While private, colleagues
  install using their own granted git access (⚠️ if the clone fails with "Repository not
  found", the SSH key GitHub picked lacks access — pass an explicit git URL for the right
  identity).

## Content policy — read before adding anything

**Assume this repository becomes public.** It exists precisely so the plugin can be
installed without access to `alynki/alynki`, which is private.

This repository contains **only** the plugin and its marketplace manifest. The following are
**explicitly excluded** and must never be added: VISION, architecture documents, feature
specifications, patent material, the risk register, competitor analysis — anything carrying
a confidentiality banner. CI greps every push for the banner and fails the build if one
appears.

Nothing customer-specific may appear in the plugin either. The plugin is identical for every
installer; a node label or tenant name in these files would leak one customer's structure to
all others.

## Licence

MIT — see [LICENSE](LICENSE). It covers the plugin configuration in this repository only.
