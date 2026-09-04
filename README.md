# Alynki plugin

> Knowledge is inherited, not rediscovered.

The Claude Code plugin for Alynki, the business context layer — it loads your organisation's
governed context into every session: the policy and product context that applies to the scope
your credential holds and, where that scope sits in a workflow, the steps, checks and runs that
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

That is the whole install. **The MCP connection is bundled** — there is no separate
`claude mcp add` step, and nothing to type but your own credential.

**To sign in with your own identity**, install and use it: the first call returns 401 and Claude
Code offers OAuth. Nothing to configure.

**If your operator issued you a pinned token**, put it in the plugin's **Alynki API token** field
(`/plugin`, or `--config token=…` on install). Automation — CI, an agent — always uses a pinned
token, since sign-in needs a human in a browser.

Both credential paths run through one plugin because the connection uses a `headersHelper` script
rather than a static header: it emits the `Authorization` header only when a token is configured,
and `{}` otherwise. ⚠️ A **static** `headers.Authorization` key would disable Claude Code's OAuth
fallback unconditionally, *even when its interpolated value is empty* — so the choice has to be made
at connection time, from configuration, never from a key in `.mcp.json`.

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

Installing prompts for three values, **all optional** (every one can instead be set up by running
`alynki-local` directly, once, from a terminal). ⚠️ **No tenant is asked for.** Your tenant is
resolved from your credential, server-side — see *Status* below.

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
  all twenty-six tools: additionally `list_nodes`, `create_node`, `set_default_context`,
  `update_node`, `delete_node`, `move_node`, the workflow tools (`create_workflow`,
  `load_workflow`, `list_workflows`, `update_workflow`, `move_workflow`,
  `delete_workflow`, `create_step`, `create_check`), the run tools (`create_run`,
  `save_run`, `load_run`, `list_runs`, `delete_run`), the non-composing reads
  (`load_check`, `load_step`, `list_checks` — one node's own body, or a workflow's check
  metadata, without walking the ancestor chain; `load_step` and `load_check` also take an
  optional `run`, which appends that run's TRAIL — the whole record, what was consumed and
  what was produced, of every step at or before this one — so an agent arriving cold can
  work a step or judge a check from a single read) and the decision tools (`save_check`,
  `list_pending_checks`); one typed prompt per tool (`/load`,
  `/save`, `/create`, `/list`, `/set-default`, `/update`, `/delete`, `/move`,
  `/create-workflow`, `/load-workflow`, `/list-workflows`, `/update-workflow`,
  `/move-workflow`, `/delete-workflow`, `/create-step`, `/create-check`, `/create-run`,
  `/save-run`, `/load-run`, `/list-runs`, `/delete-run`, `/load-check`, `/load-step`,
  `/list-checks`, `/save-check`, `/list-pending-checks`), each taking one whole-string argument; and the optional whole-path `address` argument (with `run` at a step or a check).
  ⚠️ A check's read carries the run's work and deliberately carries NO governing context
  above it — not the workflow manual, not organisational context, not even its own step's
  body — because a check is a yes/no question about work that was produced.
  ⚠️ **A run stops at a check nobody has approved.** While any check on step N of a run is
  pending or rejected, `save_run` on a later step of that run is *refused* — the hold is
  enforced by the server, not advisory. A check declared `autonomous` is evaluated and
  decided by the model in the same session; a check declared `human` waits for a person,
  and `list_pending_checks` — no argument, no filter — is how a session finds every human
  check whose step is recorded and whose decision is still open. `save_check` records it:
  approving, rejecting and withdrawing are the same call. ⚠️ Rewriting a step's record
  voids that step's decisions, so its checks are decided again. On the **sealed** variant a
  check's findings are encrypted on your machine like any other body, while the decision
  itself travels in clear — the hosted server is the thing that holds the run on it.
  The tools that change structure in more than one place — creating a workflow or a run,
  reshaping, moving or deleting a workflow, deleting a run — answer a preview first and act
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

⚠️ **And that is not only about new TOOLS.** The sealed variant declares its tool descriptions
and renders its prompts *locally*, inside `alynki-local` — so a change to the wording of either
also reaches you only with a redistributed binary. Nothing warns you: the staleness nudge
compares tool **schemas**, and a re-worded description or prompt leaves the schema untouched.
V2.1.3 is the first release of exactly that shape — no new tool, no schema change, different
words — so **reinstall `alynki-local` when the sealed plugin's version moves**, not only when a
tool is added. A changed tool *result* is the opposite case and needs no rebuild: results are
relayed from the hosted server verbatim.

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

- **One shared endpoint — `https://mcp.alynki.com/mcp`.** Your tenant is resolved server-side from
  the credential you present, never from the URL, so **neither variant asks you for a tenant** and
  both `.mcp.json` files carry the same literal URL. The per-tenant paths that existed briefly
  (`https://mcp.alynki.com/<tenant>/mcp`) are retired and now 404.
  ⚠️ This is not only a convenience: **RFC 9728 §3.3 requires** the `resource` identifier a client
  is handed to be identical to the URL it dialled, so one shared dialled URL and one shared resource
  identifier are the same decision. For local development against a local server, override with an
  **uncommitted** working-copy change — `main` only ever carries production.
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
