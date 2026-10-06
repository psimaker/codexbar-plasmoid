# Screenshot candidates

Use one Breeze Dark set, with Noto Sans 10 pt (8 pt secondary text), native
`QT_SCALE_FACTOR=2`, UTC and a frozen clock at 2026-10-06 12:00. Dark neutral
surfaces keep the provider colors clear on either GitHub background without
doubling the review set. No wallpaper, other applets, window decorations or
cursor. Every canvas has at least 16 logical pixels of clear space; images
are cropped from native renders and padded, never enlarged.

All usage, costs, status and identities are fictional. Codex and Claude use
`alex@example.com`. The settings fields retain their neutral built-in
placeholders. The usage bars show remaining quota throughout.

| Candidate | Pixels (2×) | Demonstrates / replaces |
|---|---:|---|
| `overview.png` | 896 × 896 | Codex, Claude and Antigravity with session/weekly bars in their brand colors. Replaces the hero `codexbar-plasma.png`. |
| `provider-codex.png` | 896 × 1536 | Session, weekly and Codex Spark windows, reset countdowns, computed pace, today/30-day cost, operational status and neutral identity. Adds the detail promised by the Features text. |
| `panel-meters.png` | 960 × 352 | Two actual panel captures: one merged meter and separate meters, including the Codex/Claude critters. Captions sit outside the captures. Adds the two default meter layouts. |
| `panel-logos-horizontal.png` | 1152 × 128 | Logos, remaining percentages and reset countdowns. Replaces `provider-logos-horizontal.png`. |
| `panel-logos-vertical.png` | 256 × 320 | The same data in a narrow panel with stacked countdowns. Replaces `provider-logos-vertical.png`. |
| `settings-general.png` | 1920 × 2944 | The complete current General page, including actions, cost and CLI controls. Replaces `panel-display-mode-settings.png`; the taller canvas avoids clipping the expanded settings. |
| `settings-providers.png` | 1920 × 1152 | The actual Providers page reading the mock CLI's config.json, with Show enabled only selected, configured sources and override buttons. Adds the shared-config behavior. |

The popup shots capture the widget's real FullView inside plasmoidviewer.
Panels use Plasma's panel containment; settings use Plasma's configuration
window. There is no recreated UI. `Probe.qml` is an observer added to disposable
package copies only: it reports loaded data, visible text, click targets and
capture bounds. It neither draws nor changes widget state. Navigation uses
real X11 clicks. The original checkout's QML is unchanged.

## Render and review

Run **Documentation screenshots** (`.github/workflows/screenshots.yml`) on a
pull request or with `workflow_dispatch`. It uses the same Arch/Plasma packages
as the smoke job, plus explicit KDE Qt integration, Python and libfaketime.
On an Arch machine with those dependencies, from the checkout:

```sh
dbus-run-session -- bash tests/screenshots/render.sh "$PWD/dist/screenshots"
```

The output directory must be empty. The script starts its own Xvfb and isolates
the viewer's home, config, environment and CLI path. Only `tests/smoke/codexbar`
supplies data. Its provider-list and config helpers are reused; screenshot
usage/cost fixtures live in `tests/screenshots/fixtures/`. Without cost fixtures,
the mock still returns `[]`, as the existing smoke scenarios expect.

Readiness checks assert the clock, theme, scale, font, config mode, providers,
selected page, percentages, countdowns and cost. Clipped/elided text, scroll
overflow, loading/error text, unchanged clicks, unstable pixels and QML errors
fail the job. Three successive equal frames precede each capture. Captures
that exceed a planned canvas fail instead of being shrunk or cut off. The
workflow uploads diagnostics even when it fails.

The artifact is `codexbar-screenshots-<commit SHA>`. Send back these files for
visual review (or simply the whole artifact):

- All seven `images/*.png` named in the table.
- `contact-sheet.png` (a reduced review aid, not a publication image).
- `manifest.txt` and `diagnostics/` (state JSON, raw windows/content, logs and
  installed package versions; on failure, the screen and window tree too).

Successful assertions do not replace visual review. No candidates can be
rendered in the development workspace, so the README references are staged
for the CI images. After reviewing the downloaded candidates, copy the seven
files from `images/` into this directory before merging. The unresized PNGs
can also be offered for KDE Store review. Arch is rolling: the clock, fixtures
and presentation are fixed, while exact pixels across dependency upgrades are
not guaranteed; the artifact records the installed versions.

After the maintainer approves the replacements, remove **only** these obsolete
files (kept in the working tree until then): `codexbar-plasma.png`,
`panel-display-mode-settings.png`, `provider-logos-horizontal.png`, and
`provider-logos-vertical.png`.
