# Alynki

From your people to your customers, faster and with higher quality. Alynki is the business context layer your people and their AI agents work from. AI doesn't replace your people, it empowers them.

Alynki requires an Alynki account. Request access at alynki.com/contact. Setup and examples: alynki.com/docs.

## Start

In Claude Code, run these two commands (Anthropic's [Install and manage plugins](https://code.claude.com/docs/en/plugins/install)). `/plugin install` opens the plugin's details in the `/plugin` panel, where you choose the scope (user, project or local). The connection is bundled, so there is no address to enter. The other clients are covered below, and [alynki.com/docs](https://alynki.com/docs) gives the same steps.

```
/plugin marketplace add alynki/plugin
/plugin install alynki@alynki-marketplace
```

You need no token. Type `/mcp`, pick Alynki and choose Authenticate: Claude Code opens a browser window, where you sign in with the account your administrator invited and approve the connection.

If your operator issued you a pinned token, put it in the plugin's **Alynki API token** field (`/plugin`). It wins over signing in.

## Codex CLI

OpenAI's [Developer commands](https://developers.openai.com/codex/cli/reference). Codex installs from the repository root, whose `.codex-plugin/plugin.json` names this folder's `mcp.json` (the same address, with a transport `type`), skills and `hooks/codex-hooks.json`: the same script as Claude Code's hooks, printing `additionalContext` only, because Codex drops a hook output that carries a field it does not know. Install it with `codex plugin marketplace add alynki/plugin` and `codex plugin add alynki@alynki-marketplace`, and sign in when Codex first connects. Codex runs a plugin's hooks only after you review and trust them once with `/hooks` in Codex, so the load-first instruction does not run from the public plugin directory. A session then starts with `load_context`; without the hook, ask your agent to call `load_context` first. `$alynki:setup` (`codex/skills/setup`, which runs `codex/setup.sh` only when you invoke it) writes the plugin's tool policy into your Codex `config.toml`: the tools in `tools.txt` run without asking and those in `ask-tools.txt` ask before each call; to undo it, delete the `[plugins."alynki@alynki-marketplace".mcp_servers.alynki...]` tables.

## Antigravity CLI

Google's [Plugins & skills](https://antigravity.google/docs/cli/plugins):

```
agy plugin install https://github.com/alynki/plugin
```

Antigravity reads `.antigravity-plugin/plugin.json`, `mcp_config.json` and `hooks.json` from this folder. If your version needs the plugin at the root of what you install, run `agy plugin install <path>/alynki-plugin` from a clone. Sign in when Antigravity first connects. The `SessionStart` hook injects the same load-first text, so a session starts with `load_context`. `agy plugin validate` warns about `.mcp.json`, `mcp.json` and `hooks/hooks.json`; those files are for the other clients.

## GitHub Copilot

**VS Code** ([Agent plugins in VS Code](https://code.visualstudio.com/docs/agent-customization/agent-plugins)): turn on the `chat.plugins.enabled` setting, then run "Chat: Install Plugin from Source" from the Command Palette and enter the Git repository URL, `https://github.com/alynki/plugin`. Sign in when Copilot first connects.

**Copilot CLI** (GitHub's [Finding and installing plugins](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-finding-installing)):

```
copilot plugin marketplace add alynki/plugin
copilot plugin install alynki@alynki-marketplace
```

Copilot reads the root `plugin.json`, an [Agent Plugins](https://agent-plugins.org/) v1.0.0 manifest, then `mcp.json` (the server's address) and `com.github.copilot/hooks/hooks.json` (the `sessionStart` and `subagentStart` hooks). The Copilot agent in VS Code 1.147 runs the `sessionStart` hook but discards its output, and runs no `subagentStart`, so the same wording is also a rule, `com.github.copilot/rules/alynki-load-first.instructions.md`, which VS Code adds to a chat's instructions. A subagent there does not receive the rule: the rule tells the chat to pass the instruction on, and VS Code does not always let the subagent find the tool. Sign in when the client first connects. Agent hooks in VS Code and Copilot CLI are in preview, and the instruction only runs where your organisation allows plugins and hooks: the VS Code policies `ChatPluginsEnabled`, `ChatAllowManagedHooksOnly` and `ChatStrictMarketplaces` can block either. Without the hook or the rule, ask your agent to call `load_context` first.

## Cursor

Cursor's [Model Context Protocol (MCP)](https://cursor.com/docs/mcp). Alynki is not yet listed in the Cursor Marketplace, so add this to `~/.cursor/mcp.json` (or a project's `.cursor/mcp.json`), then sign in with your Alynki account when Cursor first connects to `https://mcp.alynki.com/mcp`:

```json
{
  "mcpServers": {
    "alynki": {
      "url": "https://mcp.alynki.com/mcp",
      "auth": {
        "CLIENT_ID": "alynki-cursor"
      }
    }
  }
}
```

`alynki-cursor` is Alynki's public client for Cursor: it holds no secret, so there is nothing to copy or keep, and every person still signs in as themselves in the browser (OAuth with PKCE). This folder carries the same block in `cursor-mcp.json`, named by `.cursor-plugin/plugin.json`. A Cursor that installs the plugin needs no hand editing: it reads `auth` from that file (tested on 25 November 2026 from a local plugin folder). The same manifest names `hooks/cursor-hooks.json`, whose `sessionStart` and `subagentStart` hooks tell a chat and its subagents to call `load_context` first; without the plugin, the connector's server instructions say the same. If Cursor also imports Claude Code's plugins (Cursor Settings → Agents) and finds a copy of this one older than 0.31.0, that copy has no client ID, takes the server's place and sign-in fails with "does not support dynamic client registration": update the plugin in Claude Code, or turn the import off. More at https://alynki.com/docs/.

## Grok Build

xAI's [Skills, Plugins & Marketplaces](https://docs.x.ai/build/features/skills-plugins-marketplaces). Install the repository root, then open `/mcps`, select `alynki` and press `i` to sign in, run `/alynki:setup`, and start a new session:

```bash
grok plugin install alynki/plugin --trust
```

The root `.grok-plugin/plugin.json` names this folder's `grok/mcp.json` (the same address, with Alynki's public loopback client), its setup skill and one `PreToolUse` hook. Grok Build has no hook that can inject text into a session; setup writes the load-first wording to `~/.grok/rules/` instead.

## Setup per client

- **Claude Code:** run `/alynki:setup` once.
- **Codex CLI:** run `$alynki:setup` once. It runs `codex/setup.sh`, which writes `approve` for the 37 tools in `tools.txt` and `prompt` for the seven in `ask-tools.txt` into `$CODEX_HOME/config.toml`; a second run changes nothing. If your organisation sets `allow_managed_hooks_only = true` ([Codex hooks](https://developers.openai.com/codex/hooks)), Codex skips every plugin hook, so sessions are not told to call `load_context` first and setup cannot change that: ask your administrator to add Alynki's hook as a managed hook in `requirements.toml`.
- **Antigravity CLI:** run `/setup` once and approve its one command outside the sandbox. It runs `bin/setup-antigravity.sh` (needs `jq`), which writes to `~/.gemini/antigravity-cli/settings.json` a `mcp(alynki_alynki/<tool>)` rule in `permissions.allow` for the 37 tools in `tools.txt` and in `permissions.ask` for the seven access-changing tools in `ask-tools.txt`, removes any allow rule for those seven, keeps your other entries, and changes nothing on a second run. It names, and leaves for you to remove, any allow rule under the old server name `alynki` (or a wildcard) that lets one of the seven run without asking.
- **GitHub Copilot CLI:** run `/alynki:setup` once. It runs `bin/setup-copilot.sh`: hooks then allow the 37 tools of `tools.txt` and make the seven of `ask-tools.txt` ask each time; `--undo` reverses it. Limits: the hooks recognise Alynki by the server name `alynki` only, so any server of that name is treated as Alynki's; hooks run only in a folder you have trusted; if the hook script crashes, Copilot denies the call; autopilot treats ask as deny; not on Windows.
- **Cursor:** run `/alynki-setup` once and approve its one command (needs `jq`). It adds `plugin-alynki-alynki:<tool>` (the CLI's server name) and `alynki:<tool>` (the desktop app's; these also match any other MCP server named `alynki`) for the 37 tools in `tools.txt` to `mcpAllowlist` in `~/.cursor/permissions.json`, removes both names' entries that cover the seven in `ask-tools.txt`, keeps your other entries, and changes nothing on a second run. The seven ask only in [Run Mode](https://cursor.com/docs/agent/security/run-modes) Allowlist: Auto-review's classifier can run them without asking, and Run Everything runs them. That file's list replaces the MCP allowlist in Cursor Settings.
- **Grok Build:** run `/alynki:setup` once. It writes the rules for the same 37 and 7 into `~/.grok/config.toml` and writes `~/.grok/rules/alynki-load-context.md`.
- **VS Code:** no setup script, since VS Code has no setting for a named list of MCP tools. Choose **Always Allow** (or **Chat: Manage Tool Approval**) for the 37 tools in `tools.txt` and **Allow Once** for the seven in `ask-tools.txt`. Its docs do not say whether the first chat message waits for the MCP server; if a first chat has no Alynki tools, send the message again.
- **Other clients:** no local permission file; see https://alynki.com/docs/.

## What you can ask

What your business already knows, how you decide, who may do what and what good looks like, is written once and inherited by every person and every agent at the point of work. With Alynki connected, you can ask for the standards and decisions that apply where you work, define workflows and the checks each step must pass, and start a run and work it step by step. A person decides the checks that need judgement, in the Alynki app. You only ever see and change the parts of your business you have access to.

## What it runs, sends and fetches

Claude Code runs three things from this plugin, and nothing else (Codex and Antigravity run only the hook script, the same way; Cursor also runs `cursor/ask.sh` before each MCP call, which asks for the seven access-changing tools and reads nothing but the call; `bin/setup-antigravity.sh`, Codex's `codex/setup.sh` and `cursor/setup.sh` run only when you invoke them, and each writes only its one settings file; Grok Build runs `grok/ask.sh` before each of the seven access-changing tools, which reads the call and prints ask or deny, and `grok/setup.sh` only when you invoke setup):

- **Two hooks**, `SessionStart` and `SubagentStart`. Each runs `sh "${CLAUDE_PLUGIN_ROOT}"/hooks/session-start.sh claude <session|subagent>`, which prints the fixed text in `hooks/load-first.md` and tells the session, and every subagent it starts, to call `load_context` first. The text applies even when the user's message asks the model not to use tools, and it says the model may tell the user it loaded the context. The hooks make no network call and read nothing else.
- **A header helper**, `bin/headers.sh`, which Claude Code runs when it connects, reconnects or meets a 401 or 403 from Alynki. It needs `jq`, reads only the `alynki` entry under `pluginConfigs` in `$CLAUDE_CONFIG_DIR/settings.json` (`~/.claude/settings.json` when that is unset), and prints a JSON object of headers: `Authorization: Bearer <token>` when a pinned token is set, and `X-Alynki-Model: <model>` when the optional model setting is a plain model id. It writes nothing, makes no network call and never prints the model.
- **A setup skill**, `/alynki:setup`, which runs only when you invoke it. It shows you an edit to your `settings.json` in the Claude folder (`$CLAUDE_CONFIG_DIR` when set, `~/.claude` otherwise) that allows 37 of Alynki's tools (listed in `tools.txt`) without a prompt and makes the seven that change who has access (listed in `ask-tools.txt`) ask you before each call, and applies the edit once you agree.

It sends your requests, over HTTPS, only to `https://mcp.alynki.com/mcp`, and signs you in at `https://auth.alynki.com` through Claude Code's OAuth flow in your browser. It fetches only what that server returns for your account. It sends no analytics and contacts no other host.

One setting is held for a reviewer. A pinned token, if you use one, sits in `settings.json` in plain text rather than in the operating system's credential store, because Claude Code gives a header helper no sensitive plugin option, so the helper must read the file itself. Signing in needs no token, and the token field is optional.

## Privacy, support and licence

- Privacy policy: https://alynki.com/privacy/
- Documentation: https://alynki.com/docs/
- Support: https://alynki.com/support/ or info@alynki.com
- Licence: MIT, see the repository's [LICENSE](https://github.com/alynki/plugin/blob/main/LICENSE).
