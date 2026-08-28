#!/bin/sh
# headersHelper for the alynki MCP server (V2.1, alynki/alynki#550).
#
# Emits the Authorization header only when a pinned token is configured;
# emits {} otherwise, which Claude Code treats identically to a server with
# no headers/headersHelper at all — the 401 that follows triggers native
# OAuth discovery. A STATIC headers.Authorization key would disable that
# fallback unconditionally, even when its interpolated value is empty
# (confirmed empirically, alynki/alynki#398 design record §2.2); this script
# exists so the decision is made from configuration, at connection time,
# never from a static key in .mcp.json.
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
token=$(jq -r '
	.pluginConfigs // {}
	| to_entries[]
	| select(.key | split("@")[0] == "alynki")
	| .value.options.token // empty
' "$settings" 2>/dev/null | head -n1)

if [ -n "${token:-}" ]; then
	jq -n --arg t "$token" '{"Authorization": ("Bearer " + $t)}'
else
	echo '{}'
fi
