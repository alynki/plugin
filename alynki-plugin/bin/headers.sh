#!/bin/sh
# headersHelper for the alynki MCP server.
#
# Emits the Authorization header only when a pinned token is configured, and
# the X-Alynki-Model header only when the plugin's optional `model` setting is
# present and well formed (the model the session runs on: the controller writes
# it into the session's private settings; a person's own session leaves it
# unset and sends none). Emits {} when neither is configured, which Claude
# Code treats identically to a server with no headers/headersHelper at all:
# the 401 that follows triggers native OAuth discovery. A STATIC headers.Authorization key would disable that
# fallback unconditionally, even when its interpolated value is empty
# (confirmed empirically, alynki/alynki#398 design record §2.2); this script
# exists so the decision is made from configuration, at connection time,
# never from a static key in .mcp.json.
#
# The model is read from the same settings entry as the token, is never
# printed (the only output is the JSON a header carries), and a value that is
# not a plain model id (^[A-Za-z0-9._:-]{1,100}$, no leading "-") is dropped,
# so nothing odd can reach a header line.
#
# Claude Code does not export CLAUDE_PLUGIN_OPTION_* to headersHelper
# processes (confirmed empirically, same design record) and refuses
# ${user_config.*} in this field outright, so the configured token is read
# directly from settings.json here, per the documented remedy ("read the
# value from a config file in the script").
set -eu

settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"

if ! command -v jq >/dev/null 2>&1 || [ ! -f "$settings" ]; then
	echo '{}'
	exit 0
fi

# Match any pluginConfigs key whose plugin name (before "@") is "alynki" —
# not a hardcoded marketplace source, since a dev/test install's source
# segment differs from a real marketplace install's.
entry='
	.pluginConfigs // {}
	| to_entries[]
	| select(.key | split("@")[0] == "alynki")
	| .value.options
'
token=$(jq -r "$entry | .token // empty" "$settings" 2>/dev/null | head -n1)
model=$(jq -r "$entry"' | .model // empty
	| select(type == "string" and test("\\A[A-Za-z0-9._:-]{1,100}\\z") and (startswith("-") | not))' "$settings" 2>/dev/null | head -n1)

jq -n --arg t "${token:-}" --arg m "${model:-}" '
	(if $t != "" then {"Authorization": ("Bearer " + $t)} else {} end)
	+ (if $m != "" then {"X-Alynki-Model": $m} else {} end)
'
