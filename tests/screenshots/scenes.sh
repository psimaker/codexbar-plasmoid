#!/usr/bin/env bash
# Shared state supplied by render.sh: out, viewer_pid and an isolated DISPLAY.
set -euo pipefail

scene_failures=0
active_scene_pid=""

finish_scene() {
    local status="$1" scene="$2"
    if [[ "$status" != 0 && -n "${DISPLAY:-}" ]]; then
        import -window root "$out/diagnostics/$scene.failure-screen.png" 2>/dev/null || true
        xwininfo -root -tree >"$out/diagnostics/$scene.failure-windows.txt" 2>&1 || true
    fi
    if [[ -n "$viewer_pid" ]]; then
        kill "$viewer_pid" 2>/dev/null || true
        wait "$viewer_pid" 2>/dev/null || true
    fi
    exit "$status"
}

run_scene() {
    local scene="$1"
    # A background subshell preserves errexit inside the scene. Calling the
    # scene directly as an if-condition would silently disable that safeguard.
    (
        trap 'finish_scene "$?" "$scene"' EXIT
        "$scene"
    ) &
    active_scene_pid=$!
    if ! wait "$active_scene_pid"; then
        scene_failures=$((scene_failures + 1))
        echo "Capture group $scene failed; continuing to collect the other views." >&2
    fi
    active_scene_pid=""
}
