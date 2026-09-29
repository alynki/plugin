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

## Credential paths

Both variants offer the same two paths to every colleague, and a pinned token always wins over
sign-in when both are present:

```mermaid
---
title: The two credential paths — pinned token vs OAuth sign-in
---
graph TB
  cc["Claude Code — the MCP client"]
  local[("alynki-local — sealed variant only, decrypts locally")]
  helper{"headersHelper script, runs on every call"}
  decide{"Pinned token configured?"}
  hdr["Emits Authorization: Bearer TOKEN"]
  empty["Emits {} — no header"]
  srv["alynki-mcp — https://mcp.alynki.com/mcp"]
  unauth["Server replies 401"]
  oauth["Claude Code's native OAuth 2.1 discovery, then browser sign-in"]

  cc -->|"standard variant: direct"| helper
  cc -.->|"sealed variant: routed through the local process first"| local
  local -->|"same header logic, run on this machine"| helper
  helper --> decide
  decide -->|"yes: an agent revealed in the app, or operator-issued"| hdr
  decide -->|"no"| empty
  hdr -->|"call carries Authorization"| srv
  empty -->|"call carries no Authorization"| srv
  srv -->|"token valid: serves the call"| cc
  srv -->|"no token: refuses"| unauth
  unauth -->|"triggers"| oauth
  oauth -->|"signs in once; the OAuth token is then used on later calls"| cc
```

Key: rectangle — a process or service; diamond — a decision; cylinder — a local, on-machine
credential store (sealed variant only); dashed edge — sealed-variant-only routing.

This mechanism is unchanged for an agent working a run unattended: whatever launches the headless
session, its only credential is its pinned token, supplied the same way as any other pinned
session, so it loads context and works the run without ever seeing a browser sign-in prompt.

## Install — `alynki` (standard)

```
/plugin marketplace add alynki/plugin
/plugin install alynki@alynki-marketplace
/reload-plugins
```

That is the whole install. **The MCP connection is bundled** — there is no separate
`claude mcp add` step, and nothing to type but your own credential.

**To sign in with your own identity**, install and use it — nothing to configure; see
*Credential paths* above.

**If you hold a pinned token** — an agent you created and revealed in the Alynki app (it expires 90
days after the reveal), or one your operator issued — put it in the plugin's **Alynki API token** field
(`/plugin`, or `--config token=…` on install). Automation — CI, an agent — always uses a pinned
token, since sign-in needs a human in a browser.

⚠️ One plugin serves both paths because the connection uses a `headersHelper` script rather than a
static header. A **static** `headers.Authorization` key would disable Claude Code's OAuth fallback
unconditionally, *even when its interpolated value is empty* — so the choice has to be made at
connection time, from configuration, never from a key in `.mcp.json`.

## Install — `alynki-sealed`

For organisations that have opted into sealing. **A local process, `alynki-local`, runs on
your machine**: Claude Code launches it for each session, it calls the same hosted Alynki
endpoint, and it decrypts your context locally. The hosted service stores and serves
ciphertext only; your organisation key never leaves this machine.

⚠️ **The trade-off: sealing needs that local process, so it works only in clients that can run
one** — Claude Code and other CLI-class clients. **Hosted chat apps cannot use it:** claude.ai
on the web, Desktop and mobile connect to the hosted endpoint directly and run no local process,
so a sealed organisation's context is structurally unavailable there, and the Alynki browser app
is unavailable to a sealed organisation too. An organisation that needs those surfaces uses the
standard variant.

`alynki-local` must be installed and on your `PATH` before the plugin can serve context.
Your Alynki operator provides the binary for your platform — installing the plugin does not
install it. Confirm before continuing:

```sh
which alynki-local     # must print a path
```

(Building from source — `go install ./cmd/alynki-local` from an `alynki/server` checkout — is an
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
  own identity; an existing colleague with a pinned token keeps it, not switches, until identity
  linking ships. A token pasted here is stored in this plugin's own `settings.json`, plaintext —
  `alynki-local login`'s own credential store (your OS keychain, with a file fallback) is the
  better place for a long-lived credential.
- **Alynki organisation key** and **Alynki key id** — leave both blank and run
  `alynki-local key import` instead (with `ALYNKI_KEY`/`ALYNKI_KEY_ID` set in your shell). The
  key then lives in `alynki-local`'s own credential store — your OS keychain, never this
  plugin's configuration.

Non-interactive form, if you are pasting values directly:

```
claude plugin install alynki-sealed@alynki-marketplace --config token=<token> --config key=<key> --config key_id=<key-id>
```

## What it installs

- An MCP connection exposing the Alynki tools. What a session is offered depends on the
  **class of your credential**: an agent (pinned) credential — including one working a run
  unattended, on someone else's behalf — is offered exactly **nine tools**: `load_context`,
  `save_context`, `list_ready_runs`, `start_run`, `load_run`, `load_step`, `load_check`,
  `save_run` and `save_check`. `load_context` and `save_context` take **no address argument** —
  scope comes entirely from the token, so an injected instruction has no way to redirect it; the
  run tools take only a run's own workflow and label, or a step's or check's address, handed to
  the agent by a run's own next action, never composed by the agent itself. No authoring,
  deletion, move, people or agent tool is served to a pinned credential — calling one is the same
  refusal as calling a tool that does not exist. A human (interactive) credential is offered all
  **thirty-seven** tools (the same nine, plus every node, workflow, people and agent tool). Every
  tool but the queue pair (`list_ready_runs`, `start_run`) has a matching typed slash prompt
  taking one whole-string argument; that pair is instead covered by one composite prompt,
  **`work-run`** — thirty-six prompts in all, interactive sessions only, since prompts are never
  offered to a pinned credential. What each tool does, how confirm tokens, the run lease, the
  context token, run holds and non-composing reads work, and how large a body it can carry are
  the server's own contract, not this plugin's — see `alynki/alynki`
  `docs/architecture/run-continuation.md` and `docs/architecture/tool-descriptions.md`.
- **Large context is chunked and paged for you on the human surface**; a pinned (agent) session
  receives its payload whole. The tool descriptions and prompts carry the exact rules.
- In the standard variant the connection goes directly to Alynki's hosted server; in the
  sealed variant it goes to the local `alynki-local` process, which calls the hosted server,
  decrypts the result, and does the chunking and paging on this machine so the hosted service
  sees only whole ciphertext. The rendered payload is the same either way. **The run surface
  above is the standard variant's**: Alynki serves runs to unsealed organisations only, so
  `alynki-local` mirrors none of it. A sealed session is offered thirty-five tools (no
  `list_ready_runs`, no `start_run`) and thirty-five prompts (no `work-run`), and a sealed agent
  (pinned) credential keeps `load_context` and `save_context` only.
- `SessionStart` and `SubagentStart` hooks that instruct every session — and every subagent —
  to call `load_context` first (`SessionStart` emits both `initialUserMessage` and
  `additionalContext`; `SubagentStart` emits `additionalContext`). The same text is served to
  both credential classes: it names no tool, so it stays accurate whichever surface — nine tools
  or thirty-seven — the session was actually given.

⚠️ A new sealed capability reaches you only with a redistributed `alynki-local` binary — that is
not only about new TOOLS. The sealed variant declares its tool descriptions,
renders its prompts and answers the server's own `instructions` string *locally*, inside
`alynki-local` — so a change to the wording of any of the three also reaches you only with a
redistributed binary. Nothing warns you of a wording-only change: the staleness nudge compares
tool **schemas** byte-for-byte, and a re-worded description, prompt or instructions string leaves
the schema untouched — an older `alynki-local` keeps serving the stale wording rather than
mis-declaring it. **Reinstall `alynki-local` whenever the sealed plugin's version moves**, not
only when a tool is added. A genuine schema change is the one case an old binary catches itself:
it withholds the changed tool — one `OUT OF DATE` log line — until rebuilt. A changed tool
*result*, by contrast, needs no rebuild: results are relayed from the hosted server verbatim.

## Working a run

A run (a workflow's steps and checks, in progress against one label) is worked the same way by
a person or an agent: load context, take the run's lease with `start_run`, then follow each
returned next action — `load_step`/`save_run`, or `load_check`/`save_check` — to a stop.

- **In an interactive session**, use the `work-run` prompt. It takes two arguments — the
  workflow's address and the run's label — loads context, calls `start_run`, and works the run
  to a stop for you. It is interactive only: an agent (pinned) credential is never offered any
  prompt. Unattended work instead runs through `alynki-controller`, a separate customer-side
  piece, not part of this plugin: it polls Alynki's own controller API (never MCP — a different
  credential, a different surface entirely) for ready runs and starts one headless session per
  run it reserves; that session then calls `load_context` and `start_run` over MCP exactly as an
  interactive one does.
- **A pinned agent's session** gets, from `load_context`'s last page, a `context_token` that
  every run, step and check tool then requires; from `start_run`, a `lease_id` that every write
  then requires, plus the run's working instructions and its first next action; and, on every
  write, the next action to make — or a stop, such as **held for a person** (a human check's
  evaluation was just written, or a limit was reached) or **complete**. Following the next
  action verbatim, to a stop, is the whole loop; no tool call is ever inferred from scratch.
- **A human check is decided in the app only, by a person, never over MCP** — by any credential,
  pinned or interactive. `save_check` records a human check's evaluation, and that alone hands
  the run to a person and ends the agent's turn; deciding it (`approved`) is refused and says so.
- **A revoked agent is kept, never deleted.** Revoking removes what it can reach; the credential
  itself, and every run record it left behind, stays for the record and shows as revoked in the
  Alynki app.

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

It also adds six exact-name rules to `permissions.ask`, so the tools that change who has access or
create a credential — `grant_principal`, `revoke_principal`, `invite_principal`,
`revoke_principal_invite`, `create_principal_agent` and `revoke_principal_agent` — still prompt
before every call. Claude Code evaluates deny, then ask, then allow, so an ask rule wins over the
wildcard. Re-running the command adds any ask rule that is missing and changes nothing else; a
machine set up before these rules existed needs it run once more. ⚠️ The gate lives in this client:
a non-interactive `-p` run without `--permission-prompt-tool` cannot answer the prompt, `dontAsk`
denies these calls, and another MCP client may not prompt at all.

⚠️ **This command still prompts once, for its own write.** `~/.claude` is a protected path, so no
allow rule can suppress that prompt. It removes every *subsequent* Alynki prompt, not its own.

To grant it by hand instead of running the command, add to `~/.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "mcp__plugin_alynki_alynki__*"
    ],
    "ask": [
      "mcp__plugin_alynki_alynki__grant_principal",
      "mcp__plugin_alynki_alynki__revoke_principal",
      "mcp__plugin_alynki_alynki__invite_principal",
      "mcp__plugin_alynki_alynki__revoke_principal_invite",
      "mcp__plugin_alynki_alynki__create_principal_agent",
      "mcp__plugin_alynki_alynki__revoke_principal_agent"
    ]
  }
}
```

(substitute `plugin_alynki-sealed_alynki` for the sealed variant, in all seven entries). This grants
every Alynki tool, including ones added after you run this — the wildcard's `plugin_alynki_alynki`
segment is exact, so it can only ever match Alynki's own server — and keeps the prompt on the six
access-changing tools. Preserve any existing `permissions.allow` and `permissions.ask` entries
already in the file.

## Status

- **One shared endpoint — `https://mcp.alynki.com/mcp`.** Your tenant is resolved server-side from
  the credential you present, never from the URL, so **neither variant asks you for a tenant** and
  both `.mcp.json` files carry the same literal URL. ⚠️ Not only a convenience: **RFC 9728 §3.3
  requires** the `resource` identifier a client is handed to be identical to the URL it dialled,
  so one shared dialled URL and one shared resource identifier are the same decision. For local
  development against a local server, override with an **uncommitted** working-copy change —
  `main` only ever carries production.
- **Visibility:** this repository is **private**; making it public is a deliberate founder
  decision, taken separately. While private, colleagues install using their own granted git
  access (⚠️ a clone failing with "Repository not found" means the SSH key GitHub picked lacks
  access — pass an explicit git URL for the right identity).

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
