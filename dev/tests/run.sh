#!/bin/sh
# Run every scenario. Needs lua5.1 -- the client's Lua version, so the same
# forward-reference and scoping rules apply here as in game.
#
#   cd dev/tests && ./run.sh
cd "$(dirname "$0")" || exit 1

SCENARIOS="normal no_settings settings_refuses cvar_refused tracking_refused
           no_cminimap no_entry no_cvar native native_halfway"

total=0
failed=0
for s in $SCENARIOS; do
    out=$(lua5.1 run_tests.lua "$s" 2>&1)
    ok=$(printf '%s\n' "$out" | grep -c '\[ok\]')
    bad=$(printf '%s\n' "$out" | grep -c '\[FAIL\]')
    total=$((total + ok))
    failed=$((failed + bad))
    printf '%-18s %3d ok  %d fail\n' "$s" "$ok" "$bad"
    printf '%s\n' "$out" | grep '\[FAIL\]\|lua5.1:'
done
printf '\n%d checks, %d failed\n' "$total" "$failed"
[ "$failed" -eq 0 ] || exit 1
