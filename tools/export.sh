#!/usr/bin/env bash
# Headless export for Linux/X11 and Windows Desktop presets.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT:-godot}"
OUT_DIR="${OUT_DIR:-$ROOT/build}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	if [[ "$GODOT_BIN" == "godot" && -x "${HOME:-}/bin/godot" ]]; then
		GODOT_BIN="${HOME}/bin/godot"
	else
		echo "godot not found (looked for '$GODOT_BIN'). Set GODOT to the engine binary." >&2
		exit 1
	fi
fi

if [[ ! -f "$ROOT/export_presets.cfg" ]]; then
	echo "export_presets.cfg not found in $ROOT" >&2
	exit 1
fi

mkdir -p "$OUT_DIR/linux" "$OUT_DIR/windows"

export_preset() {
	local preset="$1"
	local dest="$2"
	local pck="${dest%.*}.pck"
	echo "Exporting ${preset} -> ${dest}"
	if ! "$GODOT_BIN" --headless --path "$ROOT" --export-release "$preset" "$dest"; then
		echo "Godot export failed for preset '${preset}'." >&2
		echo "Install the official export templates for this engine version." >&2
		exit 1
	fi
	if [[ ! -f "$dest" ]]; then
		echo "export produced no binary: $dest" >&2
		exit 1
	fi
	if [[ ! -f "$pck" ]]; then
		echo "export produced no pack: $pck" >&2
		exit 1
	fi
}

export_preset "Linux/X11" "$OUT_DIR/linux/colony.x86_64"
export_preset "Windows Desktop" "$OUT_DIR/windows/colony.exe"

echo "Exports written under $OUT_DIR"
