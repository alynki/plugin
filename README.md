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

```
/plugin marketplace add alynki/plugin
/plugin install alynki@alynki-marketplace
/reload-plugins
```

Installing prompts once for an **optional** Alynki API token.

- **New to Alynki? Leave it blank and sign in with your own identity.** The first tool call
  offers OAuth — a browser opens, you sign in, and Claude Code keeps your session refreshed
  automatically. Nothing is typed here.
- **Already have a pinned token from your Alynki operator, and were using it before this
  version?** Keep using it — paste it here. **Do not switch to sign-in yet**: today, signing in
  resolves to a *new* identity distinct from your existing one, so switching would put you on a
  narrower, freshly-provisioned account rather than the one your operator already scoped for
  you. This is a known limitation, not an oversight (alynki/alynki#398 §5) — it will be lifted
  when identity linking ships.
- **Automation (CI, an agent) always uses a pinned token** — sign-in needs a human in a browser.

⚠️ **A configured token here is stored in plaintext** in this plugin's own `settings.json`, not
your OS keychain — the script that reads it at connect time has no way to read your keychain.
Issue it at the narrowest scope your automation actually needs, and treat it with the same care
as any other plaintext secret on this machine. (Signing in instead avoids this entirely: Claude
Code manages that credential in its own, more private storage.)

Provisioning automation uses the non-interactive form:

```
claude plugin install alynki@alynki-marketplace --config token=<token>
```

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

Installing prompts for three values, **all optional** — every one of them can instead be set up
by running `alynki-local` directly, once, from a terminal:

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
claude plugin install alynki-sealed@alynki-marketplace --config token=<token> --config key=<key> --config key_id=<key-id>
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

- `alynki-plugin/.mcp.json` and `alynki-sealed-plugin/.mcp.json` carry the **live hosted
  endpoint** — `https://mcp.alynki.com/mcp`, a global anycast address in front of the service
  (the path from hostname to serving revision is `alynki/alynki`
  `docs/architecture/dns-and-request-routing.md`). For local development against a local
  server, override the URL to
  `http://127.0.0.1:8080/mcp` as an **uncommitted** working-copy change and add the marketplace
  from the local clone — `main` only ever carries production.
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
