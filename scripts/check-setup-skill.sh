#!/usr/bin/env bash
# Asserts what /alynki:setup promises: the exact set of tools that always ask
# for approval, in the setup skill and in the README that documents them,
# and that the words around them are not stale. Run from anywhere:
#
#   scripts/check-setup-skill.sh
#
# SETUP_CHECK_FLOOR is the number of assertions that must run (CI sets it to the
# real total). A check deleted or skipped lowers the count and fails the run.
set -u
cd "$(dirname "$0")/.." || exit 1

SKILL=alynki-plugin/skills/setup/SKILL.md
STD=alynki-plugin/.claude-plugin/plugin.json
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
in_readme_all() { for t in "$@"; do grep -qF "\`$t\`" README.md || return 1; done; }
named_in_readme() { grep -qF "\`$1\` $2" README.md; }


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

ok "the README names CLAUDE_CONFIG_DIR, which headers.sh reads" grep -qF 'CLAUDE_CONFIG_DIR' README.md
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
ok "the standard plugin's version is at least 0.25.0, the release of the model header" version_at_least "$STD" 0.25.0
ok "the README names the X-Alynki-Model header" grep -qF 'X-Alynki-Model' README.md
ok "the README says the model is never printed" grep -qF 'The model is never printed' README.md
ok "the README does not name ALYNKI_MODEL, which the plugin does not read" absent 'ALYNKI_MODEL' README.md
ok "the README states the trail is delivered once per lease" grep -qF 'The trail is delivered once per lease' README.md
ok "the README says the trail comes again with start_run or load_run" grep -qF '`start_run` again, or' README.md

# One name for a place (alynki/alynki#2269): the tools, the prompts and the next actions say `node`, never `address`.
ok "the README names no address argument (the tools say node)" absent "no address argument|optional address|check.s address|workflow.s address" README.md
ok "the standard plugin's version is at least 0.26.0, the release of the node rename" version_at_least "$STD" 0.26.0

# The five inherited-check tools (alynki/alynki#2829): named in the README, counted as 44 tools and 44 prompts.
ok "the standard plugin's version is at least 0.27.0, the release of the five inherited-check tools" version_at_least "$STD" 0.27.0
ok "the README names the five inherited-check tools" in_readme_all create_inherited_check list_inherited_checks load_inherited_check move_inherited_check delete_inherited_check
ok "the README carries no stale interactive count (thirty-nine)" absent_word thirty-nine README.md
ok "the README counts forty-four interactive tools and prompts" grep -qF 'all **forty-four** tools' README.md
ok "the README's settings example does not ask before the five new tools" not_in_readme_json create_inherited_check

# The sealed variant is removed (alynki/alynki#3262). The words are assembled from parts so this script never names what it asserts is gone.
S=seal
GONE="${S}ed|alynki-local"
# The one README line allowed to name it is the release note that names the commit which last carried it.
NOTE="the commit that last carried the ${S}ed variant"
marketplace_lists_alynki_only() { [ "$(jq -r '[.plugins[].name] | join(",")' .claude-plugin/marketplace.json)" = "alynki" ]; }
variant_directory_gone() { [ ! -e "alynki-${S}ed-plugin" ]; }
readme_names_it_only_in_the_note() { ! grep -v -F -- "$NOTE" README.md | grep -qiE -- "$GONE"; }
note_names_the_commit() { grep -F -- "$NOTE" README.md | grep -qE '[0-9a-f]{40}'; }
plugin_folder_names_it_nowhere() { ! grep -rqiE --exclude-dir=.git -- "$GONE" alynki-plugin .claude-plugin; }
ok "the marketplace lists alynki alone" marketplace_lists_alynki_only
ok "the sealed variant's directory is gone from main" variant_directory_gone
ok "the README names the sealed variant, its server segment and its local binary nowhere but the release note" readme_names_it_only_in_the_note
ok "the release note names the commit that last carried the sealed variant (a full 40-character SHA)" note_names_the_commit
ok "the setup skill, the plugin folder and the marketplace name no sealed variant, server segment or local binary" plugin_folder_names_it_nowhere
ok "the setup skill recognises one server segment, plugin_alynki_alynki, by literal equality" grep -qF 'exactly one server segment' "$SKILL"

echo "$n assertions, $failed failed"
[ "$failed" -eq 0 ] || exit 1
floor=${SETUP_CHECK_FLOOR:-0}
if [ "$n" -lt "$floor" ]; then
  echo "FAIL: $n assertions ran, the floor is $floor"
  exit 1
fi
