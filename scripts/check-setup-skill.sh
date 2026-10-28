#!/usr/bin/env bash
# Asserts what /alynki:setup promises: the exact set of tools that always ask
# for approval, in both variants' skills and in the README that documents them,
# and that the words around them are not stale. Run from anywhere:
#
#   scripts/check-setup-skill.sh
#
# SETUP_CHECK_FLOOR is the number of assertions that must run (CI sets it to the
# real total). A check deleted or skipped lowers the count and fails the run.
set -u
cd "$(dirname "$0")/.." || exit 1

SKILL=alynki-plugin/skills/setup/SKILL.md
SEALED=alynki-sealed-plugin/skills/setup/SKILL.md
STD=alynki-plugin/.claude-plugin/plugin.json
SLD=alynki-sealed-plugin/.claude-plugin/plugin.json
GATED="grant_principal revoke_principal invite_principal revoke_principal_invite create_principal_agent update_principal_agent revoke_principal_agent"

n=0
failed=0
ok() {
  local desc=$1
  shift
  n=$((n + 1))
  if "$@" >/dev/null 2>&1; then
    echo "ok   $n $desc"
  else
    echo "FAIL $n $desc"
    failed=$((failed + 1))
  fi
}

# Each helper takes the pattern or tool first, then the file.
listed() { grep -qx -- "- \`$1\`" "$2"; }
absent() { ! grep -qiE -- "$1" "$2"; }
absent_word() { ! grep -qiw -- "$1" "$2"; }
# shellcheck disable=SC2016 # the backticks are literal Markdown
gate_size() { [ "$(grep -cE '^- `[a-z_]+`$' "$1")" -eq "$2" ]; }
in_readme_json() { grep -qF "\"mcp__plugin_alynki_alynki__$1\"" README.md; }
not_in_readme_json() { ! grep -qF "mcp__plugin_alynki_alynki__$1" README.md; }
# A count in a list item or paragraph is read in the context of the nearest preceding class word: "sealed" before "39 tools" is wrong.
absent_sealed_39() { ! tr -d '*`' <"$1" | awk '/^[ \t]*$/ || /^[ \t]*#/ || /^[ \t]*[-*][ \t]/ || /\["/ { c = "" } { l = tolower($0); gsub(/[^a-z0-9-]/, " ", l); n = split(l, w, " "); for (i = 1; i <= n; i++) { if (index(w[i], "sealed") > 0) c = "sealed"; else if (w[i] == "server" || w[i] == "pinned" || w[i] == "interactive") c = ""; if (c == "sealed" && (w[i] == "39" || w[i] == "thirty-nine") && (w[i+1] == "tools" || w[i+1] == "prompts")) bad = 1 } } END { exit !bad }'; }
in_readme_all() { for t in "$@"; do grep -qF "\`$t\`" README.md || return 1; done; }
named_in_readme() { grep -qF "\`$1\` $2" README.md; }

# Sealed tenants are discontinued (alynki/alynki#1093, 2026-10-20); restore if they return.
# ok "the two setup skills are byte-identical" cmp -s "$SKILL" "$SEALED"

for t in $GATED; do
  ok "the skill lists $t in the human gate" listed "$t" "$SKILL"
done
ok "the human gate holds exactly seven tools" gate_size "$SKILL" 7
ok "the skill adds only the missing ask rules to a machine set up earlier" grep -qF 'fewer ask rules' "$SKILL"
ok "release_run is not in the skill" absent 'release_run' "$SKILL"
ok "the skill states no mechanism for the rule (nothing about expiry)" absent 'expir' "$SKILL"
ok "the skill carries no stale count (six)" absent_word six "$SKILL"

for t in $GATED; do
  ok "the README's settings example asks before $t" in_readme_json "$t"
done
ok "release_run is not in the README's settings example" not_in_readme_json release_run
ok "the README says seven exact-name ask rules" grep -qF 'seven exact-name rules' README.md
ok "the README carries no stale count (six)" absent_word six README.md

ok "the README does not tell a person to paste a revealed agent token" absent 'you revealed' README.md
ok "the standard plugin's token field does not offer a revealed agent token" absent 'revealed' "$STD"
ok "the standard plugin's hooks do not offer a revealed agent token" absent 'you revealed' alynki-plugin/hooks/hooks.json

ok "the README names the standard plugin's version" named_in_readme alynki "$(jq -r .version "$STD")"
# Sealed tenants are discontinued (alynki/alynki#1093, 2026-10-20); restore if they return.
# ok "the README names the sealed plugin's version" named_in_readme alynki-sealed "$(jq -r .version "$SLD")"

# Sealed tenants are discontinued (alynki/alynki#1093, 2026-10-20); restore if they return.
# ok "the README does not say the sealed proxy mirrors none of the run surface" absent 'mirrors none of it' README.md
# Sealed tenants are discontinued (alynki/alynki#1093, 2026-10-20); restore if they return.
# ok "the README names the run tools the sealed proxy mirrors" in_readme_all load_run load_step load_check save_run save_check create_run release_run
ok "the README names ALYNKI_AUTH_URL" grep -qF 'ALYNKI_AUTH_URL' README.md
ok "the README names CLAUDE_CONFIG_DIR, which headers.sh reads" grep -qF 'CLAUDE_CONFIG_DIR' README.md
# Sealed tenants are discontinued (alynki/alynki#1093, 2026-10-20); restore if they return.
# ok "the README quotes no sealed count of 39 (the sealed proxy has no start_run: 38 tools, 38 prompts)" absent_sealed_39 README.md
ok "the README's run-stop note names the states load_run declares (held, paused, terminated, complete)" grep -qF 'held for a person, a limit, paused, terminated, or complete' README.md

# The model header (alynki/alynki#1918): the standard plugin's header script sends the optional `model`
# setting as the second header X-Alynki-Model, and nothing when it is absent or is not a plain model id.
HEADERS=alynki-plugin/bin/headers.sh
# headers_for <settings.json body>: runs the script against that settings file; stdout is the header JSON, stderr is kept apart.
headers_for() {
  local d out err
  d=$(mktemp -d) || return 1
  printf '%s' "$1" >"$d/settings.json"
  out=$(CLAUDE_CONFIG_DIR="$d" sh "$HEADERS" 2>"$d/stderr")
  err=$(cat "$d/stderr")
  rm -rf "$d"
  HEADERS_OUT=$out
  HEADERS_ERR=$err
}
settings_with() { printf '{"pluginConfigs":{"alynki@alynki-marketplace":{"options":%s}}}' "$1"; }
hdr_eq() { headers_for "$(settings_with "$1")" && [ "$(printf '%s' "$HEADERS_OUT" | jq -cS .)" = "$2" ]; }
model_header_sent_with_token() { hdr_eq '{"token":"tok-1","model":"claude-sonnet-5-5"}' '{"Authorization":"Bearer tok-1","X-Alynki-Model":"claude-sonnet-5-5"}'; }
model_header_sent_alone() { hdr_eq '{"model":"claude-sonnet-5-5"}' '{"X-Alynki-Model":"claude-sonnet-5-5"}'; }
model_header_absent_sends_none() { hdr_eq '{"token":"tok-1"}' '{"Authorization":"Bearer tok-1"}' && hdr_eq '{}' '{}'; }
model_header_blank_sends_none() { hdr_eq '{"token":"tok-1","model":""}' '{"Authorization":"Bearer tok-1"}'; }
model_header_refused_when_malformed() {
  hdr_eq '{"token":"tok-1","model":"-x"}' '{"Authorization":"Bearer tok-1"}' &&
    hdr_eq '{"token":"tok-1","model":"a b"}' '{"Authorization":"Bearer tok-1"}' &&
    hdr_eq '{"token":"tok-1","model":"a\nb: c"}' '{"Authorization":"Bearer tok-1"}' &&
    hdr_eq "{\"token\":\"tok-1\",\"model\":\"$(printf 'm%.0s' $(seq 1 101))\"}" '{"Authorization":"Bearer tok-1"}'
}
model_never_printed() {
  headers_for "$(settings_with '{"token":"tok-1","model":"claude-sonnet-5-5"}')" && [ -z "$HEADERS_ERR" ] &&
    ! grep -qiE 'echo[^|]*model|printf[^|]*model|>&2' "$HEADERS"
}
no_settings_file_sends_none() {
  local d out
  d=$(mktemp -d) || return 1
  out=$(CLAUDE_CONFIG_DIR="$d" sh "$HEADERS" 2>&1)
  rm -rf "$d"
  [ "$out" = '{}' ]
}
sealed_has_no_model() { ! grep -qF 'ALYNKI_MODEL' alynki-sealed-plugin/.mcp.json && [ "$(jq -r '.userConfig | has("model")' "$SLD")" = "false" ]; }
declares_model_setting() { [ "$(jq -r '.userConfig.model.type + "/" + (.userConfig.model.required | tostring)' "$1")" = "string/false" ]; }
# The version carries the release that added the model header or a later one (the floor rises with each release, never falls).
version_at_least() { [ "$(printf '%s\n%s\n' "$2" "$(jq -r .version "$1")" | sort -t. -k1,1n -k2,2n -k3,3n | head -n1)" = "$2" ]; }

ok "the model header is sent beside the token as X-Alynki-Model" model_header_sent_with_token
ok "the model header is sent on its own when only the model is set" model_header_sent_alone
ok "no model header is sent when the model setting is absent" model_header_absent_sends_none
ok "no model header is sent when the model setting is blank" model_header_blank_sends_none
ok "a model that is not a plain model id is refused: no header is sent for it" model_header_refused_when_malformed
ok "the model is never printed: nothing on stderr and no echo of it in the script" model_never_printed
ok "no settings file sends no header at all" no_settings_file_sends_none
ok "the standard plugin declares the optional model setting" declares_model_setting "$STD"
# Sealed tenants are discontinued (alynki/alynki#1093, 2026-10-20); restore if they return.
# ok "the sealed plugin declares the optional model setting" declares_model_setting "$SLD"
# Sealed tenants are discontinued (alynki/alynki#1093, 2026-10-20); restore if they return.
# ok "the sealed plugin passes the model to alynki-local as ALYNKI_MODEL" grep -qF '"ALYNKI_MODEL": "${user_config.model}"' alynki-sealed-plugin/.mcp.json
ok "the standard plugin's version is at least 0.25.0, the release of the model header" version_at_least "$STD" 0.25.0
# Sealed tenants are discontinued (alynki/alynki#1093, 2026-10-20); restore if they return.
# ok "the sealed plugin's version is at least 0.21.0, the release of the model setting" version_at_least "$SLD" 0.21.0
ok "the README names the X-Alynki-Model header" grep -qF 'X-Alynki-Model' README.md
ok "the README says the model is never printed" grep -qF 'The model is never printed' README.md
ok "the README does not name ALYNKI_MODEL, which alynki-local does not read" absent 'ALYNKI_MODEL' README.md
ok "the sealed plugin passes no ALYNKI_MODEL and declares no model setting" sealed_has_no_model
ok "the README states the trail is delivered once per lease" grep -qF 'The trail is delivered once per lease' README.md
ok "the README says the trail comes again with start_run or load_run" grep -qF '`start_run` again, or' README.md

# One name for a place (alynki/alynki#2269): the tools, the prompts and the next actions say `node`, never `address`.
ok "the README names no address argument (the tools say node)" absent "no address argument|optional address|check.s address|workflow.s address" README.md
ok "the standard plugin's version is at least 0.26.0, the release of the node rename" version_at_least "$STD" 0.26.0

echo "$n assertions, $failed failed"
[ "$failed" -eq 0 ] || exit 1
floor=${SETUP_CHECK_FLOOR:-0}
if [ "$n" -lt "$floor" ]; then
  echo "FAIL: $n assertions ran, the floor is $floor"
  exit 1
fi
