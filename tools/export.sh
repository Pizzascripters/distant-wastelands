#!/usr/bin/env bash
# Headless export for Linux/X11 and Windows Desktop presets.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT:-godot}"
OUT_DIR="${OUT_DIR:-$ROOT/build}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "godot not found (looked for '$GODOT_BIN'). Set GODOT to the engine binary." >&2
	exit 1
fi

mkdir -p "$OUT_DIR/linux" "$OUT_DIR/windows"

"$GODOT_BIN" --headless --path "$ROOT" --export-release "Linux/X11" "$OUT_DIR/linux/colony.x86_64"
"$GODOT_BIN" --headless --path "$ROOT" --export-release "Windows Desktop" "$OUT_DIR/windows/colony.exe"
