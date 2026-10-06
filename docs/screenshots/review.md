# Review of the first rendered candidates

These observations refer to the four PNGs from commit `f6fcf62`. None is a
publication approval. Native pixels are crisp and no text appears clipped or
half-loaded, but the framing and README scale need correction.

| Render | Assessment | Revision |
|---|---|---|
| Overview | The 680 × 752 px content is centered on 896 × 896, leaving 108 px on each side and 72 px above/below. The near-black rectangle reads as an accidental seam. Provider names, percentage columns and bars align well. At the old 448 px README width, labels are readable; three brands give enough variety without crowding the tab strip. | Match the padding to the rendered background and use 32 px on all sides: 744 × 816. Display at 372 px wide to preserve the same native text scale. Add a matched light variant for GitHub and the Store. |
| Codex detail | Content is 680 × 1266 px inside 896 × 1536: 108 px sides versus 135 px top/bottom. The email disqualifies it for the Store. Session/weekly/Spark labels, percentages and countdowns align; the quieter pace/status lines remain readable at half scale. The many native action rows add substantial length and compete with the usage information in a main README gallery. | Remove the email field from fixtures while retaining the Pro plan. Fit the entire native content with equal 32 px padding. Keep all actions intact; move this shot to the dedicated gallery and Store set. |
| General settings | No clipping, but roughly a third of the height is vacant between the adapter description and footer. The image is too tall for a feature overview. At the old 600 px README width, ordinary labels become approximately 8 px and help text smaller still. Colorful native sidebar icons are visually louder than the form, although correct for Plasma. The CLI path field is present and contains a safe placeholder. | Resize the real window from 928 × 1440 to 928 × 960 logical pixels before capture. Preserve the footer and every field; retain clipping checks. Use the full-size gallery/Store image instead of a tiny README thumbnail. Keep stock Plasma styling. |
| Providers settings | Three checked rows and the current config-source labels are correct. The introductory text is dense, and about 450 physical pixels separate the last row from the footer. At 600 px wide, both source labels and explanatory text become too small. The enabled-only filter usefully explains why only three providers appear; populating more rows merely to fill space would dilute this example. | Keep the filter and resize the real window from 928 × 544 to 928 × 368 logical pixels. Preserve the sidebar and footer, retain current-release source wording, and show this only in the gallery/Store set. |

The data needs no numerical retouching. Remaining quotas vary plausibly across
providers; reset times stay within their session or weekly windows. Codex's
weekly 36% used, with 4d 2h remaining, yields the displayed 6% reserve. Spark's
lighter use is distinct from the main session. Today's cost/tokens are below
the 30-day totals, and the blended amounts are reasonable fictional examples.
Operational status and a Pro plan provide context without an account identity.

The panel candidates were never reached, so their appearance is still
unreviewed. The next run uses a normal 44 px panel instead of the original
64 px capture window and combines three modes in one comparison. Review its
icon scale, critter detail, caption spacing and countdown legibility at the
README's display width. Also inspect light-theme icon contrast, all setup-card
buttons, the shortened settings footers and the absence of email/account lines.
