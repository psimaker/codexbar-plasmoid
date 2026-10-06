#!/usr/bin/env bash
# Run inside a D-Bus session on the Plasma CI image; see screenshots.yml.
set -euo pipefail

repo="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
out="${1:-$repo/dist/screenshots}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
[[ -z "$(ls -A "$out")" ]] || { echo "Output directory must be empty: $out" >&2; exit 1; }
mkdir -p "$out/images" "$out/diagnostics"
work="$(mktemp -d)"
viewer_pid="" xvfb_pid=""
cleanup() {
    local status=$?
    if [[ "$status" != 0 && -s "$work/display" && -n "$xvfb_pid" ]]; then
        import -window root "$out/diagnostics/failure-screen.png" 2>/dev/null || true
        xwininfo -root -tree >"$out/diagnostics/failure-windows.txt" 2>&1 || true
    fi
    [[ -z "$viewer_pid" ]] || kill "$viewer_pid" 2>/dev/null || true
    [[ -z "$xvfb_pid" ]] || kill "$xvfb_pid" 2>/dev/null || true
    rm -rf "$work"
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

for command in Xvfb plasmoidviewer xdotool xwininfo import magick python3 dbus-run-session fc-match; do
    command -v "$command" >/dev/null || { echo "Missing dependency: $command" >&2; exit 1; }
done
: "${DBUS_SESSION_BUS_ADDRESS:?Run with dbus-run-session -- bash tests/screenshots/render.sh}"
faketime=/usr/lib/faketime/libfaketime.so.1
[[ -f "$faketime" ]] || { echo "Missing Arch libfaketime: $faketime" >&2; exit 1; }
[[ -f /usr/share/color-schemes/BreezeDark.colors ]]

source "$repo/tests/smoke/helpers.sh"
capture=(python3 "$repo/tests/screenshots/capture.py")
failed=0
export CODEXBAR_MOCK_STATE="$work/mock-config"
mkdir -p "$work/fixtures"
cp "$repo/tests/smoke/fixtures/providers.txt" "$work/fixtures/"
cp "$repo/tests/screenshots/fixtures/"*.json "$work/fixtures/"

# No desktop, other applets, compositor, wallpaper or window decorations.
# Qt renders directly at 2x; ImageMagick only crops and adds the canvas.
Xvfb -displayfd 3 -screen 0 3200x3200x24 -dpi 96 -nolisten tcp \
    3>"$work/display" >"$out/diagnostics/xvfb.log" 2>&1 &
xvfb_pid=$!
for _ in {1..50}; do
    [[ ! -s "$work/display" ]] || break
    kill -0 "$xvfb_pid"
    sleep 0.1
done
[[ -s "$work/display" ]]
export DISPLAY=":$(cat "$work/display")"
xdo() { timeout 10s xdotool "$@"; }
xdo mousemove 3199 3199
caption_font="$(fc-match -f '%{file}' 'Noto Sans:style=Regular')"

{
    git -C "$repo" rev-parse HEAD
    git -C "$repo" status --short
    uname -m
    pacman -Q plasma-sdk libplasma qt6-base qt6-declarative breeze noto-fonts libfaketime imagemagick
    fc-match 'Noto Sans'
} >"$out/diagnostics/environment.txt"

start() {
    local name="$1" size="$2" form="$3"
    shift 3
    local pkg capture_home
    pkg="$(package "$name" enabledProviders=codex,claude,antigravity \
        showPercentInPanel=true showStatus=true showCost=true "$@")"
    "${capture[@]}" inject "$pkg"
    capture_home="$work/home-$name"
    mkdir -p "$capture_home/.local/bin" "$capture_home/.config" "$capture_home/run"
    chmod 700 "$capture_home/run"
    ln -s "$repo/tests/smoke/codexbar" "$capture_home/.local/bin/codexbar"
    cp /usr/share/color-schemes/BreezeDark.colors "$capture_home/.config/kdeglobals"
    cat >>"$capture_home/.config/kdeglobals" <<'EOF'

[General]
ColorScheme=BreezeDark
font=Noto Sans,10,-1,5,50,0,0,0,0,0
smallestReadableFont=Noto Sans,8,-1,5,50,0,0,0,0,0
[KDE]
widgetStyle=Breeze
AnimationDurationFactor=0
CursorBlinkRate=0
[Icons]
Theme=breeze-dark
[KDE-Global GUI Settings]
LookAndFeelPackage=org.kde.breezedark.desktop
EOF
    cat >"$capture_home/.config/plasmarc" <<'EOF'
[Theme]
name=default
EOF
    # Start from the mock CLI's curated config, not a plasmoid-only list.
    printf '%s\n' codex claude antigravity >"$CODEXBAR_MOCK_STATE"
    log="$out/diagnostics/$name.log"
    local options=(-f planar)
    if [[ "$form" == horizontal ]]; then
        options=(-c org.kde.panel -f horizontal -l topedge)
    elif [[ "$form" == vertical ]]; then
        options=(-c org.kde.panel -f vertical -l leftedge)
    fi
    # Only this child gets a disposable HOME and a clean environment. Nothing
    # can inherit credentials, a real CLI path or the caller's desktop config.
    env -i HOME="$capture_home" PATH="$capture_home/.local/bin:/usr/bin:/bin" \
        XDG_CONFIG_HOME="$capture_home/.config" XDG_DATA_HOME="$capture_home/.local/share" \
        XDG_CACHE_HOME="$capture_home/.cache" XDG_RUNTIME_DIR="$capture_home/run" \
        XDG_DATA_DIRS=/usr/local/share:/usr/share XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true \
        KDE_SESSION_VERSION=6 DISPLAY="$DISPLAY" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        LC_ALL=C.UTF-8 LANGUAGE=en_US TZ=UTC QT_QPA_PLATFORM=xcb QT_SCALE_FACTOR=2 \
        QT_AUTO_SCREEN_SCALE_FACTOR=0 QT_FONT_DPI=96 QT_QUICK_BACKEND=software \
        QT_QPA_PLATFORMTHEME=kde QT_STYLE_OVERRIDE=breeze QT_QUICK_CONTROLS_STYLE=org.kde.desktop \
        LD_PRELOAD="$faketime" FAKETIME='2026-10-06 12:00:00' DONT_FAKE_MONOTONIC=1 \
        CODEXBAR_FIXTURES="$work/fixtures" CODEXBAR_MOCK_STATE="$CODEXBAR_MOCK_STATE" \
        plasmoidviewer -a "$pkg" -s "$size" "${options[@]}" >"$log" 2>&1 &
    viewer_pid=$!
    window=""
    for _ in {1..120}; do
        window="$(xdo search --all --onlyvisible --pid "$viewer_pid" 2>/dev/null | head -n 1 || true)"
        [[ -z "$window" ]] || break
        kill -0 "$viewer_pid"
        sleep 0.5
    done
    [[ -n "$window" ]] || { echo "No viewer window: $name" >&2; return 1; }
    # xdotool uses device pixels; plasmoidviewer -s uses logical pixels.
    local width="${size%x*}" height="${size#*x}"
    xdo windowsize --sync "$window" "$((width * 2))" "$((height * 2))"
    xdo windowmove --sync "$window" 0 0
    xdo windowfocus --sync "$window"
}

wait_state() {
    local kind="$1" view="$2" stable=0
    state="$out/diagnostics/$view.json"
    rm -f "$work/previous-state"
    for _ in {1..120}; do
        kill -0 "$viewer_pid"
        if "${capture[@]}" state "$log" "$kind" "$view" >"$state.tmp" 2>"$work/pending"; then
            if cmp -s "$state.tmp" "$work/previous-state"; then
                stable=$((stable + 1))
            else
                stable=0
            fi
            cp "$state.tmp" "$work/previous-state"
            if [[ "$stable" -ge 2 ]]; then
                mv "$state.tmp" "$state"
                return
            fi
        else
            stable=0
        fi
        sleep 0.5
    done
    cat "$work/pending" >&2
    echo "Timed out waiting for $view; see $log" >&2
    return 1
}

click() {
    local x y
    read -r x y < <("${capture[@]}" click "$state" "$1")
    import -window "$window" "$work/before.png"
    xdo mousemove --window "$window" "$x" "$y" click 1
    xdo mousemove 3199 3199
}

changed() {
    import -window "$window" "$work/after.png"
    # Semantic assertions alone must not bless a missed click. Compare the
    # actual pixels too; hover has already been cleared before both frames.
    local difference
    difference="$(magick compare -metric AE "$work/before.png" "$work/after.png" null: 2>&1 || true)"
    python3 -c 'import sys; assert float(sys.argv[1]) > 100, "Click changed fewer than 100 pixels"' "$difference"
}

stop() {
    expect_config codex claude antigravity
    [[ "$failed" == 0 ]]
    kill "$viewer_pid" 2>/dev/null || true
    wait "$viewer_pid" 2>/dev/null || true
    viewer_pid=""
    if rg_errors="$(grep -E '([A-Za-z]+Error:|Unable to assign|is not a function|Cannot read property|is not defined|does not exist|Containment doesn.t exist)' "$log")"; then
        echo "$rg_errors" >&2
        return 1
    fi
}

# Capture the measured QML content, with at least 16 logical pixels of clear
# space on every side. Never shrink content to make it fit a planned canvas.
shoot() {
    local name="$1" width="$2" height="$3" crop a b kind stable=0
    kind="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["kind"])' "$state")"
    a="$out/diagnostics/$name.window.png"
    b="$work/next.png"
    import -window "$window" "$a"
    for _ in {1..20}; do
        sleep 0.5
        import -window "$window" "$b"
        if magick compare -metric AE "$a" "$b" null: 2>"$work/difference"; then
            stable=$((stable + 1))
            [[ "$stable" -lt 3 ]] || break
        else
            stable=0
        fi
        cp "$b" "$a"
    done
    [[ "$stable" -ge 3 ]] || { echo "Unstable pixels in $name" >&2; return 1; }
    # Re-read the report after layout and pixels settle. A stale rectangle or
    # a window chosen from the wrong process must not produce a valid crop.
    wait_state "$kind" "$name"
    crop="$("${capture[@]}" crop "$state")"
    [[ "$(magick identify -format '%w %h' "$a")" == "$("${capture[@]}" window "$state")" ]] || {
        echo "QML and X11 window dimensions disagree for $name" >&2
        return 1
    }
    magick "$a" -crop "$crop" +repage "$out/diagnostics/$name.content.png"
    local actual_width actual_height
    read -r actual_width actual_height < <(magick identify -format '%w %h\n' "$out/diagnostics/$name.content.png")
    [[ "$actual_width" -le "$((width - 64))" && "$actual_height" -le "$((height - 64))" ]] || {
        echo "$name: ${actual_width}x${actual_height} does not fit ${width}x${height} with 32px margins" >&2
        return 1
    }
    magick "$out/diagnostics/$name.content.png" -background '#232629' -gravity center \
        -extent "${width}x${height}" -strip "$out/images/$name.png"
}

shot() {
    local width height
    read -r width height < <("${capture[@]}" size "$1")
    shoot "$1" "$width" "$height"
}

start popup 416x820 planar
wait_state popup overview
shot overview
click tab:codex
wait_state popup navigation
# Wait specifically for the selected tab before locating its cost action.
for _ in {1..60}; do
    wait_state popup navigation
    [[ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["tab"])' "$state")" != codex ]] || break
    sleep 0.5
done
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["tab"] == "codex"' "$state"
changed
click 'menu:Refresh cost history'
wait_state popup provider-codex
changed
shot provider-codex

click 'menu:Settings…'
settings_window=""
for _ in {1..120}; do
    settings_window="$(xdo search --all --onlyvisible --pid "$viewer_pid" --name 'CodexBar Settings' 2>/dev/null | head -n 1 || true)"
    [[ -z "$settings_window" ]] || break
    sleep 0.5
done
[[ -n "$settings_window" ]] || { echo 'Settings click did not open its window' >&2; exit 1; }
window="$settings_window"
xdo windowsize --sync "$window" 1856 2880
xdo windowmove --sync "$window" 0 0
xdo windowfocus --sync "$window"
wait_state general settings-general
shot settings-general
click text:Providers
wait_state providers navigation
changed
click 'text:Show enabled only'
wait_state providers settings-providers
changed
xdo windowsize --sync "$window" 1856 1088
sleep 1
wait_state providers settings-providers
shot settings-providers
stop

for mode in merged separate; do
    start "meters-$mode" 416x64 horizontal "separateIcons=$([[ "$mode" == separate ]] && echo true || echo false)"
    wait_state panel "meters-$mode"
    shoot "meters-$mode" 960 144
    stop
done
# Two real panel captures in one comparison plate. Captions sit outside the
# widget; no pixels inside either capture are altered.
magick -size 960x352 xc:'#232629' \
    "$out/images/meters-merged.png" -geometry +0+32 -composite \
    "$out/images/meters-separate.png" -geometry +0+208 -composite \
    -font "$caption_font" -pointsize 22 -fill '#bdc3c7' -gravity NorthWest \
    -annotate +32+32 'Merged meter' -annotate +32+208 'Per-provider meters' \
    -strip "$out/images/panel-meters.png"
mv "$out/images/meters-"*.png "$out/diagnostics/"

start logos-horizontal 544x64 horizontal panelDisplayMode=logos showResetCountdown=true
wait_state panel panel-logos-horizontal
shot panel-logos-horizontal
stop
start logos-vertical 96x224 vertical panelDisplayMode=logos showResetCountdown=true
wait_state panel panel-logos-vertical
shot panel-logos-vertical
stop

magick montage "$out/images/overview.png" "$out/images/provider-codex.png" \
    "$out/images/panel-meters.png" "$out/images/panel-logos-horizontal.png" \
    "$out/images/panel-logos-vertical.png" "$out/images/settings-general.png" \
    "$out/images/settings-providers.png" -thumbnail 480x640 -tile 3x -geometry +24+24 \
    -background '#232629' "$out/contact-sheet.png"
magick identify "$out/images/"*.png >"$out/manifest.txt"
(cd "$out" && sha256sum images/*.png) >>"$out/manifest.txt"
echo "Review candidates in $out/images; contact sheet and diagnostics are alongside them."
