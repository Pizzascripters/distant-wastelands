#!/usr/bin/env bash
# Official automated test entry.
# Starts a private Xvfb and runs res://tests/run.gd on that display.
# Extra args are forwarded after -- (filters or --list).
# Never uses the host session display. Never uses godot --headless.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT:-godot}"
XVFB_SCREEN="${COLONY_TEST_SCREEN:-1280x720x24}"
CACHE_ROOT="${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/colony-xvfb"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	if [[ "$GODOT_BIN" == "godot" && -x "${HOME:-}/bin/godot" ]]; then
		GODOT_BIN="${HOME}/bin/godot"
	else
		echo "godot not found (looked for '$GODOT_BIN'). Set GODOT to the engine binary." >&2
		exit 1
	fi
fi

die_missing_xvfb() {
	echo "Xvfb is required for automated tests." >&2
	echo "Install: sudo apt-get install -y xvfb" >&2
	echo "Do not run Godot against the host display, and do not use godot --headless for this runner." >&2
	exit 1
}

bootstrap_xvfb() {
	# Best-effort user-local copy when apt-get is available but xvfb is not installed.
	if ! command -v apt-get >/dev/null 2>&1 || ! command -v dpkg-deb >/dev/null 2>&1; then
		return 1
	fi
	echo "Xvfb not on PATH; downloading a user-local copy..." >&2
	local debs
	debs="$(mktemp -d)"
	# Clean partial extracts on failure.
	rm -rf "$CACHE_ROOT"
	mkdir -p "$CACHE_ROOT" "$debs"
	if ! (cd "$debs" && apt-get download xvfb xserver-common >/dev/null); then
		rm -rf "$debs"
		return 1
	fi
	local deb
	for deb in "$debs"/*.deb; do
		dpkg-deb -x "$deb" "$CACHE_ROOT"
	done
	rm -rf "$debs"
	[[ -x "$CACHE_ROOT/usr/bin/Xvfb" ]]
}

resolve_xvfb() {
	if command -v Xvfb >/dev/null 2>&1; then
		command -v Xvfb
		return 0
	fi
	if [[ -x "$CACHE_ROOT/usr/bin/Xvfb" ]]; then
		echo "$CACHE_ROOT/usr/bin/Xvfb"
		return 0
	fi
	if bootstrap_xvfb; then
		echo "$CACHE_ROOT/usr/bin/Xvfb"
		return 0
	fi
	return 1
}

XVFB_BIN="$(resolve_xvfb)" || die_missing_xvfb

pick_display() {
	local n
	for n in $(seq 90 119); do
		if [[ ! -e "/tmp/.X${n}-lock" && ! -S "/tmp/.X11-unix/X${n}" ]]; then
			echo "$n"
			return 0
		fi
	done
	echo "no free X display in :90–:119" >&2
	return 1
}

DISPLAY_N="$(pick_display)"
XVFB_PID=""

cleanup() {
	if [[ -n "$XVFB_PID" ]] && kill -0 "$XVFB_PID" 2>/dev/null; then
		kill "$XVFB_PID" 2>/dev/null || true
		wait "$XVFB_PID" 2>/dev/null || true
	fi
}
trap cleanup EXIT INT TERM

# Isolate from the session: do not inherit DISPLAY / WAYLAND_DISPLAY.
unset WAYLAND_DISPLAY || true
unset DISPLAY || true

"$XVFB_BIN" ":${DISPLAY_N}" -screen 0 "$XVFB_SCREEN" -nolisten tcp -ac +extension GLX >/dev/null 2>&1 &
XVFB_PID=$!

for _ in $(seq 1 50); do
	if [[ -S "/tmp/.X11-unix/X${DISPLAY_N}" ]] || [[ -e "/tmp/.X${DISPLAY_N}-lock" ]]; then
		break
	fi
	if ! kill -0 "$XVFB_PID" 2>/dev/null; then
		echo "Xvfb exited before the display came up." >&2
		exit 1
	fi
	sleep 0.05
done

if ! kill -0 "$XVFB_PID" 2>/dev/null; then
	echo "Xvfb failed to start." >&2
	exit 1
fi

export DISPLAY=":${DISPLAY_N}"
export COLONY_TEST_XVFB=1
# Default to software GL so tests do not use the session GPU.
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"

echo "Using virtual X server DISPLAY=${DISPLAY} (Xvfb pid ${XVFB_PID})"

# Script mode does not scan class_name. Write the cache Godot's editor
# would have written so global types resolve without opening the editor.
python3 - "$ROOT" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
src = root / "src"
entries = []
class_re = re.compile(r"^class_name\s+(\w+)\s*$")
extends_re = re.compile(r"^extends\s+(\w+)\s*$")
for path in sorted(src.rglob("*.gd")):
    lines = path.read_text(encoding="utf-8").splitlines()
    cls = None
    base = "RefCounted"
    for line in lines[:8]:
        m = class_re.match(line)
        if m:
            cls = m.group(1)
            continue
        m = extends_re.match(line)
        if m:
            base = m.group(1)
    if cls is None:
        continue
    rel = path.relative_to(root).as_posix()
    entries.append(
        "{\n"
        f"\"base\": &\"{base}\",\n"
        f"\"class\": &\"{cls}\",\n"
        "\"icon\": \"\",\n"
        "\"is_abstract\": false,\n"
        "\"is_tool\": false,\n"
        "\"language\": &\"GDScript\",\n"
        f"\"path\": \"res://{rel}\"\n"
        "}"
    )
godot = root / ".godot"
godot.mkdir(exist_ok=True)
(godot / "global_script_class_cache.cfg").write_text(
    "list=[" + ", ".join(entries) + "]\n", encoding="utf-8"
)
PY

set +e
"$GODOT_BIN" --display-driver x11 --audio-driver Dummy --path "$ROOT" -s res://tests/run.gd -- "$@"
status=$?
set -e
exit "$status"
