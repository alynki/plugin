#!/bin/sh
# Allows the Alynki tools in tools.txt in GitHub Copilot CLI, in every directory, by writing the marker
# file the plugin's permissionRequest hook looks for. The tools in ask-tools.txt still ask each time. Running it twice changes nothing.
#   sh bin/setup-copilot.sh          allow
#   sh bin/setup-copilot.sh --undo   ask again
set -eu
dir=${COPILOT_HOME:-${HOME:?HOME is not set}/.copilot}
marker=$dir/alynki-allow-tools
case ${1-} in
  '')
    if [ -f "$marker" ]; then
      echo "Copilot: already set up, nothing changed ($marker)"
    else
      mkdir -p "$dir"
      printf 'Alynki tools in the plugin tools.txt run without a prompt. Delete this file to be asked again.\n' >"$marker"
      echo "Copilot: Alynki tools now run without asking, except the seven that change who has access or manage agents ($marker)"
    fi ;;
  --undo)
    rm -f "$marker"
    echo "Copilot: Alynki tools ask again" ;;
  *) echo "usage: setup-copilot.sh [--undo]" >&2; exit 2 ;;
esac
