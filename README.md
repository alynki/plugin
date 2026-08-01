# Alynki plugin

The Claude Code plugin for Alynki — loads your team's shared product context into every
session, scoped to your token.

## Install

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

## What it installs

- An MCP connection to Alynki's hosted server, exposing one tool: `load_context`. The tool
  takes no arguments — scope comes entirely from your token.
- A `SessionStart` hook stating that context is available to load.

## Status

- `alynki-plugin/.mcp.json` carries the **live hosted endpoint** (Cloud Run,
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
