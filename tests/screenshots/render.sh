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
    if [[ -n "${active_scene_pid:-}" ]]; then
        kill "$active_scene_pid" 2>/dev/null || true
        wait "$active_scene_pid" 2>/dev/null || true
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
[[ -f /usr/share/color-schemes/BreezeLight.colors ]]

source "$repo/tests/smoke/helpers.sh"
source "$repo/tests/screenshots/scenes.sh"
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
    git -c safe.directory="$repo" -C "$repo" rev-parse HEAD
    git -c safe.directory="$repo" -C "$repo" status --short
    uname -m
    pacman -Q plasma-sdk libplasma qt6-base qt6-declarative breeze noto-fonts libfaketime imagemagick
    fc-match 'Noto Sans'
} >"$out/diagnostics/environment.txt"

start() {
    local name="$1" size="$2" form="$3"
    theme="$4"
    shift 4
    local capture_home scheme icons look
    case "$theme" in
        dark) scheme=BreezeDark; icons=breeze-dark; look=org.kde.breezedark.desktop ;;
        light) scheme=BreezeLight; icons=breeze; look=org.kde.breeze.desktop ;;
        *) echo "Unknown theme: $theme" >&2; return 1 ;;
    esac
    pkg="$(package "$name" enabledProviders=codex,claude,antigravity \
        showPercentInPanel=true showStatus=true showCost=true "$@")"
    "${capture[@]}" inject "$pkg"
    capture_home="$work/home-$name"
    mkdir -p "$capture_home/.local/bin" "$capture_home/.config" "$capture_home/run"
    chmod 700 "$capture_home/run"
    ln -s "$repo/tests/smoke/codexbar" "$capture_home/.local/bin/codexbar"
    cp "/usr/share/color-schemes/$scheme.colors" "$capture_home/.config/kdeglobals"
    cat >>"$capture_home/.config/kdeglobals" <<EOF

[General]
ColorScheme=$scheme
font=Noto Sans,10,-1,5,50,0,0,0,0,0
smallestReadableFont=Noto Sans,8,-1,5,50,0,0,0,0,0
[KDE]
widgetStyle=Breeze
AnimationDurationFactor=0
CursorBlinkRate=0
[Icons]
Theme=$icons
[KDE-Global GUI Settings]
LookAndFeelPackage=$look
EOF
    cat >"$capture_home/.config/plasmarc" <<'EOF'
[Theme]
name=default
EOF
    # Start from the mock CLI's curated config, not a plasmoid-only list.
    printf '%s\n' codex claude antigravity >"$CODEXBAR_MOCK_STATE"
    : >"$CODEXBAR_MOCK_STATE.calls"
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
        QT_FORCE_STDERR_LOGGING=1 \
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
        if "${capture[@]}" state "$log" "$kind" "$view" "$theme" >"$state.tmp" 2>"$work/pending"; then
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
    cp "$work/pending" "$out/diagnostics/$view.failure.txt"
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
    # ImageMagick 7.1.2 prints the count with its share: "131557 (0.0964)".
    python3 -c 'import sys; assert float(sys.argv[1].split()[0]) > 100, "Click changed fewer than 100 pixels"' "$difference"
}

stop() {
    expect_config codex claude antigravity
    [[ "$failed" == 0 ]]
    kill "$viewer_pid" 2>/dev/null || true
    wait "$viewer_pid" 2>/dev/null || true
    viewer_pid=""
    cp "$CODEXBAR_MOCK_STATE.calls" "${log%.log}.calls.txt"
    "${capture[@]}" errors "$log" "$pkg"
}

# Capture measured content with EXACTLY 16 logical pixels on every side.
# Match padding to an empty native corner so the old near-black seam vanishes.
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
    if [[ "$kind" == panel ]]; then
        # QML visibility alone cannot detect plasmoidviewer's overlaid toolbar.
        "${capture[@]}" panel-pixels "$state" "$a" >"$out/diagnostics/$name.pixels.json"
    fi
    local actual_width actual_height
    read -r actual_width actual_height < <(magick identify -format '%w %h\n' "$out/diagnostics/$name.content.png")
    [[ "$actual_width" -le "$width" && "$actual_height" -le "$height" ]] || {
        echo "$name: ${actual_width}x${actual_height} exceeds the ${width}x${height} content limit" >&2
        return 1
    }
    local corner='0,0' background
    if [[ "$kind" == general || "$kind" == providers ]]; then
        # The upper-left corner contains Plasma's native sidebar border.
        corner="$((actual_width - 2)),$((actual_height - 2))"
    fi
    background="$(magick "$out/diagnostics/$name.content.png" -format "%[pixel:p{$corner}]" info:)"
    magick "$out/diagnostics/$name.content.png" -bordercolor "$background" \
        -border 32 -strip "$out/images/$name.png"
}

shot() {
    local width height
    read -r width height < <("${capture[@]}" limit "$1")
    shoot "$1" "$width" "$height"
}

popup_views() {
    start popup 416x820 planar dark
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
    # The Notifications section adds three controls and a wrapped hint.
    xdo windowsize --sync "$window" 1856 2240
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
    xdo windowsize --sync "$window" 1856 736
    sleep 1
    wait_state providers settings-providers
    shot settings-providers
    stop
}

light_overview() {
    start overview-light 416x820 planar light
    wait_state popup overview-light
    shot overview-light
    stop
}

cli_setup() {
    # A truly nonexistent absolute executable avoids falling through to any CLI
    # on PATH. Capture only the actual setup card, leaving unrelated empty quota
    # rows out of this deliberately unavailable-CLI shot. Never click Install.
    [[ ! -e "$work/unavailable-codexbar" ]]
    start cli-setup-light 416x820 planar light enabledProviders=codex \
        "cliPath=$work/unavailable-codexbar" showCost=false
    wait_state setup cli-setup-light
    shot cli-setup-light
    stop
}

panel_views() {
    for mode in merged separate; do
        separate=false
        [[ "$mode" != separate ]] || separate=true
        # Like the smoke test: the 32px icon strip sits above the viewer toolbar.
        start "meters-$mode" 640x140 horizontal dark "separateIcons=$separate" "showPercentInPanel=$separate"
        wait_state panel "meters-$mode"
        shot "meters-$mode"
        stop
    done
    start logos-horizontal 640x140 horizontal dark panelDisplayMode=logos showResetCountdown=true
    wait_state panel logos-horizontal
    shot logos-horizontal
    stop

    # Crop only the native 32px icon grid. Add 6 logical pixels above/below
    # each row on the canvas, giving the spacing of a normal 44px panel without
    # importing toolbar borders or shadows from the surrounding viewer.
    # Preserve individual captures in diagnostics for reviewing size and crops.
    panel_width=0
    for name in meters-merged meters-separate logos-horizontal; do
        read -r width height < <(magick identify -format '%w %h\n' "$out/diagnostics/$name.content.png")
        [[ "$height" == 64 ]] || { echo "$name does not contain native 32px icons at 2x" >&2; exit 1; }
        [[ "$width" -le "$panel_width" ]] || panel_width="$width"
        mv "$out/images/$name.png" "$out/diagnostics/"
    done
    panel_background="$(magick "$out/diagnostics/meters-merged.content.png" -format '%[pixel:p{0,0}]' info:)"
    # The merged meter's capture has no color, so its corner pixel would make
    # a grayscale canvas; keep the canvas in sRGB for the colored logos.
    magick -size "$((panel_width + 64))x512" "xc:$panel_background" -colorspace sRGB \
        "$out/diagnostics/meters-merged.content.png" -geometry +32+84 -composite \
        "$out/diagnostics/meters-separate.content.png" -geometry +32+244 -composite \
        "$out/diagnostics/logos-horizontal.content.png" -geometry +32+404 -composite \
        -font "$caption_font" -pointsize 22 -fill '#bdc3c7' -gravity NorthWest \
        -annotate +32+32 'Merged meter (three providers)' -annotate +32+192 'Per-provider meters' \
        -annotate +32+352 'Provider logos with reset countdowns' \
        -strip "$out/images/panel-modes.png"
    [[ "$(magick "$out/images/panel-modes.png" -format '%[colorspace]' info:)" == sRGB ]] \
        || { echo "panel-modes.png lost its colors" >&2; exit 1; }
}

for scene in popup_views panel_views light_overview cli_setup; do
    run_scene "$scene"
done

# Preserve successful candidates and a partial contact sheet even if one
# group failed. The aggregate exit status still fails the workflow.
images=("$out/images/"*.png)
if [[ -f "${images[0]}" ]]; then
    magick montage "${images[@]}" -thumbnail 480x640 -tile 3x -geometry +24+24 \
        -background '#232629' "$out/contact-sheet.png"
    magick identify "${images[@]}" >"$out/manifest.txt"
    (cd "$out" && sha256sum images/*.png) >>"$out/manifest.txt"
fi
[[ "$scene_failures" == 0 ]] || { echo "$scene_failures capture group(s) failed" >&2; exit 1; }
[[ "${#images[@]}" == 7 ]] || { echo 'Expected seven publication candidates' >&2; exit 1; }
echo "Review candidates in $out/images; contact sheet and diagnostics are alongside them."
