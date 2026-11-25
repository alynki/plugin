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
LIST=alynki-plugin/tools.txt
ASKLIST=alynki-plugin/ask-tools.txt
AGYSET=alynki-plugin/bin/setup-antigravity.sh

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

absent() { ! grep -qiE -- "$1" "$2"; }
absent_word() { ! grep -qiw -- "$1" "$2"; }
in_readme_all() { for t in "$@"; do grep -qF "\`$t\`" README.md || return 1; done; }
named_in_readme() { grep -qF "\`$1\` $2" README.md; }


ok "the skill states no mechanism for the rule (nothing about expiry)" absent 'expir' "$SKILL"
ok "the skill carries no stale count (six)" absent_word six "$SKILL"

ok "the README carries no stale count (six)" absent_word six README.md

ok "the README does not tell a person to paste a revealed agent token" absent 'you revealed' README.md
ok "the standard plugin's token field does not offer a revealed agent token" absent 'revealed' "$STD"
ok "the standard plugin's hooks do not offer a revealed agent token" absent 'you revealed' alynki-plugin/hooks/load-first.md

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
# The hook text now lives in hooks/load-first.md; the pins are the hashes of what `session-start.sh claude` prints. They changed once since #3148,
# for the permission hint (alynki/alynki#3582), which the founder asked for.
SESSION_START_SHA256=9146b1446215ecffbf5253af038fa9fbc7fec7e2a12e896c0c5f75956a2fc945
SUBAGENT_START_SHA256=c791e9dd014a4a49a172438bc51499997954c0c2bb06c1ae1b26b86d547eae1e
sha_of() { { sha256sum "$1" 2>/dev/null || shasum -a 256 "$1"; } | cut -d' ' -f1; }
# shellcheck disable=SC2016 # ${CLAUDE_PLUGIN_ROOT} is literal text in the hook command
hook_commands_use_plugin_root() {
  [ "$(jq -r '[.hooks[][].hooks[].command] | length' "$HOOKS")" -eq 2 ] &&
    [ "$(jq -r '[.hooks[][].hooks[].command | startswith("sh \"${CLAUDE_PLUGIN_ROOT}\"/hooks/session-start.sh claude ")] | all' "$HOOKS")" = "true" ] &&
    [ "$(jq -r '[.hooks[][].hooks[].command | contains("<<")] | any' "$HOOKS")" = "false" ]
}
hook_script_and_wording_exist() { [ -x alynki-plugin/hooks/session-start.sh ] && [ -s alynki-plugin/hooks/load-first.md ]; }
claude_output() { sh alynki-plugin/hooks/session-start.sh claude "$1" </dev/null; }
claude_output_is_hook_json() {
  claude_output session | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null &&
    claude_output subagent | jq -e '.hookSpecificOutput.hookEventName == "SubagentStart"' >/dev/null
}
hook_text_is_kept() { [ "$(claude_output session | shasum -a 256 | cut -d' ' -f1)" = "$SESSION_START_SHA256" ] && [ "$(claude_output subagent | shasum -a 256 | cut -d' ' -f1)" = "$SUBAGENT_START_SHA256" ]; }
hook_commands_print_the_output() {
  local d out
  d=$PWD/alynki-plugin
  out=$(CLAUDE_PLUGIN_ROOT=$d sh -c "$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$HOOKS")" </dev/null) && [ "$out" = "$(claude_output session)" ] &&
    out=$(CLAUDE_PLUGIN_ROOT=$d sh -c "$(jq -r '.hooks.SubagentStart[0].hooks[0].command' "$HOOKS")" </dev/null) && [ "$out" = "$(claude_output subagent)" ]
}
plugin_license_matches_root() { cmp -s LICENSE alynki-plugin/LICENSE; }
no_private_repository_link() { ! grep -rhoE --exclude-dir=.git 'github\.com/alynki/[A-Za-z0-9._-]+' README.md alynki-plugin | grep -vx 'github.com/alynki/plugin'; }
ok "the hook commands are CLAUDE_PLUGIN_ROOT paths, not inline heredocs" hook_commands_use_plugin_root
ok "the wording file and the executable hook script exist" hook_script_and_wording_exist
ok "session-start.sh claude prints hook JSON for both events" claude_output_is_hook_json
ok "the hook commands print the script's output (a real run with CLAUDE_PLUGIN_ROOT set)" hook_commands_print_the_output
ok "the hook text is kept as it was (sha256 of the script's Claude output, pinned; a change is the founder's decision)" hook_text_is_kept
ok "the plugin folder has its own LICENSE, identical to the repository's" plugin_license_matches_root
ok "no link points into a private repository" no_private_repository_link
ok "the plugin README says what the plugin runs, sends and fetches" grep -qF '## What it runs, sends and fetches' alynki-plugin/README.md
ok "the plugin README holds the token finding for the reviewer" grep -qF 'One setting is held for a reviewer' alynki-plugin/README.md

# The release (alynki/alynki#3264): 0.28.0 is the version that removed the variant and carries the listing; its note says what changed.
ok "the standard plugin's version is at least 0.28.0, the release of the listing and the directory validation" version_at_least "$STD" 0.28.0
ok "the 0.28.0 release note says the listing, the hook command form and the counts unchanged" grep -qF 'No tool and no prompt added (the counts are those of the diagram above: 44 tools and 44 prompts' README.md
ok "the plugin's version is named in the README's release notes" grep -qF "\`alynki\` $(jq -r .version "$STD"):" README.md

# One plugin for every client (alynki/alynki#3349): one wording file, one script, one address, one version.
ok "the standard plugin's version is at least 0.29.0, the release of one plugin for every client" version_at_least "$STD" 0.29.0
CODEX=alynki-plugin/.codex-plugin/plugin.json
AGY=alynki-plugin/.antigravity-plugin/plugin.json
MCP_URL=https://mcp.alynki.com/mcp
# One url per MCP file; Claude's .mcp.json is the server itself, the others sit under mcpServers.alynki.
mcp_urls() {
  jq -r '.alynki.url' alynki-plugin/.mcp.json
  jq -r '.mcpServers.alynki.url' alynki-plugin/mcp.json alynki-plugin/mcp_config.json
}
mcp_urls_all_match() { [ "$(mcp_urls | wc -l | tr -d ' ')" -eq 3 ] && [ "$(mcp_urls | sort -u | wc -l | tr -d ' ')" -eq 1 ] && [ "$(mcp_urls | head -n1)" = "$MCP_URL" ]; }
# The wording is found by two of its sentences; only load-first.md may hold them (this script is not scanned).
wording_only_in_load_first() {
  [ "$(grep -rlF --exclude-dir=.git --exclude-dir=scripts -e 'MANDATORY FIRST ACTION' -e 'PAGE TO COMPLETION' . | sort -u)" = "./alynki-plugin/hooks/load-first.md" ]
}
versions_all_match() { [ "$(jq -r .version "$CODEX")" = "$(jq -r .version "$STD")" ] && [ "$(jq -r .version "$AGY")" = "$(jq -r .version "$STD")" ]; }
names_all_match() { [ "$(jq -r .name "$CODEX")" = alynki ] && [ "$(jq -r .name "$AGY")" = alynki ]; }
codex_mcp_declares_transport() { jq -e '.mcpServers.alynki | has("type") and has("url")' alynki-plugin/mcp.json >/dev/null; }
antigravity_output_injects_the_wording() {
  sh alynki-plugin/hooks/session-start.sh antigravity session </dev/null | jq -e --rawfile w alynki-plugin/hooks/load-first.md '.injectSteps[0].systemMessage.systemMessage + "\n" == $w' >/dev/null
}
antigravity_hook_runs_the_script() {
  local out
  out=$(cd alynki-plugin && sh -c "$(jq -r '.["alynki-load-first"].SessionStart[0].command' hooks.json)" </dev/null) && [ "$out" = "$(sh alynki-plugin/hooks/session-start.sh antigravity session </dev/null)" ]
}
copilot_output_has_the_wording() {
  sh alynki-plugin/hooks/session-start.sh copilot session </dev/null | jq -e --rawfile w alynki-plugin/hooks/load-first.md '.additionalContext + "\n" == $w' >/dev/null
}
unknown_shape_refused() { ! sh alynki-plugin/hooks/session-start.sh nope session </dev/null >/dev/null 2>&1; }
no_grok_hook() { [ ! -e alynki-plugin/.grok-plugin ]; }
# shellcheck disable=SC2016 # the backticks are literal Markdown
readmes_cover_the_clients() {
  local f
  for f in README.md "$PLUGIN_README"; do
    grep -qF 'Codex CLI' "$f" && grep -qF 'Antigravity CLI' "$f" && grep -qF 'load_context' "$f" && grep -qF 'codex-hooks.json' "$f" && grep -qF 'trust' "$f" && grep -qF 'codex plugin add alynki@alynki-marketplace' "$f" || return 1
  done
}
ok "every MCP file (.mcp.json, mcp.json, mcp_config.json) names the same url, https://mcp.alynki.com/mcp" mcp_urls_all_match
ok "the hook wording exists in one place, hooks/load-first.md" wording_only_in_load_first
ok "the Codex and Antigravity manifests carry the Claude manifest's version" versions_all_match
ok "the Codex and Antigravity manifests are named alynki" names_all_match
ok "the Codex mcp.json declares a transport type and a url" codex_mcp_declares_transport
# The Antigravity Marketplace (alynki/alynki#3660): its bundle leaves out any path with a part starting with ".",
# and a submission needs three or fewer starter prompts and a square logo of 128 px or more.
agy_logo_is_bundled() {
  local rel f dims
  rel=$(jq -r .logo "$AGY"); f=alynki-plugin/$rel
  case "/$rel" in */.*) return 1 ;; esac
  [ -f "$f" ] || return 1
  # PNG IHDR: width and height are the big-endian words at bytes 16-23
  dims=$(od -An -tu1 -j16 -N8 "$f" | awk 'NF == 8 {print $1*16777216+$2*65536+$3*256+$4, $5*16777216+$6*65536+$7*256+$8}')
  [ "${dims% *}" = "${dims#* }" ] && [ "${dims% *}" -ge 128 ]
}
agy_has_starter_prompts() { jq -e '(.suggestedPrompts | length) == 3 and all(.suggestedPrompts[]; test("\\S"))' "$AGY" >/dev/null; }
listing_logo_matches() { cmp -s alynki-plugin/assets/logo.png alynki-plugin/.claude-plugin/icon.png; }
ok "the Antigravity logo is a bundled square PNG of 128 px or more, outside dot folders" agy_logo_is_bundled
ok "the Antigravity manifest carries three starter prompts" agy_has_starter_prompts
ok "assets/logo.png is the listing icon" listing_logo_matches
ok "session-start.sh antigravity prints the wording as an injected systemMessage" antigravity_output_injects_the_wording
ok "the Antigravity hooks.json command prints the script's output (run from the plugin root)" antigravity_hook_runs_the_script
ok "session-start.sh copilot prints the wording as top-level additionalContext" copilot_output_has_the_wording
ok "session-start.sh refuses an unknown shape" unknown_shape_refused
ok "no Grok hook ships (Grok Build session hooks cannot inject)" no_grok_hook
ok "both READMEs cover Codex CLI (its own hook file, the one-time trust, the marketplace install), Antigravity CLI and load_context" readmes_cover_the_clients

# Codex gets its own hook file (alynki/alynki#3442): Codex drops a SessionStart output carrying initialUserMessage.
CODEXHOOKS=alynki-plugin/hooks/codex-hooks.json
codex_manifest_names_its_hooks() { [ "$(jq -r .hooks "$CODEX")" = "./hooks/codex-hooks.json" ] && [ -s "$CODEXHOOKS" ]; }
# shellcheck disable=SC2016 # ${PLUGIN_ROOT} is literal text in the hook command
codex_hook_commands_use_the_codex_shape() {
  [ "$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$CODEXHOOKS")" = 'sh "${PLUGIN_ROOT}"/hooks/session-start.sh codex session' ] &&
    [ "$(jq -r '.hooks.SubagentStart[0].hooks[0].command' "$CODEXHOOKS")" = 'sh "${PLUGIN_ROOT}"/hooks/session-start.sh codex subagent' ] &&
    [ "$(jq -r '[.hooks[][].hooks[].command] | length' "$CODEXHOOKS")" -eq 2 ]
}
codex_session_output_is_additional_context_only() {
  sh alynki-plugin/hooks/session-start.sh codex session </dev/null |
    jq -e --rawfile w alynki-plugin/hooks/load-first.md '(.hookSpecificOutput | keys) == ["additionalContext", "hookEventName"] and .hookSpecificOutput.hookEventName == "SessionStart" and .hookSpecificOutput.additionalContext + "\n" == $w' >/dev/null
}
codex_hook_commands_print_the_output() {
  local d out
  d=$PWD/alynki-plugin
  out=$(PLUGIN_ROOT=$d sh -c "$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$CODEXHOOKS")" </dev/null) && [ "$out" = "$(sh alynki-plugin/hooks/session-start.sh codex session </dev/null)" ] &&
    out=$(PLUGIN_ROOT=$d sh -c "$(jq -r '.hooks.SubagentStart[0].hooks[0].command' "$CODEXHOOKS")" </dev/null) && [ "$out" = "$(claude_output subagent)" ]
}
ok "the standard plugin's version is at least 0.29.1, the release of the Codex hook file" version_at_least "$STD" 0.29.1
ok "the Codex manifest names hooks/codex-hooks.json, which exists" codex_manifest_names_its_hooks
ok "codex-hooks.json runs session-start.sh codex for SessionStart and SubagentStart, from PLUGIN_ROOT" codex_hook_commands_use_the_codex_shape
ok "session-start.sh codex prints SessionStart with the wording as additionalContext and no other field" codex_session_output_is_additional_context_only
ok "the Codex hook commands print the script's output (a real run with PLUGIN_ROOT set)" codex_hook_commands_print_the_output

readmes_cover_copilot() {
  local f
  for f in README.md "$PLUGIN_README"; do
    grep -qF 'chat.plugins.enabled' "$f" && grep -qF 'Chat: Install Plugin from Source' "$f" && grep -qF 'copilot plugin marketplace add alynki/plugin' "$f" &&
      grep -qF 'copilot plugin install alynki@alynki-marketplace' "$f" && grep -qF 'preview' "$f" && grep -qF 'ChatPluginsEnabled' "$f" || return 1
  done
}
# VS Code and GitHub Copilot CLI (alynki/alynki#3353, D11; alynki/alynki#3659): the root plugin.json is an Agent Plugins
# v1.0.0 manifest, which names no hooks or MCP file. Copilot reads mcp.json and com.github.copilot/hooks/hooks.json.
# Antigravity's hooks file has a fixed name and sits at the root as hooks.json.
COP=alynki-plugin/plugin.json
COPHOOKS=alynki-plugin/com.github.copilot/hooks/hooks.json
copilot_manifest_matches() { [ "$(jq -r .name "$COP")" = alynki ] && [ "$(jq -r .version "$COP")" = "$(jq -r .version "$STD")" ]; }
copilot_manifest_is_agent_plugins() {
  jq -e '."$schema" == "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json" and ((keys - ["$schema","name","version","description","author","homepage","repository","license","keywords","extensions"]) == []) and .license == "MIT"' "$COP" >/dev/null
}
copilot_old_files_are_gone() { [ -s "$COPHOOKS" ] && [ ! -e alynki-plugin/hooks/copilot-hooks.json ] && [ ! -e alynki-plugin/copilot-mcp.json ]; }
copilot_hooks_are_flat_version_1() {
  jq -e '.version == 1 and (.hooks | keys | sort) == ["sessionStart","subagentStart"] and ([.hooks[][] | has("hooks") | not] | all) and ([.hooks[][] | .type == "command" and (.timeoutSec | type == "number")] | all)' "$COPHOOKS" >/dev/null
}
# shellcheck disable=SC2016 # ${PLUGIN_ROOT} is literal text in the hook command
copilot_hooks_use_the_shared_script() {
  [ "$(jq -r '.hooks.sessionStart[0].command' "$COPHOOKS")" = 'sh "${PLUGIN_ROOT}/hooks/session-start.sh" copilot session' ] &&
    [ "$(jq -r '.hooks.subagentStart[0].command' "$COPHOOKS")" = 'sh "${PLUGIN_ROOT}/hooks/session-start.sh" copilot subagent' ]
}
# Run from outside the plugin, so only PLUGIN_ROOT can find the script.
copilot_hook_commands_print_the_output() {
  local d out
  d=$PWD/alynki-plugin
  out=$(cd / && PLUGIN_ROOT=$d sh -c "$(jq -r '.hooks.sessionStart[0].command' "$d/com.github.copilot/hooks/hooks.json")" </dev/null) && [ "$out" = "$(sh alynki-plugin/hooks/session-start.sh copilot session </dev/null)" ] &&
    out=$(cd / && PLUGIN_ROOT=$d sh -c "$(jq -r '.hooks.subagentStart[0].command' "$d/com.github.copilot/hooks/hooks.json")" </dev/null) && [ "$out" = "$(sh alynki-plugin/hooks/session-start.sh copilot subagent </dev/null)" ]
}
copilot_output_is_exactly_additional_context() {
  sh alynki-plugin/hooks/session-start.sh copilot session </dev/null | jq -e 'keys == ["additionalContext"]' >/dev/null &&
    sh alynki-plugin/hooks/session-start.sh copilot subagent </dev/null | jq -e 'keys == ["additionalContext"]' >/dev/null
}
copilot_mcp_is_agent_plugins() {
  jq -e '."$schema" == "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json" and ((keys - ["$schema","mcpServers"]) == []) and (.mcpServers.alynki | .type == "streamable-http" and ((keys - ["type","url"]) == []))' alynki-plugin/mcp.json >/dev/null
}
# Antigravity: the root hooks.json is the file its docs name; named groups, no Copilot keys, and its manifest has no hooks field.
antigravity_hooks_are_named_groups() {
  jq -e 'has("version") == false and has("hooks") == false and (.["alynki-load-first"].SessionStart | length) == 1' alynki-plugin/hooks.json >/dev/null &&
    jq -e 'has("hooks") | not' "$AGY" >/dev/null
}
ok "the Copilot root plugin.json carries the Claude manifest's name and version" copilot_manifest_matches
ok "the root plugin.json is an Agent Plugins v1.0.0 manifest: the schema, no field outside the specification, MIT" copilot_manifest_is_agent_plugins
ok "the Copilot hooks sit at com.github.copilot/hooks/hooks.json, and copilot-hooks.json and copilot-mcp.json are gone" copilot_old_files_are_gone
ok "the Copilot hooks file is version 1, flat, with sessionStart and subagentStart command entries and a timeout" copilot_hooks_are_flat_version_1
ok "the Copilot hooks run the shared script with the copilot shape (sh \"\${PLUGIN_ROOT}/hooks/session-start.sh\" copilot session|subagent)" copilot_hooks_use_the_shared_script
ok "the Copilot hook commands print the script's output (run from outside the plugin, PLUGIN_ROOT set)" copilot_hook_commands_print_the_output
ok "session-start.sh copilot prints exactly one top-level key, additionalContext, for both events" copilot_output_is_exactly_additional_context
ok "mcp.json is an Agent Plugins v1.0.0 MCP file: the schema and a streamable-http server with a url and nothing else" copilot_mcp_is_agent_plugins
ok "the Antigravity root hooks.json is named groups with no Copilot keys, and its manifest has no hooks field" antigravity_hooks_are_named_groups
ok "both READMEs cover VS Code, GitHub Copilot CLI, chat.plugins.enabled and the preview status" readmes_cover_copilot

# One pair of lists for every setup (alynki/alynki#3343, D9, J8; SEC-31, alynki/alynki#3447): 37 tools allowed,
# the seven access-changing tools asking, each list defined once.
SEVEN="create_principal_agent grant_principal invite_principal revoke_principal revoke_principal_agent revoke_principal_invite update_principal_agent"
lists_are_37_and_the_seven() {
  [ "$(grep -c . "$LIST")" -eq 37 ] && [ "$(sort -u "$LIST" | grep -c .)" -eq 37 ] && ! grep -qvE '^[a-z]+(_[a-z]+)+$' "$LIST" &&
    [ "$(sort "$ASKLIST" | tr '\n' ' ' | sed 's/ $//')" = "$SEVEN" ] && [ -z "$(sort "$LIST" "$ASKLIST" | uniq -d)" ]
}
# A sample of names must appear in no other plugin file (the READMEs describe the tools; the hook wording names load_context).
SAMPLE="grant_principal list_runs create_workflow delete_workflow save_check move_node revoke_principal_agent"
no_second_copy() {
  local t
  for t in $SAMPLE; do
    grep -qx "$t" "$LIST" "$ASKLIST" || return 1
    if grep -rlw --exclude-dir=.git --exclude=tools.txt --exclude=ask-tools.txt --exclude=README.md --exclude=load-first.md -- "$t" alynki-plugin .claude-plugin | grep -q .; then return 1; fi
  done
}
# Run the Antigravity script under a temporary HOME holding other settings and the allow rules 0.29 wrote for two of
# the seven: it merges the 37, removes the seven's allow rules, and a second run is byte-identical.
agy_idempotent() {
  local h f a ok=1
  h=$(mktemp -d) || return 1
  f=$h/.gemini/antigravity-cli/settings.json
  mkdir -p "$(dirname "$f")"
  printf '{"theme":"dark","permissions":{"deny":["command(sudo)"],"allow":["command(git)","mcp(alynki/grant_principal)","mcp(alynki/revoke_principal_agent)"]}}' >"$f"
  HOME=$h sh "$AGYSET" >/dev/null && cp "$f" "$h/first" && HOME=$h sh "$AGYSET" >/dev/null && cmp -s "$h/first" "$f" &&
    [ "$(jq -r '.theme' "$f")" = dark ] && [ "$(jq -c '.permissions.deny' "$f")" = '["command(sudo)"]' ] &&
    [ "$(jq -r '.permissions.allow[0]' "$f")" = 'command(git)' ] && [ "$(jq -r '[.permissions.allow[] | select(startswith("mcp(alynki/"))] | length' "$f")" -eq 37 ] &&
    [ "$(jq -r '.permissions.allow | length' "$f")" -eq 38 ] || ok=0
  for a in $SEVEN; do jq -e --arg r "mcp(alynki/$a)" '.permissions.allow | index($r) == null' "$f" >/dev/null || ok=0; done
  rm -rf "$h"
  [ "$ok" -eq 1 ]
}
agy_refuses_bad_json() {
  local h ok=1
  h=$(mktemp -d) || return 1
  mkdir -p "$h/.gemini/antigravity-cli"
  printf 'not json' >"$h/.gemini/antigravity-cli/settings.json"
  ! HOME=$h sh "$AGYSET" >/dev/null 2>&1 && [ "$(cat "$h/.gemini/antigravity-cli/settings.json")" = 'not json' ] || ok=0
  rm -rf "$h"
  [ "$ok" -eq 1 ]
}
ok "tools.txt has exactly 37 unique names and ask-tools.txt exactly the seven access-changing tools, with no name in both" lists_are_37_and_the_seven
skill_reads_list_no_wildcard() { grep -qF 'tools.txt' "$SKILL" && grep -qF 'never a wildcard' "$SKILL" && ! grep -qE 'Add .*mcp__plugin_alynki_alynki__\*' "$SKILL"; }
ok "the Claude setup skill reads the shared list (tools.txt) and its add step writes exact names, never a wildcard" skill_reads_list_no_wildcard
skill_asks_the_seven() {
  grep -qF 'ask-tools.txt' "$SKILL" && grep -qF 'one rule in `permissions.ask` per tool in `ask-tools.txt`' "$SKILL" &&
    grep -qF 'remove** from `permissions.allow` the exact rule of any tool in `ask-tools.txt`' "$SKILL" &&
    grep -qF 'still ask a person each time' "$SKILL" && absent 'All 44 tools are allowed' "$SKILL"
}
ok "the Claude setup skill writes an ask rule for each of the seven and removes their allow rules" skill_asks_the_seven
ok "the Antigravity script reads the shared list (tools.txt)" grep -qF 'tools.txt' "$AGYSET"
ok "the Antigravity script reads the asking list (ask-tools.txt)" grep -qF 'ask-tools.txt' "$AGYSET"
ok "no tool name outside the list file appears in the plugin's skill, scripts or manifests (no second copy)" no_second_copy
ok "the Antigravity script merges and is idempotent under a temporary HOME (two runs, cmp)" agy_idempotent
ok "the Antigravity script leaves an unparseable settings file untouched" agy_refuses_bad_json
ok "both READMEs describe the setup per client and the shared list" bash -c 'grep -qF tools.txt README.md && grep -qF setup-antigravity.sh README.md && grep -qF setup-antigravity.sh alynki-plugin/README.md'
ok "both READMEs say the seven access-changing tools ask (ask-tools.txt)" bash -c 'grep -qF ask-tools.txt README.md && grep -qF ask-tools.txt alynki-plugin/README.md'
ok "the standard plugin's version is at least 0.30.0, the release in which the seven ask again" version_at_least "$STD" 0.30.0

# The Microsoft 365 Copilot agent package (alynki/alynki#3357, D8, J12): Teams manifest 1.19, declarative agent v1.6, plugin v2.4,
# sources under copilot/ (not in alynki-plugin/, which is the Claude, Codex and Antigravity plugin), built into a zip by copilot/build.sh.
CP=copilot
CP_PLUGIN=$CP/alynki-plugin.json
CP_PLACEHOLDER='${ALYNKI_COPILOT_REGISTRATION_ID}'
png_dims() { printf '%sx%s' "$(od -An -tu1 -j16 -N4 "$1" | awk 'NF {print $1*16777216+$2*65536+$3*256+$4}')" "$(od -An -tu1 -j20 -N4 "$1" | awk 'NF {print $1*16777216+$2*65536+$3*256+$4}')"; }
copilot_json_parses() { jq -e . "$CP/manifest.json" "$CP/declarativeAgent.json" "$CP_PLUGIN" >/dev/null; }
copilot_schema_versions() {
  [ "$(jq -r .manifestVersion "$CP/manifest.json")" = 1.19 ] && [ "$(jq -r .version "$CP/declarativeAgent.json")" = v1.6 ] && [ "$(jq -r .schema_version "$CP_PLUGIN")" = v2.4 ] &&
    [ "$(jq -r '.copilotAgents.declarativeAgents[0].file' "$CP/manifest.json")" = declarativeAgent.json ] &&
    [ "$(jq -r '.actions[0].file' "$CP/declarativeAgent.json")" = alynki-plugin.json ] &&
    [ "$(jq -r '.id | test("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")' "$CP/manifest.json")" = true ]
}
copilot_runtime_url() {
  [ "$(jq -r '.runtimes | length' "$CP_PLUGIN")" -eq 1 ] && [ "$(jq -r '.runtimes[0].type' "$CP_PLUGIN")" = RemoteMCPServer ] &&
    [ "$(jq -r '.runtimes[0].spec.url' "$CP_PLUGIN")" = "$MCP_URL" ] && [ "$(mcp_urls | head -n1)" = "$MCP_URL" ]
}
copilot_auth_is_the_vault() {
  [ "$(jq -r '.runtimes[0].auth.type' "$CP_PLUGIN")" = OAuthPluginVault ] && [ "$(jq -r '.runtimes[0].auth.reference_id' "$CP_PLUGIN")" = "$CP_PLACEHOLDER" ]
}
# The tools are pinned (alynki/alynki#3453): mcp.alynki.com answers tools/list with 401 before sign-in, so Copilot's
# dynamic discovery finds none and nothing prompts the sign-in. functions, run_for_functions and mcp-tools.json name
# the same tools, and they are the plugin's tool list, so a tool added to the server and the list cannot be left out.
copilot_tools_are_pinned() {
  local f r m
  f=$(jq -r '[.functions[].name] | sort | join(" ")' "$CP_PLUGIN") && r=$(jq -r '.runtimes[0].run_for_functions | sort | join(" ")' "$CP_PLUGIN") &&
    m=$(jq -r '[.tools[].name] | sort | join(" ")' "$CP/mcp-tools.json") &&
    [ -n "$f" ] && [ "$f" = "$r" ] && [ "$f" = "$m" ] && [ "$(jq -r '.runtimes[0].spec.mcp_tool_description.file' "$CP_PLUGIN")" = mcp-tools.json ] &&
    jq -e '[.tools[] | has("name") and has("description") and has("inputSchema")] | all' "$CP/mcp-tools.json" >/dev/null
}
# The admin centre refuses a function with no description (alynki/alynki#3458): each carries its tool's, from mcp-tools.json.
copilot_functions_carry_descriptions() {
  jq -e --slurpfile t "$CP/mcp-tools.json" '($t[0].tools | map({(.name): .description}) | add) as $d
    | (.functions | length) > 0 and all(.functions[]; (.description // "") != "" and .description == $d[.name])' "$CP_PLUGIN" >/dev/null
}
copilot_pinned_tools_are_the_tool_list() {
  [ "$(jq -r '.tools[].name' "$CP/mcp-tools.json" | sort | tr '\n' ' ')" = "$(cat alynki-plugin/tools.txt alynki-plugin/ask-tools.txt 2>/dev/null | sort | tr '\n' ' ')" ]
}
copilot_instructions_name_load_context() {
  jq -e '.instructions | contains("load_context") and contains("cursor") and (length <= 8000)' "$CP/declarativeAgent.json" >/dev/null &&
    jq -e '.description_for_model | contains("load_context")' "$CP_PLUGIN" >/dev/null
}
copilot_first_chat_connects() {
  # the first chat only connects (#3463): Copilot calls no tool again in the chat where the person signed in,
  # so the agent offers a Connect starter and sends questions to a new chat; wording that the tools are
  # unavailable or cannot be called empties Copilot's function table, so it must never appear
  jq -e '.conversation_starters[0] == {"title": "Connect to Alynki", "text": "Connect me to Alynki"}' "$CP/declarativeAgent.json" >/dev/null &&
    jq -e '(.instructions | split("\n\n"))[2] | startswith("When the person has just allowed the connection or signed in to Alynki") and contains("call the tools again")' "$CP/declarativeAgent.json" >/dev/null &&
    ! jq -r .instructions "$CP/declarativeAgent.json" | grep -qiE 'unavailable|not available|cannot be called|can not be called'
}
copilot_icons_have_their_sizes() {
  [ "$(jq -r '.icons.color' "$CP/manifest.json")" = color.png ] && [ "$(jq -r '.icons.outline' "$CP/manifest.json")" = outline.png ] &&
    [ "$(png_dims "$CP/color.png")" = 192x192 ] && [ "$(png_dims "$CP/outline.png")" = 32x32 ]
}
copilot_listing_fields() {
  jq -e '.developer.name == "Alynki" and .developer.websiteUrl == "https://alynki.com" and .developer.privacyUrl == "https://alynki.com/privacy/" and .developer.termsOfUseUrl == "https://alynki.com/terms/" and (.name.short == "Alynki")' "$CP/manifest.json" >/dev/null &&
    [ "$(jq -r '.conversation_starters | length >= 3' "$CP/declarativeAgent.json")" = true ] && [ "$(jq -r .name "$CP/declarativeAgent.json")" = "$(jq -r .name.short "$CP/manifest.json")" ] && no_em_dash "$CP/manifest.json" "$CP/declarativeAgent.json" &&
    # the functions carry the server's tool descriptions verbatim (#3458), as mcp-tools.json does; the rest of the plugin is listing copy
    ! jq 'del(.functions)' "$CP_PLUGIN" | grep -q '—'
}
build_refuses_missing_and_placeholder() {
  local d rc=0
  d=$(mktemp -d) || return 1
  ! sh -c "$CP/build.sh" >/dev/null 2>&1 && ! "$CP/build.sh" '' "$d/a.zip" >/dev/null 2>&1 && ! "$CP/build.sh" "$CP_PLACEHOLDER" "$d/b.zip" >/dev/null 2>&1 &&
    ! "$CP/build.sh" 'ALYNKI_COPILOT_REGISTRATION_ID' "$d/c.zip" >/dev/null 2>&1 && [ -z "$(ls "$d")" ] || rc=1
  rm -rf "$d"
  [ "$rc" -eq 0 ]
}
build_zip_carries_the_id() {
  local d rc=0
  d=$(mktemp -d) || return 1
  "$CP/build.sh" dummy-reg-id-123 "$d/p.zip" >/dev/null 2>&1 &&
    [ "$(unzip -Z1 "$d/p.zip" | sort | tr '\n' ' ')" = "alynki-plugin.json color.png declarativeAgent.json manifest.json mcp-tools.json outline.png " ] &&
    [ "$(unzip -p "$d/p.zip" alynki-plugin.json | jq -r '.runtimes[0].auth.reference_id')" = dummy-reg-id-123 ] &&
    [ "$(unzip -p "$d/p.zip" manifest.json | jq -r .id)" = "$(jq -r .id "$CP/manifest.json")" ] &&
    ! unzip -p "$d/p.zip" alynki-plugin.json | grep -qF 'ALYNKI_COPILOT_REGISTRATION_ID' || rc=1
  rm -rf "$d"
  [ "$rc" -eq 0 ]
}
# shellcheck disable=SC2016 # the backticks are literal Markdown
readme_covers_copilot_package() {
  grep -qF '## Microsoft 365 Copilot' README.md && grep -qF 'copilot/build.sh' README.md && grep -qF 'Microsoft 365 admin centre' README.md && grep -qF 'Add agent' README.md && grep -qF 'OAuthPluginVault' README.md
}
ok "the Copilot package's three JSON files parse" copilot_json_parses
ok "the Copilot package is Teams manifest 1.19, declarative agent v1.6 and plugin v2.4, wired to each other, with a GUID id" copilot_schema_versions
ok "the Copilot agent opens with a Connect starter, says to ask in a new chat after a sign-in, and never calls its tools unavailable" copilot_first_chat_connects
ok "the plugin's runtime is one RemoteMCPServer at https://mcp.alynki.com/mcp, the url the MCP files carry" copilot_runtime_url
ok "the plugin's auth is OAuthPluginVault with the placeholder reference_id (the real id is never committed)" copilot_auth_is_the_vault
ok "the plugin pins its tools: functions, run_for_functions and mcp-tools.json name the same tools, each with a description and inputSchema" copilot_tools_are_pinned
ok "the pinned tools are exactly the plugin's tool list" copilot_pinned_tools_are_the_tool_list
ok "every Copilot function carries a non-empty description, its tool's from mcp-tools.json" copilot_functions_carry_descriptions
ok "the agent's instructions name load_context, paging to a cursor, within 8000 characters" copilot_instructions_name_load_context
ok "the icons are color.png 192x192 and outline.png 32x32, named by the manifest" copilot_icons_have_their_sizes
ok "the manifest carries the developer, privacy and terms URLs; the agent has three prompt starters and the same name; no em dash" copilot_listing_fields
ok "copilot/build.sh refuses a missing, empty or placeholder registration id and writes nothing" build_refuses_missing_and_placeholder
ok "copilot/build.sh given a dummy id writes a zip, six files at its root, whose plugin carries the id" build_zip_carries_the_id
ok "the README has a Microsoft 365 Copilot section: the build, the admin centre install, OAuthPluginVault" readme_covers_copilot_package

# Cursor (alynki/alynki#3505): a public client, alynki-cursor, no secret; the block is in the plugin folder and in both READMEs.
CUR=alynki-plugin/.cursor-plugin/plugin.json
CURMCP=alynki-plugin/cursor-mcp.json
CURMKT=.cursor-plugin/marketplace.json
cursor_manifest_matches() {
  [ "$(jq -r .name "$CUR")" = alynki ] && [ "$(jq -r .version "$CUR")" = "$(jq -r .version "$STD")" ] && [ "$(jq -r .mcpServers "$CUR")" = "./cursor-mcp.json" ] && [ -s "alynki-plugin/cursor-mcp.json" ]
}
cursor_mcp_is_the_public_client() {
  [ "$(jq -r '.mcpServers.alynki.url' "$CURMCP")" = "$MCP_URL" ] && [ "$(jq -r '.mcpServers.alynki.auth.CLIENT_ID' "$CURMCP")" = alynki-cursor ] && [ "$(jq -r '.mcpServers.alynki.auth | keys | join(",")' "$CURMCP")" = CLIENT_ID ]
}
cursor_marketplace_lists_alynki() {
  [ "$(jq -r '.plugins | length' "$CURMKT")" -eq 1 ] && [ "$(jq -r '.plugins[0].name' "$CURMKT")" = alynki ] && [ -d "$(jq -r '.plugins[0].source' "$CURMKT")" ]
}
readmes_show_the_cursor_block() {
  local f
  for f in README.md "$PLUGIN_README"; do
    grep -qF '"CLIENT_ID": "alynki-cursor"' "$f" && grep -qF '.cursor/mcp.json' "$f" && grep -qF 'https://alynki.com/docs/' "$f" || return 1
  done
}
ok "the standard plugin's version is at least 0.31.0, the release of the Cursor setup" version_at_least "$STD" 0.31.0
ok "the Cursor manifest is named alynki, carries the Claude manifest's version and names cursor-mcp.json, which exists" cursor_manifest_matches
ok "cursor-mcp.json names https://mcp.alynki.com/mcp with auth CLIENT_ID alynki-cursor and no secret" cursor_mcp_is_the_public_client
ok "the Cursor marketplace lists alynki alone, from a folder that exists" cursor_marketplace_lists_alynki
ok "both READMEs show Cursor's block (CLIENT_ID alynki-cursor, ~/.cursor/mcp.json) and link to alynki.com/docs" readmes_show_the_cursor_block
CURHOOKS=alynki-plugin/hooks/cursor-hooks.json
cursor_hooks_use_the_cursor_shape() {
  [ "$(jq -r .hooks "$CUR")" = "./hooks/cursor-hooks.json" ] && [ "$(jq -r '.hooks | keys | join(",")' "$CURHOOKS")" = sessionStart,subagentStart ] &&
    [ "$(jq -r '.hooks.sessionStart[0].command' "$CURHOOKS")" = 'sh "${CURSOR_PLUGIN_ROOT}"/hooks/session-start.sh cursor session' ] &&
    [ "$(jq -r '.hooks.subagentStart[0].command' "$CURHOOKS")" = 'sh "${CURSOR_PLUGIN_ROOT}"/hooks/session-start.sh cursor subagent' ]
}
cursor_output_is_additional_context_only() {
  local e
  for e in session subagent; do
    sh alynki-plugin/hooks/session-start.sh cursor "$e" </dev/null |
      jq -e --rawfile w alynki-plugin/hooks/load-first.md 'keys == ["additional_context"] and .additional_context + "\n" == $w' >/dev/null || return 1
  done
}
cursor_logo_is_the_listing_icon() { [ "$(jq -r .logo "$CUR")" = "./assets/logo.png" ] && cmp -s alynki-plugin/assets/logo.png alynki-plugin/.claude-plugin/icon.png; }
readmes_claim_no_unlisted_listing() {
  grep -qF 'not yet listed in the Cursor Marketplace' README.md && grep -qF 'not yet listed in the Cursor Marketplace' "$PLUGIN_README" &&
    grep -qF "not yet in Grok's connector catalog" README.md && ! grep -qF 'pick Alynki from the catalog' README.md && ! grep -qF 'open the Cursor Marketplace' README.md "$PLUGIN_README"
}
ok "the Cursor manifest names cursor-hooks.json, which runs session-start.sh cursor for sessionStart and subagentStart" cursor_hooks_use_the_cursor_shape
ok "session-start.sh cursor prints exactly one key, additional_context, holding the wording, for both events" cursor_output_is_additional_context_only
ok "the Cursor manifest's logo is the listing icon at assets/logo.png" cursor_logo_is_the_listing_icon
ok "the READMEs claim no Cursor Marketplace or Grok catalog listing" readmes_claim_no_unlisted_listing

# The permission hint (alynki/alynki#3582): the server's refusal no longer names /alynki:setup, so the shared hook text tells the person
# how to allow Alynki's tools in each client, in one paragraph every client reads. Each shape's session and subagent output must carry it.
# The count it names is the length of tools.txt.
hint_in() { # <shape> <event>: the printed output, once decoded, holds the whole hint
  local out
  out=$(sh alynki-plugin/hooks/session-start.sh "$1" "$2" </dev/null) || return 1
  printf '%s' "$out" | grep -qF 'If load_context is refused for permission, do not retry.' &&
    printf '%s' "$out" | grep -qF 'In Claude Code: run /alynki:setup, which allows '"$(grep -c . "$LIST")"' of Alynki' &&
    printf '%s' "$out" | grep -qF 'In Antigravity CLI: run sh bin/setup-antigravity.sh' &&
    printf '%s' "$out" | grep -qF 'In Codex CLI and in GitHub Copilot (VS Code or CLI): allow Alynki' &&
    printf '%s' "$out" | grep -qF 'If no user is present, end the session.'
}
ok "the Claude hook output (session and subagent) carries the permission hint: /alynki:setup, the 37 tools of tools.txt" bash -c "$(declare -f hint_in); LIST=$LIST; hint_in claude session && hint_in claude subagent"
ok "the Codex hook output (session and subagent) carries the permission hint" bash -c "$(declare -f hint_in); LIST=$LIST; hint_in codex session && hint_in codex subagent"
ok "the Antigravity session output carries the permission hint (setup-antigravity.sh)" bash -c "$(declare -f hint_in); LIST=$LIST; hint_in antigravity session"
ok "the Copilot hook output (session and subagent) carries the permission hint" bash -c "$(declare -f hint_in); LIST=$LIST; hint_in copilot session && hint_in copilot subagent"
ok "the standard plugin's version is at least 0.32.0, the release of the permission hint" version_at_least "$STD" 0.32.0
ok "the standard plugin's version is at least 0.33.0, the release of the Agent Plugins manifest" version_at_least "$STD" 0.33.0
ok "the hint's setup script exists and is the one the READMEs name" bash -c 'test -f alynki-plugin/bin/setup-antigravity.sh && grep -qF "bin/setup-antigravity.sh" alynki-plugin/hooks/load-first.md && grep -qF setup-antigravity.sh alynki-plugin/README.md'

echo "$n assertions, $failed failed"
[ "$failed" -eq 0 ] || exit 1
floor=${SETUP_CHECK_FLOOR:-0}
if [ "$n" -lt "$floor" ]; then
  echo "FAIL: $n assertions ran, the floor is $floor"
  exit 1
fi
