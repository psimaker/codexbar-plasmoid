#!/usr/bin/env bash
# Render the widget in plasmoidviewer against the mock CodexBar CLI, save a
# screenshot per scenario and fail on QML runtime errors. Run it inside a
# D-Bus session with Xvfb, plasmoidviewer and ImageMagick installed, as
# .github/workflows/plasma-smoke.yml does:
#   dbus-run-session -- bash tests/smoke/run.sh [output-dir]
set -euo pipefail

repo="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
out="${1:-$repo/dist/smoke}"
mkdir -p "$out"

work="$(mktemp -d)"
export HOME="$work/home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache" XDG_RUNTIME_DIR="$work/run"
mkdir -p "$HOME/.local/bin" "$XDG_CONFIG_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
# The widget puts ~/.local/bin first on the CLI's PATH.
ln -s "$repo/tests/smoke/codexbar" "$HOME/.local/bin/codexbar"
export CODEXBAR_FIXTURES="$repo/tests/smoke/fixtures" CODEXBAR_MOCK_STATE="$work/mock-config"

export DISPLAY=:99 QT_QPA_PLATFORM=xcb QT_FORCE_STDERR_LOGGING=1
Xvfb "$DISPLAY" -screen 0 1280x900x24 -nolisten tcp &
xvfb_pid=$!
trap 'kill "$xvfb_pid" 2>/dev/null || true' EXIT
sleep 2

# package NAME KEY=VALUE... prints the path of a copy of the widget whose
# config defaults are replaced, so every scenario starts from a known state.
package() {
    local dir="$work/pkg-$1"
    shift
    mkdir -p "$dir"
    cp -r "$repo/metadata.json" "$repo/contents" "$dir/"
    local xml="$dir/contents/config/main.xml" pair key value
    for pair in "$@"; do
        key="${pair%%=*}"
        value="${pair#*=}"
        awk -v key="$key" -v value="$value" '
            index($0, "<entry name=\"" key "\"") { hit = 1 }
            hit && /<default>/ { sub(/<default>.*<\/default>/, "<default>" value "</default>"); hit = 0 }
            { print }
        ' "$xml" >"$xml.new"
        mv "$xml.new" "$xml"
        grep -q -F "<default>$value</default>" "$xml" || { echo "unknown setting: $key" >&2; return 1; }
    done
    echo "$dir"
}

failed=0

# expect_config ID... checks that the mock config.json enables exactly these.
expect_config() {
    local want have
    want="$(printf '%s\n' "$@" | sort | tr '\n' ' ')"
    have="$({ cat "$CODEXBAR_MOCK_STATE" 2>/dev/null || echo codex; } | sort | tr '\n' ' ')"
    if [[ "$want" != "$have" ]]; then
        echo "config.json enables [$have], expected [$want]" >&2
        failed=1
    fi
}

# shoot NAME WIDTHxHEIGHT saves the screen and the widget's corner of it.
shoot() {
    xwininfo -root -tree >"$out/$1.windows.txt" 2>&1 || true
    import -window root "$out/$1.screen.png"
    magick "$out/$1.screen.png" -crop "${2}+0+0" +repage "$out/$1.png"
}

# render NAME PACKAGE WIDTHxHEIGHT [plasmoidviewer options...]; every run
# starts from a fresh config.json where only Codex is enabled, or from the
# mock's state in $config_state (space-separated) when that is set.
render() {
    local name="$1" pkg="$2" size="$3"
    shift 3
    rm -f "$CODEXBAR_MOCK_STATE"
    if [[ -n "${config_state:-}" ]]; then
        tr ' ' '\n' <<<"$config_state" >"$CODEXBAR_MOCK_STATE"
    fi
    plasmoidviewer -a "$pkg" -s "$size" "$@" >"$out/$name.log" 2>&1 &
    local pid=$!
    sleep "${SMOKE_WAIT:-15}"
    shoot "$name" "$size"
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
}

three="enabledProviders=codex,claude,antigravity"
panel=(-c org.kde.panel -f horizontal -l topedge)

# The Providers page follows config.json while it is open: the CLI enables
# Groq, the widget reads that (every minute here), and OK, which writes every
# key of the page, keeps Groq enabled.
rm -f "$CODEXBAR_MOCK_STATE"
plasmoidviewer -a "$(package external "$three" refreshIntervalMinutes=1)" -s 560x860 -f planar \
    >"$out/settings-external.log" 2>&1 &
external_pid=$!
sleep "${SMOKE_WAIT:-15}"
xdotool mousemove 230 694 click 1
sleep 5
external_window="$(xdotool search --name 'CodexBar Settings' | head -n 1)"
if [[ -z "$external_window" ]]; then
    echo "The settings window did not open" >&2
    failed=1
else
    xdotool windowsize "$external_window" 1000 890
    sleep 2
    xdotool mousemove 63 100 click 1
    sleep 3
    echo groq >>"$CODEXBAR_MOCK_STATE"
    sleep 70
    import -window "$external_window" "$out/settings-external.png"
    # OK at the bottom right closes the window and saves the page.
    xdotool mousemove 784 869 click 1
    sleep 5
    expect_config codex claude antigravity groq
fi
kill "$external_pid" 2>/dev/null || true
wait "$external_pid" 2>/dev/null || true

# QML runtime errors from the widget's own files fail the test, and so does
# an applet or containment that could not be loaded at all.
errors="$(grep -h -E 'contents/ui/.*(Error|Unable to assign|is not a function|Cannot read property|is not defined)|does not exist|Containment doesn.t exist' "$out"/*.log || true)"
if [[ -n "$errors" ]]; then
    echo "QML runtime errors:" >&2
    echo "$errors" >&2
    exit 1
fi
[[ "$failed" == 0 ]] || exit 1
echo "Rendered: $(cd "$out" && ls ./*.png | tr '\n' ' ')"
