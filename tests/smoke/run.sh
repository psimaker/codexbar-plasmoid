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

export DISPLAY=:99 QT_QPA_PLATFORM=xcb
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
render panel-meters "$(package meters "$three" showPercentInPanel=true panelPercentSource=lowest)" \
    640x140 "${panel[@]}"
# The widget's own list moved to config.json on first start (#25).
expect_config codex claude antigravity
render panel-logos "$(package logos "$three" panelDisplayMode=logos showPercentInPanel=true)" \
    640x140 "${panel[@]}"
render panel-override "$(package override "$three" showPercentInPanel=true \
    'providerOverrides={"claude":{"panelDisplayMode":"logos"}}')" 640x140 "${panel[@]}"
render panel-countdown "$(package countdown "$three" panelDisplayMode=logos showPercentInPanel=true \
    showResetCountdown=true)" 640x140 "${panel[@]}"
render panel-vertical "$(package vertical "$three" showPercentInPanel=true showResetCountdown=true \
    separateIcons=true)" 160x520 -c org.kde.panel -f vertical -l leftedge
render popup "$(package popup "$three")" 560x860 -f planar
render popup-used "$(package popup-used "$three" usageBarsShowUsed=true)" 560x860 -f planar
# A provider only config.json knows, such as a user plugin, still shows up.
render popup-plugin "$(package plugin enabledProviders=codex,myplugin)" 560x860 -f planar
expect_config codex myplugin
# A config.json changed by the user wins over the widget's own list, which
# is not written to it.
config_state="claude myplugin" render popup-curated "$(package curated "$three")" 560x860 -f planar
expect_config claude myplugin
# A provider whose CLI process crashes says so on its card. The CLI stays
# usable, so no setup card takes the card's place.
config_state="antigravity" CODEXBAR_MOCK_CRASH=antigravity render popup-crash \
    "$(package crash enabledProviders=antigravity)" 560x860 -f planar
expect_config antigravity
# A config.json the CLI cannot write: the migration fails, the widget keeps
# its own list, and the popup shows the CLI's error.
CODEXBAR_MOCK_READONLY=1 render popup-readonly "$(package readonly "$three")" 560x860 -f planar
expect_config codex
# CLIs before 0.66 keep the widget's own list and leave config.json alone.
export CODEXBAR_MOCK_VERSION=0.65.0
render panel-legacy "$(package legacy "$three" panelDisplayMode=logos showPercentInPanel=true)" \
    640x140 "${panel[@]}"
unset CODEXBAR_MOCK_VERSION
expect_config codex

# A config.json the CLI cannot decode keeps the widget's own list and the
# migration pending, and the card shows the CLI's error. Once config.json can
# be read again, the next refresh (every minute here) adds the widget's
# providers.
echo broken >"$CODEXBAR_MOCK_STATE"
plasmoidviewer -a "$(package broken enabledProviders=claude refreshIntervalMinutes=1)" \
    -s 560x860 -f planar >"$out/popup-broken.log" 2>&1 &
broken_pid=$!
sleep "${SMOKE_WAIT:-15}"
shoot popup-broken 560x860
rm -f "$CODEXBAR_MOCK_STATE"
for _ in $(seq 90); do
    [[ -f "$CODEXBAR_MOCK_STATE" ]] && break
    sleep 1
done
sleep 3
expect_config codex claude
kill "$broken_pid" 2>/dev/null || true
wait "$broken_pid" 2>/dev/null || true

# Middle and double click on the merged meter run the configured command.
marker="$work/clicked"
plasmoidviewer -a "$(package clicks "$three" middleClickAction=command doubleClickAction=command \
    "launchCommand=touch $marker")" -s 640x140 "${panel[@]}" >"$out/clicks.log" 2>&1 &
clicks_pid=$!
sleep "${SMOKE_WAIT:-15}"
xdotool mousemove 27 70 click 2
sleep 3
[[ -f "$marker" ]] || { echo "Middle click did not run the command" >&2; failed=1; }
rm -f "$marker"
xdotool mousemove 27 70 click --repeat 2 --delay 60 1
sleep 3
[[ -f "$marker" ]] || { echo "Double click did not run the command" >&2; failed=1; }
kill "$clicks_pid" 2>/dev/null || true
wait "$clicks_pid" 2>/dev/null || true

# "About CodexBar" at the bottom of the popup opens the About page, which
# shows the version from metadata.json.
rm -f "$CODEXBAR_MOCK_STATE"
plasmoidviewer -a "$(package about "$three")" -s 560x860 -f planar >"$out/popup-about.log" 2>&1 &
about_pid=$!
sleep "${SMOKE_WAIT:-15}"
xdotool mousemove 248 726 click 1
sleep 3
shoot popup-about 560x860
kill "$about_pid" 2>/dev/null || true
wait "$about_pid" 2>/dev/null || true

# The settings window: the General and Providers pages, and the override
# dialog of Claude, whose seeded override gives it a ticked row.
rm -f "$CODEXBAR_MOCK_STATE"
plasmoidviewer -a "$(package settings "$three" \
    'providerOverrides={"claude":{"panelDisplayMode":"logos"}}')" -s 560x860 -f planar \
    >"$out/settings.log" 2>&1 &
settings_pid=$!
sleep "${SMOKE_WAIT:-15}"
# "Settings…" at the bottom of the popup opens the configuration window.
xdotool mousemove 230 694 click 1
sleep 5
settings_window="$(xdotool search --name 'CodexBar Settings' | head -n 1)"
if [[ -z "$settings_window" ]]; then
    echo "The settings window did not open" >&2
    failed=1
else
    xdotool windowsize "$settings_window" 1000 890
    sleep 2
    import -window "$settings_window" "$out/settings-general.png"
    # The sidebar's second category is the Providers page.
    xdotool mousemove 63 100 click 1
    sleep 3
    import -window "$settings_window" "$out/settings-providers.png"
    # Claude's gear button (second row) opens its override dialog.
    xdotool mousemove 980 204 click 1
    sleep 3
    import -window "$settings_window" "$out/settings-overrides.png"
fi
xwininfo -root -tree >"$out/settings.windows.txt" 2>&1 || true
kill "$settings_pid" 2>/dev/null || true
wait "$settings_pid" 2>/dev/null || true

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
