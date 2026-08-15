# Alynki plugin

The Claude Code plugin for Alynki — loads your team's shared product context into every
session, scoped to your token.

Two variants ship from this marketplace: **`alynki`** (the standard install) and
**`alynki-sealed`** (for organisations that have opted into sealing — context is decrypted
locally on your machine). Install one or the other, as your Alynki operator directs. Once
installed they behave identically: same tool, same context.

## Install — `alynki` (standard)

```
/plugin marketplace add alynki/plugin
/plugin install alynki@alynki-marketplace
/reload-plugins
```

Installing prompts once for your Alynki API token (issued to you by your Alynki operator).
The token is masked and stored in your OS keychain — no config file is edited by hand.

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
For now, build it from the `mcp-server` repository:

```
go install github.com/alynki/mcp-server/cmd/alynki-local@latest
```

(or `go install ./cmd/alynki-local` from a checkout — per-platform packaging and signing
are tracked upstream). Then:

```
/plugin marketplace add alynki/plugin
/plugin install alynki-sealed@alynki-marketplace
/reload-plugins
```

Installing prompts for three values, issued to you by your Alynki operator:

- **Alynki API token** — masked, stored in your OS keychain.
- **Alynki organisation key** — masked, stored in your OS keychain. It is handed only to
  the local `alynki-local` process and is never sent to Alynki.
- **Alynki key id** — the (non-secret) identifier of that key.

Non-interactive form:

```
claude plugin install alynki-sealed@alynki-marketplace --config token=<token> --config key=<key> --config key_id=<key-id>
```

## What it installs

- An MCP connection exposing the Alynki tools. What a session is offered depends on the
  **class of your credential**: an agent (pinned) credential is offered `load_context` and
  `save_context` with **no address argument** — scope comes entirely from the token, so an
  injected instruction has no way to redirect it. A human (interactive) credential is
  additionally offered `list_nodes`, `create_context`, the four typed prompts (`/load`,
  `/save`, `/create`, `/list`) and the optional whole-path `address` argument.
- **Large context is handled for you.** A body too large for one tool call is sent in chunks
  (`mode: stage` … `mode: commit`) and a large context is served in pages under a cursor the
  model echoes back. The tool descriptions and prompts carry the rules; nothing about it is
  configured here.
- In the standard variant the connection goes directly to Alynki's hosted server; in the
  sealed variant it goes to the local `alynki-local` process, which calls the hosted server,
  decrypts the result, and does the chunking and paging on this machine so the hosted service
  sees only whole ciphertext. The tool names and the rendered payload are the same either way.
- A `SessionStart` hook stating that context is available to load.

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
  (the path from hostname to serving revision is
  `alynki/docs/architecture/dns-and-request-routing.md`). For local development against a local
  server, override the URL to
  `http://127.0.0.1:8080/mcp` as an **uncommitted** working-copy change and add the marketplace
  from the local clone — `main` only ever carries production.
- **Visibility staging:** this repository is **private through V1.2** — colleagues install
  using their own granted git access (⚠️ if the clone fails with "Repository not found", the
  SSH key GitHub picked lacks access — pass an explicit git URL for the right identity).
  It goes **public only after the provisional patent application is filed** (alynki/alynki#28).

## Content policy — read before adding anything

**Assume this repository becomes public.** It exists precisely so the plugin can be
installed without access to `alynki/alynki`, which is private and pre-patent.

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
