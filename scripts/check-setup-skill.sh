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
in_readme_all() { for t in "$@"; do grep -qF "\`$t\`" README.md || return 1; done; }
named_in_readme() { grep -qF "\`$1\` $2" README.md; }

ok "the two setup skills are byte-identical" cmp -s "$SKILL" "$SEALED"

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
ok "the README names the sealed plugin's version" named_in_readme alynki-sealed "$(jq -r .version "$SLD")"

ok "the README does not say the sealed proxy mirrors none of the run surface" absent 'mirrors none of it' README.md
ok "the README names the run tools the sealed proxy mirrors" in_readme_all load_run load_step load_check save_run save_check create_run release_run
ok "the README names ALYNKI_AUTH_URL" grep -qF 'ALYNKI_AUTH_URL' README.md
ok "the README names CLAUDE_CONFIG_DIR, which headers.sh reads" grep -qF 'CLAUDE_CONFIG_DIR' README.md

echo "$n assertions, $failed failed"
[ "$failed" -eq 0 ] || exit 1
floor=${SETUP_CHECK_FLOOR:-0}
if [ "$n" -lt "$floor" ]; then
  echo "FAIL: $n assertions ran, the floor is $floor"
  exit 1
fi
