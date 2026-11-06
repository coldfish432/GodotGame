#!/usr/bin/env bash
# scripts/run-test.sh <test-file.gd> <fps>
# Adapted from the A5 wrapper: this repository is itself the Godot project
# (--path .), and Godot is not on PATH here, so GODOT defaults to the console
# build one folder up. TEST_TIMEOUT overrides the 120 s limit for long suites.
set -o pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-../Godot_v4.7.2-stable_win64_console.exe}"
mkdir -p logs ../evidence
log="logs/$(basename "$1" .gd)_${2}fps.log"
timeout "${TEST_TIMEOUT:-120}" "$GODOT" --headless --path . --script "res://tests/$1" --fixed-fps "$2" 2>&1 | tee "$log"
status=$?
if grep -qE "SHADER ERROR|SCRIPT ERROR" "$log"; then status=1; fi
exit $status
