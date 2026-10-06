#!/usr/bin/env python3
"""Install the observer and validate its reports; never create widget pixels."""

import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import sys

PROVIDERS = {"codex", "claude", "antigravity"}
EPOCH_MS = 1791288000000  # 2026-10-06 12:00:00 UTC
# These bound content size, not a canvas to stretch it into. The renderer
# adds exactly 32 physical pixels (16 logical pixels) on all four sides.
LIMITS = {
    "overview": (760, 820),
    "overview-light": (760, 820),
    "provider-codex": (760, 1320),
    "cli-setup-light": (760, 1280),
    "meters-merged": (256, 88),
    "meters-separate": (800, 88),
    "logos-horizontal": (1100, 88),
    "settings-general": (1856, 2240),
    "settings-providers": (1856, 736),
}
# Same error patterns as tests/smoke/run.sh, applied only to this package.
QML_ERRORS = re.compile(
    r"contents/ui/.*(Error|Unable to assign|is not a function|Cannot read property|is not defined)"
    r"|does not exist|Containment doesn.t exist"
)
LOAD_ERRORS = re.compile(r"does not exist|Containment doesn.t exist")
CONFIG_WARNING = re.compile(
    r"/config(?:General|Providers)\.qml:(?:\d+:)*\s*Setting initial properties failed: "
    r"SimpleKCM does not have a property called cfg_configWriteError(?:Default)?$"
)
EMAIL = re.compile(r"[\w.+-]+@[\w.-]+\.[a-zA-Z]{2,}")


def inject(package):
    ui = Path(package) / "contents/ui"
    shutil.copyfile(Path(__file__).with_name("Probe.qml"), ui / "ScreenshotProbe.qml")
    for name, anchor, fields in [
        ("CompactBar.qml", "id: compactRoot", 'target: compactRoot; subject: grid; delegates: providerRepeater; kind: "panel"'),
        ("FullView.qml", "id: fullRoot", 'target: fullRoot; subject: mainColumn; viewport: flick; kind: "popup"'),
        ("CliSetupCard.qml", "id: card", 'target: card; subject: card; kind: "setup"'),
        ("configGeneral.qml", "id: page", 'target: page; subject: page; kind: "general"'),
        ("configProviders.qml", "id: page", 'target: page; subject: page; kind: "providers"'),
    ]:
        path = ui / name
        source = path.read_text()
        if source.count(anchor) != 1:
            raise ValueError(f"Observer anchor changed in {name}: {anchor}")
        source = source.replace(anchor, anchor + "\n    property QtObject screenshotProbe: "
                                + "ScreenshotProbe { " + fields + " }")
        path.write_text(source)


def state(log, kind):
    found = None
    for line in Path(log).read_text(errors="replace").splitlines():
        if "SCREENSHOT_STATE " in line:
            candidate = json.loads(line.split("SCREENSHOT_STATE ", 1)[1])
            if candidate["kind"] == kind:
                found = candidate
    if found is None:
        raise ValueError(f"No {kind} observer report yet")
    return found


def require(condition, message):
    if not condition:
        raise ValueError(message)


def qml_errors(log, package):
    # Plasma's desktop containment also has a contents/ui/main.qml. Scope by
    # the actual package URL, not that suffix. The two configWriteError initial
    # properties are deliberately absent from the settings pages; their names
    # contain "Error" but their expected warnings are not runtime errors.
    owned = (Path(package).resolve() / "contents/ui").as_uri() + "/"
    return [line for line in log.splitlines() if QML_ERRORS.search(line)
            and (LOAD_ERRORS.search(line) or (owned in line and not CONFIG_WARNING.search(line)))]


def inside(inner, outer):
    return (inner["x"] >= outer["x"] - 0.5 and inner["y"] >= outer["y"] - 0.5
            and inner["x"] + inner["width"] <= outer["x"] + outer["width"] + 0.5
            and inner["y"] + inner["height"] <= outer["y"] + outer["height"] + 0.5)


def panel_geometry(report):
    require(report["window"] == {"width": 640, "height": 140}, "Use the smoke test's 640x140 panel viewer")
    require(report["iconSide"] == 32 and not report["vertical"], "Panel icons must retain their native 32px size")
    strip = report["rect"]
    require(0 < strip["height"] <= 32 and strip["y"] >= 0
            and strip["y"] + strip["height"] <= 88, "Panel strip enters the viewer toolbar area")
    require(len(report["toolbar"]) >= 2, "Cannot locate the viewer toolbar")
    require(all(strip["y"] + strip["height"] + 2 <= r["y"] for r in report["toolbar"]),
            "Viewer toolbar overlaps the panel strip")
    require([item["id"] for item in report["items"]] == report["icons"], "Missing visible provider delegates")
    if report["icons"] == ["__merged__"]:
        require(set(report["mergedProviders"]) == PROVIDERS, "Merged meter must include all three providers")
    else:
        require(set(report["icons"]) == PROVIDERS, "Panel must show all three providers")
    right = strip["x"]
    for item in report["items"]:
        r = item["rect"]
        require(not item["clipped"] and inside(r, strip) and r["x"] >= right - 0.5,
                f"Clipped or overlapping provider: {item['id']}")
        right = r["x"] + r["width"]
        require(item["icon"]["width"] == 32 and item["icon"]["height"] == 32
                and inside(item["icon"], r), f"Missing or incorrectly sized icon: {item['id']}")
        require(all(inside(t, r) for t in item["textRects"]), f"Label outside provider: {item['id']}")


def pixel_bounds(rect):
    return (math.floor(rect["x"] * 2), math.floor(rect["y"] * 2),
            math.ceil((rect["x"] + rect["width"]) * 2), math.ceil((rect["y"] + rect["height"]) * 2))


def panel_pixels(report, pixels):
    """Check X11 pixels as well as QML state: covered items remain 'visible'."""
    panel_geometry(report)
    geometry(report)
    width, height = (round(report["window"][axis] * 2) for axis in ("width", "height"))
    require(len(pixels) == width * height * 3, "Unexpected native RGB image size")
    background = pixels[:3]  # Empty top-left corner of the panel viewer.

    def pixel(x, y):
        offset = (y * width + x) * 3
        return pixels[offset:offset + 3]

    def different(a, b):
        return max(abs(x - y) for x, y in zip(a, b)) > 8  # Smoke test's 3% fuzz.

    def points(bounds):
        left, top, right, bottom = bounds
        return ((x, y) for y in range(top, bottom) for x in range(left, right))

    allowed = set()
    evidence = []
    for item in report["items"]:
        icon = pixel_bounds(item["icon"])
        ink = [(x, y) for x, y in points(icon) if different(pixel(x, y), background)]
        require(len(ink) >= 300, f"Missing rendered icon: {item['id']}")
        extent = [max(p[axis] for p in ink) - min(p[axis] for p in ink) + 1 for axis in (0, 1)]
        require(min(extent) >= 32, f"Incomplete rendered icon: {item['id']}")
        if report["mode"] == "logos":
            color = item["color"].lstrip("#")[-6:]
            rgb = bytes(int(color[i:i + 2], 16) for i in (0, 2, 4))
            require(sum(not different(pixel(x, y), rgb) for x, y in ink) >= 300,
                    f"Provider logo color missing or covered: {item['id']}")
        else:
            # Native meters have empty margins inside the 32px Canvas. A
            # toolbar button/background covering it fills those margins.
            left, top, right, bottom = icon
            require(all(left + 2 <= x < right - 2 and top + 2 <= y < bottom - 2 for x, y in ink),
                    f"Unexpected pixels over meter: {item['id']}")
        for rect in item["textRects"]:
            require(sum(different(pixel(x, y), background) for x, y in points(pixel_bounds(rect))) >= 30,
                    f"Missing rendered label: {item['id']}")
        for rect in [item["icon"], *item["textRects"]]:
            left, top, right, bottom = pixel_bounds(rect)
            allowed.update(points((left - 1, top - 1, right + 1, bottom + 1)))
        evidence.append({"provider": item["id"], "iconPixels": len(ink), "extent": extent})

    # A stray toolbar edge or shadow between delegates is also a failure.
    unexpected = sum(different(pixel(x, y), background) for x, y in points(pixel_bounds(report["rect"]))
                     if (x, y) not in allowed)
    require(unexpected == 0, f"{unexpected} toolbar/background pixels outside the panel icons and labels")
    return evidence


def validate(report, view, theme="dark"):
    require(report["time"] == EPOCH_MS, "Wall clock is not frozen")
    require(report["scale"] == 2, "Expected native 2x rendering")
    require(report["font"] == "Noto Sans" and report["pointSize"] == 10,
            f"Unexpected font: {report['font']} {report['pointSize']}")
    color = report["background"].lstrip("#")[-6:]
    channels = [int(color[i:i + 2], 16) for i in (0, 2, 4)]
    require(theme in ("light", "dark"), "Unknown theme")
    require(min(channels) > 200 if theme == "light" else max(channels) < 100,
            f"Expected Breeze {theme}")
    setup = view == "cli-setup-light"
    if setup or "cliState" in report:
        require(report["cliState"] == ("missing" if setup else "available"), "Unexpected CLI state")
        require(not report["installRunning"] and report["installExitCode"] == -1, "Installer must never run")
    require(report["configMode"] == (not setup), "Unexpected CLI config mode")
    if "providers" in report:
        require(set(report["providers"]) == ({"codex"} if setup else PROVIDERS), "Wrong enabled providers")
    if "data" in report and not setup:
        require(all(d["ready"] for d in report["data"]), "Usage still loading or failed")

    text = "\n".join(report["texts"])
    require(not EMAIL.search(text) and "Account:" not in text, "Account identities must not appear")

    # During navigation the unfiltered provider list may legitimately scroll.
    if view == "navigation":
        return
    require(not report["clipped"], f"Clipped or elided text: {report['clipped']}")
    require(not report.get("overflow"), "Popup needs scrolling")
    require(not any(s in text.lower() for s in
                    ["refreshing", "loading", "no data", "could not", "/home/", "/tmp/", "error:"]),
            "Loading, error or private path text in capture")
    expected = []
    if view in ("overview", "overview-light"):
        require(report["tab"] == "overview", "Overview tab is not selected")
        expected = ["Codex", "Claude", "Antigravity", "72% left", "58% left", "81% left", "About CodexBar"]
    elif view == "provider-codex":
        require(report["tab"] == "codex", "Codex tab is not selected")
        require(any(d["id"] == "codex" and d["costReady"] for d in report["data"]), "Cost not loaded")
        expected = ["Session", "Weekly", "Codex Spark", "Resets in 3h 50m", "Resets in 4d 2h",
                    "Pace: 6% in reserve", "Today: $ 2.84", "Last 30 days: $ 47.62", "All Systems Operational",
                    "Pro", "About CodexBar"]
    elif setup:
        require(report["kind"] == "setup", "Setup card is not visible")
        require(report["buttons"].get("Install CodexBar CLI") is True, "Installer button must be enabled")
        expected = ["CodexBar CLI required", "CLI not found.", "Install CodexBar CLI",
                    "Open installation guide", "Open CodexBar CLI documentation", "Retry"]
    elif view.startswith("meters-"):
        icons = ["__merged__"] if view == "meters-merged" else ["codex", "claude", "antigravity"]
        require(report["icons"] == icons and report["mode"] == "meters", "Wrong meter layout")
        require(report["percentVisible"] == (view != "meters-merged"), "Wrong percentage setting")
        expected = [] if view == "meters-merged" else ["72%", "58%", "81%"]
    elif view == "logos-horizontal":
        require(report["mode"] == "logos" and set(report["icons"]) == PROVIDERS, "Wrong logo layout")
        require(not report["vertical"], "Wrong panel orientation")
        expected = ["72%", "58%", "81%", "3h 50m", "2h 10m", "1h"]
    elif view == "settings-general":
        require(report["kind"] == "general", "General page did not open")
        require(report["paths"] == ["", "", ""], "Settings must use neutral path placeholders")
        require(report["notifications"] == [False, False, 10], "Notifications must show their default settings")
        expected = ["Refresh interval:", "Panel display:", "Usage bars fill:", "codexbar CLI path:",
                    "Adapter executable path:", "Notifications:", "When a quota runs low or resets",
                    "Low below", "% left", "When a provider's status changes"]
    elif view == "settings-providers":
        require(report["kind"] == "providers" and report["enabledOnly"], "Enabled filter is not selected")
        expected = ["config.json", "Show enabled only", "Codex", "Claude", "Antigravity", "Config: OAuth"]
    else:
        raise ValueError(f"Unknown view: {view}")
    if report["kind"] == "panel":
        panel_geometry(report)
    for value in expected:
        require(value in text, f"Missing visible text: {value}")


def geometry(report):
    r = report["rect"]
    x, y = math.floor(r["x"] * 2), math.floor(r["y"] * 2)
    w = math.ceil((r["x"] + r["width"]) * 2) - x
    h = math.ceil((r["y"] + r["height"]) * 2) - y
    require(x >= 0 and y >= 0 and w > 0 and h > 0, "Invalid capture rectangle")
    require(x + w <= report["window"]["width"] * 2 + 1
            and y + h <= report["window"]["height"] * 2 + 1, "Capture extends outside window")
    return f"{w}x{h}+{x}+{y}"


def main():
    command, *args = sys.argv[1:]
    if command == "inject":
        inject(*args)
    elif command == "state":
        log, kind, view, theme = args
        report = state(log, kind)
        validate(report, view, theme)
        print(json.dumps(report, indent=2))
    elif command == "crop":
        print(geometry(json.loads(Path(args[0]).read_text())))
    elif command == "window":
        window = json.loads(Path(args[0]).read_text())["window"]
        print(round(window["width"] * 2), round(window["height"] * 2))
    elif command == "click":
        report = json.loads(Path(args[0]).read_text())
        point = report["actions"].get(args[1])
        require(point is not None, f"No visible click target: {args[1]}")
        print(*(round(v * 2) for v in point))
    elif command == "limit":
        print(*LIMITS[args[0]])
    elif command == "errors":
        errors = qml_errors(Path(args[0]).read_text(), args[1])
        require(not errors, "\n".join(errors))
    elif command == "panel-pixels":
        report = json.loads(Path(args[0]).read_text())
        pixels = subprocess.run(["magick", args[1], "-alpha", "off", "-depth", "8", "rgb:-"],
                                check=True, stdout=subprocess.PIPE).stdout
        print(json.dumps(panel_pixels(report, pixels), indent=2))
    else:
        raise ValueError(f"Unknown command: {command}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
