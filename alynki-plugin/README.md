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

OpenAI's [Developer commands](https://developers.openai.com/codex/cli/reference). Codex reads this folder as it is: `.codex-plugin/plugin.json`, `mcp.json` (the same address, with a transport `type`) and `hooks/codex-hooks.json`, which the Codex manifest names: the same script as Claude Code's hooks, printing `additionalContext` only, because Codex drops a hook output that carries a field it does not know. Install it with `codex plugin marketplace add alynki/plugin` and `codex plugin add alynki@alynki-marketplace`, and sign in when Codex first connects. Codex runs a plugin's hooks only after you review and trust them once in Codex, so the load-first instruction does not run from the public plugin directory. A session then starts with `load_context`; without the hook, ask your agent to call `load_context` first.

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

Copilot reads the root `plugin.json` (Copilot format), which names `hooks/copilot-hooks.json` (the `sessionStart` and `subagentStart` hooks) and `copilot-mcp.json` (the same address). Antigravity keeps the fixed root `hooks.json`, so the Copilot hooks sit in their own file. Sign in when the client first connects. Agent hooks in VS Code and Copilot CLI are in preview, and the instruction only runs where your organisation allows plugins and hooks: the VS Code policies `ChatPluginsEnabled`, `ChatAllowManagedHooksOnly` and `ChatStrictMarketplaces` can block either. Without the hook, ask your agent to call `load_context` first.

## Cursor

Cursor's [Model Context Protocol (MCP)](https://cursor.com/docs/mcp): go to Customize and open the Cursor Marketplace, find Alynki and choose Add to Cursor, then sign in. For a Cursor where Alynki is not listed, add this to `~/.cursor/mcp.json` (or a project's `.cursor/mcp.json`), then sign in when Cursor first connects to `https://mcp.alynki.com/mcp`:

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

`alynki-cursor` is Alynki's public client for Cursor: it holds no secret, so there is nothing to copy or keep, and every person still signs in as themselves in the browser (OAuth with PKCE). This folder carries the same block in `cursor-mcp.json`, named by `.cursor-plugin/plugin.json`, for a Cursor that installs from a plugin source. Cursor's documentation does not say whether it reads `auth` from a plugin's MCP file, so the block above is the setup to rely on. The connector's server instructions tell a new chat to call `load_context` first. More at https://alynki.com/docs/.

## Grok Build

xAI's [Skills, Plugins & Marketplaces](https://docs.x.ai/build/features/skills-plugins-marketplaces). Grok Build has no hook that can inject text into a session, so this plugin ships none. Add one line to `~/.grok/AGENTS.md`: call Alynki's `load_context` first.

## Setup per client

- **Claude Code:** run `/alynki:setup` once.
- **Antigravity CLI:** run `sh bin/setup-antigravity.sh` (needs `jq`). It adds `mcp(alynki/<tool>)` rules for the 37 tools in `tools.txt` to `permissions.allow` in `~/.gemini/antigravity-cli/settings.json`, removes any allow rule for the seven access-changing tools in `ask-tools.txt` so Antigravity asks before each, keeps your other entries, and changes nothing on a second run.
- **Other clients:** no local permission file; see https://alynki.com/docs/.

## What you can ask

What your business already knows, how you decide, who may do what and what good looks like, is written once and inherited by every person and every agent at the point of work. With Alynki connected, you can ask for the standards and decisions that apply where you work, define workflows and the checks each step must pass, and start a run and work it step by step. A person decides the checks that need judgement, in the Alynki app. You only ever see and change the parts of your business you have access to.

## What it runs, sends and fetches

Claude Code runs three things from this plugin, and nothing else (Codex and Antigravity run only the hook script, the same way; `bin/setup-antigravity.sh` runs only when you run it and writes only that one settings file):

- **Two hooks**, `SessionStart` and `SubagentStart`. Each runs `sh "${CLAUDE_PLUGIN_ROOT}"/hooks/session-start.sh claude <session|subagent>`, which prints the fixed text in `hooks/load-first.md` and tells the session, and every subagent it starts, to call `load_context` first. The text applies even when the user's message asks the model not to use tools, and it says the model may tell the user it loaded the context. The hooks make no network call and read nothing else.
- **A header helper**, `bin/headers.sh`, which Claude Code runs when it connects, reconnects or meets a 401 or 403 from Alynki. It needs `jq`, reads only the `alynki` entry under `pluginConfigs` in `$CLAUDE_CONFIG_DIR/settings.json` (`~/.claude/settings.json` when that is unset), and prints a JSON object of headers: `Authorization: Bearer <token>` when a pinned token is set, and `X-Alynki-Model: <model>` when the optional model setting is a plain model id. It writes nothing, makes no network call and never prints the model.
- **A setup skill**, `/alynki:setup`, which runs only when you invoke it. It shows you an edit to `~/.claude/settings.json` that allows 37 of Alynki's tools (listed in `tools.txt`) without a prompt and makes the seven that change who has access (listed in `ask-tools.txt`) ask you before each call, and applies the edit once you agree.

It sends your requests, over HTTPS, only to `https://mcp.alynki.com/mcp`, and signs you in at `https://auth.alynki.com` through Claude Code's OAuth flow in your browser. It fetches only what that server returns for your account. It sends no analytics and contacts no other host.

One setting is held for a reviewer. A pinned token, if you use one, sits in `settings.json` in plain text rather than in the operating system's credential store, because Claude Code gives a header helper no sensitive plugin option, so the helper must read the file itself. Signing in needs no token, and the token field is optional.

## Privacy, support and licence

- Privacy policy: https://alynki.com/privacy/
- Documentation: https://alynki.com/docs/
- Support: https://alynki.com/support/ or info@alynki.com
- Licence: MIT, see the repository's [LICENSE](https://github.com/alynki/plugin/blob/main/LICENSE).
