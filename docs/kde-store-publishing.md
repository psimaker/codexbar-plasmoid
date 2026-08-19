# KDE Store publishing checklist

This document prepares a manual KDE Store publication. It does not imply that
CodexBar is already available in the store. Account sign-in, product creation,
upload, and publication must be performed by the maintainer.

## Listing data

- Category: **Plasma 6 Extensions → Plasma 6 Applets**
- Product title: **CodexBar for KDE Plasma 6**
- Plugin ID: `com.github.psimaker.codexbar`
- License: **MIT**
- Source URL: <https://github.com/psimaker/codexbar-plasmoid>
- Issues: <https://github.com/psimaker/codexbar-plasmoid/issues>
- Minimum desktop version: **KDE Plasma 6.0**
- External dependency: **CodexBar CLI 0.43.0 or newer**
- Recommended tags: `kde`, `plasma`, `plasma6`, `plasmoid`, `kde-widget`,
  `panel`, `codexbar`, `usage`, `monitoring`

## Screenshots

Prepare current screenshots from an unmodified Plasma 6 theme at readable
desktop scale. Do not include credentials, email addresses, API keys, provider
tokens, or unrelated desktop notifications.

- Panel view showing the CodexBar icon at normal panel size.
- Popup overview with at least two providers and representative usage bars.
- Provider detail page with session and weekly limits.
- CLI setup card shown with the CLI intentionally unavailable.
- General settings page showing the custom CLI path field.
- At least one dark-theme and one light-theme view.

Existing images under `docs/screenshots/` may be reused only after confirming
that they still match the release being submitted.

## Build and verify the upload file

- [ ] Check out the exact release commit or tag and confirm a clean worktree.
- [ ] Confirm that `metadata.json` contains the intended release version,
      `com.github.psimaker.codexbar`, and `Plasma/Applet`.
- [ ] Build the exact ref:

      ```bash
      scripts/build-plasmoid.sh v<version>
      ```

- [ ] Use `dist/com.github.psimaker.codexbar-<version>.plasmoid` as the KDE
      Store upload. Do not upload a source archive or embed the CodexBar CLI.
- [ ] Verify archive integrity and its checksum:

      ```bash
      unzip -t dist/com.github.psimaker.codexbar-<version>.plasmoid
      (cd dist && sha256sum -c com.github.psimaker.codexbar-<version>.plasmoid.sha256)
      ```

- [ ] Inspect the archive root. It must contain only `metadata.json`,
      `contents/`, and `LICENSE`, with `contents/ui/main.qml` present.

## Installation and upgrade acceptance

- [ ] Install the package locally before upload:

      ```bash
      kpackagetool6 -t Plasma/Applet -i dist/com.github.psimaker.codexbar-<version>.plasmoid
      ```

- [ ] Add the widget to a panel, open the popup, and verify each enabled
      provider with a compatible CLI.
- [ ] Temporarily configure a nonexistent CLI path and verify the setup card,
      both documentation links, the configuration hint, and **Retry**.
- [ ] Upgrade an installation of the preceding released package:

      ```bash
      kpackagetool6 -t Plasma/Applet -u dist/com.github.psimaker.codexbar-<version>.plasmoid
      ```

- [ ] Confirm that widget configuration survives the upgrade.
- [ ] Test the graphical **Install Widget From Local File…** path.
- [ ] Repeat installation and first-run testing with a fresh user profile.
- [ ] Test keyboard navigation and both dark and light themes.
- [ ] Remove the test installation when acceptance is complete:

      ```bash
      kpackagetool6 -t Plasma/Applet -r com.github.psimaker.codexbar
      ```

Do not run these install, upgrade, or removal commands against a production
desktop profile when an isolated Plasma 6 test profile is available.

## Publication and post-publication checks

- [ ] Create or update the product manually with the listing data above.
- [ ] Paste the reviewed copy below and upload the approved screenshots.
- [ ] Upload the verified `.plasmoid` file only after all acceptance checks
      pass.
- [ ] After moderation or publication, search **Get New Widgets** for
      **CodexBar** from a fresh Plasma 6 profile.
- [ ] Confirm that installation from **Get New Widgets** installs the expected
      plugin ID and version.
- [ ] Confirm that the dependency notice is visible before users encounter a
      missing-CLI state.
- [ ] Only after the listing is live and verified, add its real URL to the
      normal README installation instructions.

## Copy-ready store text

### Short description

> Monitor AI coding-provider usage limits from a KDE Plasma 6 panel widget.

### Full product description

> CodexBar for KDE Plasma 6 keeps AI coding-provider usage limits visible in
> your panel. Its compact representation can show merged or per-provider quota
> meters, provider logos, and an optional percentage. The popup provides an
> overview plus detailed session, weekly, and additional rate-limit windows,
> reset timing, optional local cost information, provider status, and account
> details.
>
> The widget uses the separate CodexBar command-line interface to read provider
> usage. It supports configurable providers, refresh intervals, panel display
> modes, a custom CLI path, and an optional schema-v1 Claude multi-account
> adapter. Theme colors are used throughout for Plasma light and dark themes.
>
> CodexBar for KDE Plasma 6 is an independent community port. The widget does
> not contain provider credentials and does not install external software.

### Installation note

> Install the widget through KDE's Get New Widgets interface. After
> installation, add “CodexBar” to a panel. For local package testing, use
> Plasma's “Install Widget From Local File…” action with the release
> `.plasmoid` file.

### Dependency note

> Requires the external CodexBar CLI version 0.43.0 or newer. The CLI is not
> included in the widget. Install it separately, sign in to the provider tools
> you use, and ensure `codexbar` is on `PATH` or configure its executable path
> in the widget settings. CLI instructions:
> https://github.com/steipete/CodexBar/blob/main/docs/cli.md

### Changelog template

> Version `<version>`
>
> - Added: `<user-visible addition>`
> - Changed: `<user-visible change>`
> - Fixed: `<user-visible fix>`
> - Requires CodexBar CLI 0.43.0 or newer.

Remove empty lines from the changelog template rather than publishing literal
placeholders.

### Support and issue note

> Report reproducible widget issues at
> https://github.com/psimaker/codexbar-plasmoid/issues. For CodexBar CLI
> behavior, first check the upstream CLI documentation and identify whether the
> problem can be reproduced by running the CLI directly.

## Updating later store versions

1. Prepare the release version in a separate release change and validate that
   the metadata version matches the Git tag.
2. Build from the exact tag and verify the `.plasmoid` plus SHA-256 checksum.
3. Repeat local install, previous-version upgrade, fresh-profile, theme,
   keyboard, missing-CLI, and provider-data tests.
4. Update screenshots and descriptions when visible behavior changes.
5. Add concise user-facing release notes using the changelog template.
6. Upload the new `.plasmoid` manually without replacing or deleting the
   previous local artifact until the store update is confirmed.
7. After publication, verify the displayed version, fresh installation, and
   upgrade path through **Get New Widgets**.
