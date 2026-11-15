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
ok "the standard plugin's hooks do not offer a revealed agent token" absent 'you revealed' alynki-plugin/hooks/session-start.json alynki-plugin/hooks/subagent-start.json

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

# The listing (alynki/alynki#3263): words from the approved listing kit, the icon, the URLs and the plugin's own README.
PLUGIN_README=alynki-plugin/README.md
MKT=.claude-plugin/marketplace.json
OPENING="From your people to your customers, faster"
ICON_SHA256=651c242cf20d647a3e2ea0c6e95d852800171637882578882ffe9ffdc624980a
no_em_dash() { ! grep -q '—' "$@"; }
descriptions_in_the_sites_register() {
  [ "$(jq -r '.description | startswith($o)' --arg o "$OPENING" "$STD")" = "true" ] &&
    [ "$(jq -r '.plugins[0].description | startswith($o)' --arg o "$OPENING" "$MKT")" = "true" ] &&
    [ "$(jq -r '.description | length' "$STD")" -le 200 ] &&
    [ "$(jq -r '.description | length' "$MKT")" -le 200 ]
}
icon_is_the_approved_png() {
  [ "$(jq -r .icon "$STD")" = "./.claude-plugin/icon.png" ] &&
    [ "$({ sha256sum alynki-plugin/.claude-plugin/icon.png 2>/dev/null || shasum -a 256 alynki-plugin/.claude-plugin/icon.png; } | cut -d' ' -f1)" = "$ICON_SHA256" ]
}
listing_urls_are_https() { [ "$(jq -r '[.privacyPolicyUrl, .homepage, .repository] | map(startswith("https://")) | all' "$STD")" = "true" ]; }
words_outside_code() { awk '/^```/ { f = !f; next } !f' "$1" | wc -w | tr -d ' '; }
plugin_readme_has_40_words() { [ "$(words_outside_code "$PLUGIN_README")" -ge 40 ]; }
opens_with_what_alynki_is() { grep -v -e '^#' -e '^[[:space:]]*$' "$1" | head -n1 | grep -qF -- "$OPENING"; }
# shellcheck disable=SC2016 # the backticks are literal Markdown
readme_install_matches_docs() {
  grep -qxF '/plugin marketplace add alynki/plugin' "$PLUGIN_README" && grep -qxF '/plugin install alynki@alynki-marketplace' "$PLUGIN_README" &&
    grep -qF '`/plugin marketplace add alynki/plugin`' README.md && grep -qF '`/plugin install alynki@alynki-marketplace`' README.md && ! grep -q 'reload-plugins' README.md "$PLUGIN_README"
}
ok "no em dash in plugin.json, marketplace.json or either README" no_em_dash "$STD" "$MKT" README.md "$PLUGIN_README"
ok "the plugin and marketplace descriptions open in the site's register and fit 200 characters" descriptions_in_the_sites_register
ok "plugin.json's icon is the committed approved PNG (sha256 of https://alynki.com/favicon-512.png)" icon_is_the_approved_png
ok "plugin.json carries privacyPolicyUrl, homepage and repository as https URLs" listing_urls_are_https
ok "the plugin's own README has 40 words or more outside code blocks" plugin_readme_has_40_words
ok "the plugin's own README opens with what Alynki is" opens_with_what_alynki_is "$PLUGIN_README"
ok "the repository README opens in the same register" opens_with_what_alynki_is README.md
ok "the install commands match https://alynki.com/docs/ (two commands, no reload step)" readme_install_matches_docs
ok "the README says each step output and check evaluation is saved with a reasoning" grep -qF 'Each step output and check evaluation is saved with a reasoning' README.md

# Directory validation (alynki/alynki#3148): hook commands are ${CLAUDE_PLUGIN_ROOT} paths, the hook text is kept as it was
# (founder option B, 2026-11-15: any change to it is the founder's decision, so its hashes are pinned), the folder has its own LICENSE.
HOOKS=alynki-plugin/hooks/hooks.json
SESSION_START_SHA256=65b193c0dc2e0ac96813b0c461d9c3a3a22e0fa6f7b932eb7f87ce6fee24e8b1
SUBAGENT_START_SHA256=26cb4548b3e510fc6c4aec47bb86254fd6430fcef9071a16a41123b4ebdd13a7
sha_of() { { sha256sum "$1" 2>/dev/null || shasum -a 256 "$1"; } | cut -d' ' -f1; }
# shellcheck disable=SC2016 # ${CLAUDE_PLUGIN_ROOT} is literal text in the hook command
hook_commands_use_plugin_root() {
  [ "$(jq -r '[.hooks[][].hooks[].command] | length' "$HOOKS")" -eq 2 ] &&
    [ "$(jq -r '[.hooks[][].hooks[].command | startswith("cat \"${CLAUDE_PLUGIN_ROOT}\"/hooks/")] | all' "$HOOKS")" = "true" ] &&
    [ "$(jq -r '[.hooks[][].hooks[].command | contains("<<")] | any' "$HOOKS")" = "false" ]
}
hook_files_exist_and_are_json() {
  local f
  for f in alynki-plugin/hooks/session-start.json alynki-plugin/hooks/subagent-start.json; do
    jq -e '.hookSpecificOutput.hookEventName' "$f" >/dev/null || return 1
  done
}
hook_text_is_kept() { [ "$(sha_of alynki-plugin/hooks/session-start.json)" = "$SESSION_START_SHA256" ] && [ "$(sha_of alynki-plugin/hooks/subagent-start.json)" = "$SUBAGENT_START_SHA256" ]; }
hook_commands_print_the_files() {
  local d out
  d=$PWD/alynki-plugin
  out=$(CLAUDE_PLUGIN_ROOT=$d sh -c "$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$HOOKS")") && [ "$out" = "$(cat "$d/hooks/session-start.json")" ] &&
    out=$(CLAUDE_PLUGIN_ROOT=$d sh -c "$(jq -r '.hooks.SubagentStart[0].hooks[0].command' "$HOOKS")") && [ "$out" = "$(cat "$d/hooks/subagent-start.json")" ]
}
plugin_license_matches_root() { cmp -s LICENSE alynki-plugin/LICENSE; }
no_private_repository_link() { ! grep -rhoE --exclude-dir=.git 'github\.com/alynki/[A-Za-z0-9._-]+' README.md alynki-plugin | grep -vx 'github.com/alynki/plugin'; }
ok "the hook commands are CLAUDE_PLUGIN_ROOT paths, not inline heredocs" hook_commands_use_plugin_root
ok "each hook's file exists and is hook JSON" hook_files_exist_and_are_json
ok "the hook commands print their files (a real run with CLAUDE_PLUGIN_ROOT set)" hook_commands_print_the_files
ok "the hook text is kept as it was (sha256 pinned; a change is the founder's decision)" hook_text_is_kept
ok "the plugin folder has its own LICENSE, identical to the repository's" plugin_license_matches_root
ok "no link points into a private repository" no_private_repository_link
ok "the plugin README says what the plugin runs, sends and fetches" grep -qF '## What it runs, sends and fetches' alynki-plugin/README.md
ok "the plugin README holds the token finding for the reviewer" grep -qF 'One setting is held for a reviewer' alynki-plugin/README.md

# The release (alynki/alynki#3264): 0.28.0 is the version that removed the variant and carries the listing; its note says what changed.
ok "the standard plugin's version is at least 0.28.0, the release of the listing and the directory validation" version_at_least "$STD" 0.28.0
ok "the 0.28.0 release note says the listing, the hook command form and the counts unchanged" grep -qF 'No tool and no prompt added (the counts are those of the diagram above: 44 tools and 44 prompts' README.md
ok "the plugin's version is named in the README's release notes" grep -qF "\`alynki\` $(jq -r .version "$STD"):" README.md

echo "$n assertions, $failed failed"
[ "$failed" -eq 0 ] || exit 1
floor=${SETUP_CHECK_FLOOR:-0}
if [ "$n" -lt "$floor" ]; then
  echo "FAIL: $n assertions ran, the floor is $floor"
  exit 1
fi
