#!/usr/bin/env python3
"""Install the observer and validate its reports; never create widget pixels."""

import json
import math
from pathlib import Path
import shutil
import sys

PROVIDERS = {"codex", "claude", "antigravity"}
EPOCH_MS = 1791288000000  # 2026-10-06 12:00:00 UTC
SIZES = {
    "overview": (896, 896),
    "provider-codex": (896, 1536),
    "panel-meters": (960, 352),
    "panel-logos-horizontal": (1152, 128),
    "panel-logos-vertical": (256, 320),
    "settings-general": (1920, 2944),
    "settings-providers": (1920, 1152),
}


def inject(package):
    ui = Path(package) / "contents/ui"
    shutil.copyfile(Path(__file__).with_name("Probe.qml"), ui / "ScreenshotProbe.qml")
    for name, anchor, fields in [
        ("CompactBar.qml", "id: compactRoot", 'target: compactRoot; subject: grid; kind: "panel"'),
        ("FullView.qml", "id: fullRoot", 'target: fullRoot; subject: mainColumn; viewport: flick; kind: "popup"'),
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


def validate(report, view):
    require(report["time"] == EPOCH_MS, "Wall clock is not frozen")
    require(report["scale"] == 2, "Expected native 2x rendering")
    require(report["font"] == "Noto Sans" and report["pointSize"] == 10,
            f"Unexpected font: {report['font']} {report['pointSize']}")
    color = report["background"].lstrip("#")[-6:]
    require(max(int(color[i:i + 2], 16) for i in (0, 2, 4)) < 100, "Expected Breeze Dark")
    require(report["configMode"], "Widget is not reading the mock config.json")
    if "providers" in report:
        require(set(report["providers"]) == PROVIDERS, "Wrong enabled providers")
    if "data" in report:
        require(all(d["ready"] for d in report["data"]), "Usage still loading or failed")

    # During navigation the unfiltered provider list may legitimately scroll.
    if view == "navigation":
        return
    require(not report["clipped"], f"Clipped or elided text: {report['clipped']}")
    require(not report.get("overflow"), "Popup needs scrolling")
    text = "\n".join(report["texts"])
    require(not any(s in text.lower() for s in
                    ["refreshing", "loading", "no data", "could not", "/home/", "/tmp/", "error:"]),
            "Loading, error or private path text in capture")
    expected = []
    if view == "overview":
        require(report["tab"] == "overview", "Overview tab is not selected")
        expected = ["Codex", "Claude", "Antigravity", "72% left", "58% left", "81% left", "About CodexBar"]
    elif view == "provider-codex":
        require(report["tab"] == "codex", "Codex tab is not selected")
        require(any(d["id"] == "codex" and d["costReady"] for d in report["data"]), "Cost not loaded")
        expected = ["Session", "Weekly", "Codex Spark", "Resets in 3h 50m", "Resets in 4d 2h",
                    "Pace: 6% in reserve", "Today: $ 2.84", "Last 30 days: $ 47.62", "All Systems Operational",
                    "Account: alex@example.com", "About CodexBar"]
    elif view.startswith("meters-"):
        icons = ["__merged__"] if view == "meters-merged" else ["codex", "claude", "antigravity"]
        require(report["icons"] == icons and report["mode"] == "meters", "Wrong meter layout")
        expected = ["58%"] if view == "meters-merged" else ["72%", "58%", "81%"]
    elif view.startswith("panel-logos-"):
        require(report["mode"] == "logos" and set(report["icons"]) == PROVIDERS, "Wrong logo layout")
        require(report["vertical"] == view.endswith("vertical"), "Wrong panel orientation")
        expected = ["72%", "58%", "81%", "3h 50m", "2h 10m", "1h"]
    elif view == "settings-general":
        require(report["kind"] == "general", "General page did not open")
        require(report["paths"] == ["", "", ""], "Settings must use neutral path placeholders")
        expected = ["Refresh interval:", "Panel display:", "Usage bars fill:", "codexbar CLI path:",
                    "Adapter executable path:"]
    elif view == "settings-providers":
        require(report["kind"] == "providers" and report["enabledOnly"], "Enabled filter is not selected")
        expected = ["config.json", "Show enabled only", "Codex", "Claude", "Antigravity", "Config: OAuth"]
    else:
        raise ValueError(f"Unknown view: {view}")
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
        log, kind, view = args
        report = state(log, kind)
        validate(report, view)
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
    elif command == "size":
        print(*SIZES[args[0]])
    else:
        raise ValueError(f"Unknown command: {command}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
