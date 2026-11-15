# Alynki

From your people to your customers, faster and with higher quality. Alynki is the business context layer your people and their AI agents work from. AI doesn't replace your people, it empowers them.

Alynki requires an Alynki account. Request access at alynki.com/contact. Setup and examples: alynki.com/docs.

## Start

In Claude Code, run these two commands. The connection is bundled, so no other step is needed.

```
/plugin marketplace add alynki/plugin
/plugin install alynki@alynki-marketplace
```

You need no token. The first time you use Alynki, Claude Code opens a browser window: sign in with the account your administrator invited, and approve the connection. If `/mcp` shows Alynki as needing sign-in, choose it there.

If your operator issued you a pinned token, put it in the plugin's **Alynki API token** field (`/plugin`). It wins over signing in.

## What you can ask

What your business already knows, how you decide, who may do what and what good looks like, is written once and inherited by every person and every agent at the point of work. With Alynki connected, you can ask for the standards and decisions that apply where you work, define workflows and the checks each step must pass, and start a run and work it step by step. A person decides the checks that need judgement, in the Alynki app. You only ever see and change the parts of your business you have access to.

## What it runs, sends and fetches

Claude Code runs three things from this plugin, and nothing else:

- **Two hooks**, `SessionStart` and `SubagentStart`. Each runs `cat "${CLAUDE_PLUGIN_ROOT}"/hooks/<file>.json` and prints a fixed text that tells the session, and every subagent it starts, to call `load_context` first. The text applies even when the user's message asks the model not to use tools, and it says the model may tell the user it loaded the context. The hooks make no network call and read nothing else.
- **A header helper**, `bin/headers.sh`, which Claude Code runs when it connects, reconnects or meets a 401 or 403 from Alynki. It needs `jq`, reads only the `alynki` entry under `pluginConfigs` in `$CLAUDE_CONFIG_DIR/settings.json` (`~/.claude/settings.json` when that is unset), and prints a JSON object of headers: `Authorization: Bearer <token>` when a pinned token is set, and `X-Alynki-Model: <model>` when the optional model setting is a plain model id. It writes nothing, makes no network call and never prints the model.
- **A setup skill**, `/alynki:setup`, which runs only when you invoke it. It shows you an edit to `~/.claude/settings.json` that adds a standing permission for Alynki's tools, asks before every tool that changes who has access, and applies the edit once you agree.

It sends your requests, over HTTPS, only to `https://mcp.alynki.com/mcp`, and signs you in at `https://auth.alynki.com` through Claude Code's OAuth flow in your browser. It fetches only what that server returns for your account. It sends no analytics and contacts no other host.

One setting is held for a reviewer. A pinned token, if you use one, sits in `settings.json` in plain text rather than in the operating system's credential store, because Claude Code gives a header helper no sensitive plugin option, so the helper must read the file itself. Signing in needs no token, and the token field is optional.

## Privacy, support and licence

- Privacy policy: https://alynki.com/privacy/
- Documentation: https://alynki.com/docs/
- Support: https://alynki.com/support/ or info@alynki.com
- Licence: MIT, see the repository's [LICENSE](https://github.com/alynki/plugin/blob/main/LICENSE).
