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

    def test_observer_changes_only_disposable_copies(self):
        names = ["CompactBar.qml", "FullView.qml", "configGeneral.qml", "configProviders.qml"]
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

    def test_usage_fixtures_resolve_timestamps_and_neutral_identities(self):
        for provider in capture.PROVIDERS:
            with self.subTest(provider=provider):
                rows = self.mock(REPO / "tests/screenshots/fixtures", "usage", "--provider", provider, "--json")
                self.assertEqual(rows[0]["provider"], provider)
                self.assertNotIn("@IN_", json.dumps(rows))
                usage = rows[0]["usage"]
                self.assertNotEqual(usage["updatedAt"], "@NOW@")
                self.assertEqual(rows[0]["status"]["indicator"], "none")
                if "identity" in usage:
                    self.assertEqual(usage["identity"]["accountEmail"], "alex@example.com")


if __name__ == "__main__":
    unittest.main()
