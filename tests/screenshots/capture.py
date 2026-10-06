#!/usr/bin/env python3
"""Install the observer and validate its reports; never create widget pixels."""

import json
import math
from pathlib import Path
import re
import shutil
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
    "settings-general": (1856, 1920),
    "settings-providers": (1856, 736),
}
# Same failure boundary as tests/smoke/run.sh. Distribution QML warnings
# remain in the artifact but cannot prevent the later panel shots from running.
QML_ERRORS = re.compile(
    r"contents/ui/.*(Error|Unable to assign|is not a function|Cannot read property|is not defined)"
    r"|does not exist|Containment doesn.t exist"
)
EMAIL = re.compile(r"[\w.+-]+@[\w.-]+\.[a-zA-Z]{2,}")


def inject(package):
    ui = Path(package) / "contents/ui"
    shutil.copyfile(Path(__file__).with_name("Probe.qml"), ui / "ScreenshotProbe.qml")
    for name, anchor, fields in [
        ("CompactBar.qml", "id: compactRoot", 'target: compactRoot; subject: grid; kind: "panel"'),
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


def qml_errors(log):
    return [line for line in log.splitlines() if QML_ERRORS.search(line)]


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
        expected = ["Refresh interval:", "Panel display:", "Usage bars fill:", "codexbar CLI path:",
                    "Adapter executable path:"]
    elif view == "settings-providers":
        require(report["kind"] == "providers" and report["enabledOnly"], "Enabled filter is not selected")
        expected = ["config.json", "Show enabled only", "Codex", "Claude", "Antigravity", "Config: OAuth"]
    else:
        raise ValueError(f"Unknown view: {view}")
    if report["kind"] == "panel":
        require(report["panelHeight"] == 44 and 24 <= report["iconSide"] <= 32,
                "Panel must retain its normal 44px thickness and native icon size")
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
        errors = qml_errors(Path(args[0]).read_text())
        require(not errors, "\n".join(errors))
    else:
        raise ValueError(f"Unknown command: {command}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
