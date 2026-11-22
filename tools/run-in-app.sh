#!/bin/sh
# Runs a CLI command inside the installed app bundle, so it uses the app's Accessibility grant.
# Usage: tools/run-in-app.sh mcbars
OUT="$(mktemp)"
open -n -W --stdout "$OUT" --stderr "$OUT" "$HOME/Applications/SpaceDock.app" --args "$@"
cat "$OUT"; rm -f "$OUT"
