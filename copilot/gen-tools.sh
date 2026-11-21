#!/usr/bin/env bash
# Regenerates copilot/mcp-tools.json from the live server's tools/list (alynki/alynki#3453).
#
#   copilot/gen-tools.sh <token-file> [url]
#
# Copilot pins the tools because it cannot discover them: mcp.alynki.com answers initialize and
# tools/list with 401 to a caller with no token, so dynamic discovery finds nothing and no call
# ever prompts the sign-in. <token-file> holds an interactive credential (a person's tools are the
# ones Copilot gets); it is read with cat, sent only as the Authorization header, never printed.
# Writes each tool's name, description, inputSchema and annotations, sorted by name, then refuses
# unless the names equal the plugin's tool list (alynki-plugin/tools.txt and ask-tools.txt when present).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tf=${1:?usage: copilot/gen-tools.sh <token-file> [url]}
url=${2:-https://mcp.alynki.com/mcp}
[ -s "$tf" ] || { echo "gen-tools.sh: cannot read the token file $tf" >&2; exit 1; }
hdr=(-H "Content-Type: application/json" -H "Accept: application/json, text/event-stream" -H "MCP-Protocol-Version: 2025-06-18")
auth() { printf 'header = "Authorization: Bearer %s"\n' "$(cat "$tf")"; }
heads=$(mktemp); trap 'rm -f "$heads"' EXIT
auth | curl -sf -K - "${hdr[@]}" -D "$heads" -X POST "$url" -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"copilot-gen-tools","version":"1"}}}' >/dev/null
sid=$(grep -i '^mcp-session-id:' "$heads" | tr -d '\r' | awk '{print $2}')
auth | curl -sf -K - "${hdr[@]}" ${sid:+-H "Mcp-Session-Id: $sid"} -X POST "$url" -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' >/dev/null
r=$(auth | curl -sf -K - "${hdr[@]}" ${sid:+-H "Mcp-Session-Id: $sid"} -X POST "$url" -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}')
d=$(printf '%s' "$r" | sed -n 's/^data: //p' | tail -1); [ -n "$d" ] || d=$r
printf '%s' "$d" | jq -e '.result.nextCursor == null' >/dev/null || { echo "gen-tools.sh: tools/list is paged; this script reads one page" >&2; exit 1; }
printf '%s' "$d" | jq '{tools: [.result.tools[] | {name, description, inputSchema} + (if .annotations then {annotations} else {} end)] | sort_by(.name)}' >"$here/mcp-tools.json.new"
want=$(cat "$here/../alynki-plugin/tools.txt" "$here/../alynki-plugin/ask-tools.txt" 2>/dev/null | sort)
got=$(jq -r '.tools[].name' "$here/mcp-tools.json.new" | sort)
[ "$got" = "$want" ] || { rm -f "$here/mcp-tools.json.new"; echo "gen-tools.sh: the server's tools differ from the plugin's tool list; update the list first" >&2; exit 1; }
mv "$here/mcp-tools.json.new" "$here/mcp-tools.json"
echo "wrote $here/mcp-tools.json ($(jq '.tools | length' "$here/mcp-tools.json") tools); now set functions and run_for_functions in alynki-plugin.json to these names"
