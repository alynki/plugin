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

- An MCP connection exposing one tool: `load_context`. The tool takes no arguments — scope
  comes entirely from your token. In the standard variant the connection goes directly to
  Alynki's hosted server; in the sealed variant it goes to the local `alynki-local`
  process, which calls the hosted server and decrypts the result. The tool name and the
  payload are the same either way.
- A `SessionStart` hook stating that context is available to load.

## Status

- `alynki-plugin/.mcp.json` and `alynki-sealed-plugin/.mcp.json` carry the **live hosted
  endpoint** (Cloud Run,
  `australia-southeast2`). For local development against a local server, override the URL to
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
