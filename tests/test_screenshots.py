import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("capture", REPO / "tests/screenshots/capture.py")
capture = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(capture)


class ScreenshotChecks(unittest.TestCase):
    def setUp(self):
        self.report = {
            "kind": "popup", "time": capture.EPOCH_MS, "scale": 2,
            "font": "Noto Sans", "pointSize": 10, "background": "#232629",
            "configMode": True, "providers": ["codex", "claude", "antigravity"],
            "cliState": "available", "installRunning": False, "installExitCode": -1,
            "data": [{"id": p, "ready": True, "costReady": False} for p in capture.PROVIDERS],
            "tab": "overview", "clipped": [], "overflow": False,
            "texts": ["Codex", "Claude", "Antigravity", "72% left", "58% left", "81% left", "About CodexBar"],
            "rect": {"x": 12, "y": 12, "width": 392, "height": 350},
            "window": {"width": 416, "height": 820},
        }

    def test_missed_click_cannot_pass_as_provider_page(self):
        capture.validate(self.report, "overview")
        with self.assertRaisesRegex(ValueError, "Codex tab is not selected"):
            capture.validate(self.report, "provider-codex")

    def test_incomplete_or_clipped_views_fail(self):
        for key, value in [("time", 0), ("scale", 1), ("configMode", False),
                           ("background", "#ffffff"), ("clipped", ["Account"]),
                           ("overflow", True), ("texts", ["Refreshing…"]),
                           ("data", [{"ready": False}])]:
            with self.subTest(key=key):
                report = copy.deepcopy(self.report)
                report[key] = value
                with self.assertRaises(ValueError):
                    capture.validate(report, "overview")

    def test_provider_page_requires_cost_result(self):
        self.report["tab"] = "codex"
        with self.assertRaisesRegex(ValueError, "Cost not loaded"):
            capture.validate(self.report, "provider-codex")

    def test_crop_is_native_scale_and_stays_inside_window(self):
        self.assertEqual(capture.geometry(self.report), "784x700+24+24")
        self.report["rect"]["x"] = 100
        with self.assertRaisesRegex(ValueError, "outside window"):
            capture.geometry(self.report)

    def test_light_view_must_actually_use_a_light_palette(self):
        with self.assertRaisesRegex(ValueError, "Expected Breeze light"):
            capture.validate(self.report, "overview-light", "light")
        self.report["background"] = "#eff0f1"
        capture.validate(self.report, "overview-light", "light")

    def test_even_fictional_email_addresses_are_rejected(self):
        self.report["texts"].append("Account: demo@example.invalid")
        for view in ("overview", "navigation"):
            with self.assertRaisesRegex(ValueError, "Account identities"):
                capture.validate(self.report, view)

    def test_setup_requires_missing_cli_and_usable_install_button(self):
        self.report.update({
            "kind": "setup", "background": "#eff0f1", "cliState": "missing",
            "configMode": False, "providers": ["codex"], "data": [],
            "texts": ["CodexBar CLI required", "CLI not found.", "Install CodexBar CLI",
                      "Open installation guide", "Open CodexBar CLI documentation", "Retry"],
            "buttons": {"Install CodexBar CLI": True},
        })
        capture.validate(self.report, "cli-setup-light", "light")
        for changes in ({"cliState": "available"}, {"installRunning": True},
                        {"installExitCode": 0}, {"buttons": {"Install CodexBar CLI": False}}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                capture.validate({**self.report, **changes}, "cli-setup-light", "light")

    def test_panel_cannot_be_captured_at_enlarged_desktop_size(self):
        self.report.update({"kind": "panel", "icons": ["__merged__"], "mode": "meters",
                            "percentVisible": False, "texts": [], "panelHeight": 44, "iconSide": 32})
        capture.validate(self.report, "meters-merged")
        self.report["panelHeight"] = 64
        with self.assertRaisesRegex(ValueError, "normal 44px"):
            capture.validate(self.report, "meters-merged")

    def test_system_qml_warnings_do_not_hide_widget_errors(self):
        system = "\n".join([
            "file:///usr/share/plasma/shells/org.kde.plasma.plasmoidviewershell/contents/configuration/ConfigCategoryDelegate.qml:53:13: Unable to assign [undefined] to bool",
            "file:///usr/lib/qt6/qml/org/kde/kirigami/controls/private/globaltoolbar/BreadcrumbControl.qml:29:9: Unable to assign [undefined] to OverlayDrawer_QMLTYPE_262*",
            "file:///usr/lib/qt6/qml/org/kde/kirigami/controls/private/globaltoolbar/NavigationButtons.qml:39: TypeError: Cannot read property 'KL' of null",
        ])
        self.assertEqual(capture.qml_errors(system), [])
        for error in ("file:///tmp/pkg/contents/ui/FullView.qml:42: TypeError: Cannot read property 'x' of null",
                      "file:///tmp/pkg/contents/ui/ScreenshotProbe.qml:1: ReferenceError: root is not defined",
                      "Applet does not exist", "Containment doesn't exist"):
            with self.subTest(error=error):
                self.assertEqual(capture.qml_errors(system + "\n" + error), [error])

    def test_observer_changes_only_disposable_copies(self):
        names = ["CompactBar.qml", "FullView.qml", "CliSetupCard.qml", "configGeneral.qml", "configProviders.qml"]
        originals = {name: (REPO / "contents/ui" / name).read_text() for name in names}
        with tempfile.TemporaryDirectory() as directory:
            ui = Path(directory) / "contents/ui"
            ui.mkdir(parents=True)
            for name in names:
                shutil.copyfile(REPO / "contents/ui" / name, ui / name)
            capture.inject(directory)
            for name in names:
                self.assertEqual((ui / name).read_text().count("screenshotProbe:"), 1)
                self.assertEqual((REPO / "contents/ui" / name).read_text(), originals[name])
            with self.assertRaisesRegex(ValueError, "Observer anchor changed"):
                (ui / "FullView.qml").write_text("import QtQuick\nItem {}\n")
                capture.inject(directory)


class ScreenshotMock(unittest.TestCase):
    def mock(self, fixtures, *args):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(
                [str(REPO / "tests/smoke/codexbar"), *args], check=True,
                text=True, capture_output=True,
                env={**os.environ, "CODEXBAR_FIXTURES": str(fixtures),
                     "CODEXBAR_MOCK_STATE": str(Path(directory) / "config")},
            )
            return json.loads(result.stdout)

    def test_original_smoke_cost_behavior_is_unchanged(self):
        self.assertEqual(self.mock(REPO / "tests/smoke/fixtures", "cost", "--provider", "codex", "--json"), [])

    def test_screenshot_cost_has_today_and_thirty_day_totals(self):
        rows = self.mock(REPO / "tests/screenshots/fixtures", "cost", "--provider", "codex", "--json")
        self.assertEqual(rows[0]["daily"][0]["totalCost"], 2.84)
        self.assertRegex(rows[0]["daily"][0]["date"], r"^\d{4}-\d{2}-\d{2}$")
        self.assertEqual(rows[0]["last30DaysCostUSD"], 47.62)

    def test_usage_fixtures_resolve_timestamps_without_account_identities(self):
        for provider in capture.PROVIDERS:
            with self.subTest(provider=provider):
                rows = self.mock(REPO / "tests/screenshots/fixtures", "usage", "--provider", provider, "--json")
                self.assertEqual(rows[0]["provider"], provider)
                self.assertNotIn("@IN_", json.dumps(rows))
                usage = rows[0]["usage"]
                self.assertNotEqual(usage["updatedAt"], "@NOW@")
                self.assertEqual(rows[0]["status"]["indicator"], "none")
                self.assertNotIn("accountEmail", usage.get("identity", {}))
                self.assertIsNone(capture.EMAIL.search(json.dumps(rows)))


class ScreenshotScenes(unittest.TestCase):
    def test_failed_scene_stops_its_work_but_later_scenes_still_run(self):
        result = subprocess.run(
            ["bash", "-c", '''
set -euo pipefail
source "$1/tests/screenshots/scenes.sh"
unset DISPLAY
viewer_pid=""
bad() { false; echo MUST_NOT_RUN; }
good() { echo NEXT_SCENE_RAN; }
run_scene bad
run_scene good
[[ "$scene_failures" == 1 ]]
''', "scene-test", str(REPO)], text=True, capture_output=True, check=True,
        )
        self.assertNotIn("MUST_NOT_RUN", result.stdout)
        self.assertIn("NEXT_SCENE_RAN", result.stdout)
        self.assertIn("bad failed", result.stderr)


if __name__ == "__main__":
    unittest.main()
