#!/usr/bin/env node

const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const source = fs.readFileSync(
    path.join(__dirname, "..", "contents", "ui", "code", "catalog.js"),
    "utf8"
).replace(/^\.pragma library$/m, "")
const catalog = {}
vm.createContext(catalog)
vm.runInContext(source, catalog, { filename: "catalog.js" })

// An unknown --provider makes the CLI report the providers enabled in its
// own config; only the requested provider's entries may be shown.
const fallbackReport = [
    { provider: "codex", source: "auto", usage: { primary: { usedPercent: 12 } } },
    { provider: "claude", source: "auto", usage: { primary: { usedPercent: 34 } } },
]
const providersOf = (entries) => Array.from(entries, (entry) => entry.provider)
assert.equal(catalog.entriesForProvider(fallbackReport, "hyper").length, 0)
assert.deepEqual(providersOf(catalog.entriesForProvider(fallbackReport, "claude")), ["claude"])
// the report uses CodexBar's internal id for a few --provider names
assert.equal(catalog.reportedProviderId("groqcloud"), "groq")
assert.equal(catalog.reportedProviderId("codex"), "codex")
assert.deepEqual(providersOf(catalog.entriesForProvider(
    [{ provider: "abacus", usage: {} }], "abacusai")), ["abacus"])
for (const id of Object.keys(catalog.REPORTED_PROVIDER_IDS)) {
    assert.ok(catalog.PROVIDERS[id] !== undefined, id)
    assert.equal(catalog.cliProviderId(catalog.reportedProviderId(id)), id)
}
assert.equal(catalog.cliProviderId("myplugin"), "myplugin")
// providers the catalog does not know take the name config.json gives them
assert.equal(catalog.meta("myplugin").name, "myplugin")
catalog.registerName("myplugin", "My Plugin")
catalog.registerName("codex", "Not Codex")
assert.equal(catalog.meta("myplugin").name, "My Plugin")
assert.equal(catalog.meta("codex").name, "Codex")
// entries without a provider field (older CLI output) are kept; junk is not
assert.equal(catalog.entriesForProvider([{ usage: {} }], "codex").length, 1)
assert.equal(catalog.entriesForProvider([null, 3, "x"], "codex").length, 0)
assert.equal(catalog.entriesForProvider({ provider: "codex" }, "codex").length, 0)
assert.equal(catalog.entriesForProvider(null, "codex").length, 0)

// The CLI's own error messages, as CodexBar 0.70 prints them with exit 1.
const decodeError = "Failed to decode CodexBar config: The operation could not be completed. The data isn’t in the correct format."
const cliEnvelope = [{ source: "cli", provider: "cli", error: { message: decodeError, code: 1, kind: "config" } }]
assert.equal(catalog.errorForProvider(cliEnvelope, "claude"), decodeError)
assert.equal(catalog.entriesForProvider(cliEnvelope, "claude").length, 0)
const geminiError = [{ source: "auto", provider: "gemini",
    error: { code: 1, message: "Not logged in to Gemini. Run 'gemini' in Terminal to authenticate.", kind: "provider" } }]
assert.equal(catalog.errorForProvider(geminiError, "gemini"),
    "Not logged in to Gemini. Run 'gemini' in Terminal to authenticate.")
// another provider's error is not this one's; internal ids still match
assert.equal(catalog.errorForProvider(geminiError, "claude"), "")
assert.equal(catalog.errorForProvider([{ provider: "groq", error: { message: "No API key." } }], "groqcloud"),
    "No API key.")
// usage data, empty or malformed messages and other output are no error
assert.equal(catalog.errorForProvider(fallbackReport, "claude"), "")
assert.equal(catalog.errorForProvider([{ provider: "claude", error: { message: "  " } }], "claude"), "")
assert.equal(catalog.errorForProvider([{ provider: "claude", error: { code: 1 } }], "claude"), "")
assert.equal(catalog.errorForProvider([{ provider: "cli", error: "broken" }], "claude"), "")
assert.equal(catalog.errorForProvider(null, "claude"), "")
assert.equal(catalog.errorForProvider({ provider: "cli", error: { message: "x" } }, "claude"), "")

// fully colored logos keep a transparent chip; near-white brands get a dark one
assert.equal(catalog.logoBackgroundColor("codebuff"), "transparent")
assert.equal(catalog.logoBackgroundColor("vercel"), "#000000")
assert.equal(catalog.logoBackgroundColor("codex"), "#49A3B0")

const now = Date.parse("2026-08-30T12:00:00Z")
const weeklyExtra = {
    usedPercent: 10,
    windowMinutes: 10080,
    resetsAt: "2026-09-05T00:00:00Z",
}
const sessionExtra = {
    usedPercent: 10,
    windowMinutes: 300,
    resetsAt: "2026-08-30T14:00:00Z",
}

const weeklyMinutes = catalog.effectiveWindowMinutes(
    weeklyExtra, "codex", "extra"
)
assert.equal(weeklyMinutes, 10080)
assert.equal(
    catalog.paceLine(null, weeklyExtra, weeklyMinutes, now, "codex"),
    "Pace: 11% in reserve · Lasts until reset"
)

const sessionMinutes = catalog.effectiveWindowMinutes(
    sessionExtra, "codex", "extra"
)
assert.equal(sessionMinutes, 300)
assert.equal(
    catalog.paceLine(null, sessionExtra, sessionMinutes, now, "codex"),
    ""
)

// objects cross the vm boundary with a foreign prototype; compare plain copies
function plain(value) { return JSON.parse(JSON.stringify(value)) }

// Antigravity (#27): the slots repeat each model family's most constrained
// bucket; the weekly quotas only exist in the quota summary extra windows.
const antigravity = {
    primary: { usedPercent: 40, windowMinutes: 300 },
    secondary: { usedPercent: 0, windowMinutes: 300 },
    extraRateWindows: [
        { id: "antigravity-quota-summary-gemini-5h", title: "Gemini 5-hour",
          window: { usedPercent: 40, windowMinutes: 300 } },
        { id: "antigravity-quota-summary-gemini-weekly", title: "Gemini weekly",
          window: { usedPercent: 65, windowMinutes: 10080 } },
        { id: "antigravity-quota-summary-3p-5h", title: "Claude/GPT 5-hour",
          window: { usedPercent: 0, windowMinutes: 300 } },
        { id: "antigravity-quota-summary-3p-weekly", title: "Claude/GPT weekly",
          window: { usedPercent: 90, windowMinutes: 10080 }, usageKnown: false },
    ],
}
// the most constrained known bucket wins; an unknown one never does
assert.equal(catalog.windowFor(antigravity, "antigravity", 10080).usedPercent, 65)
assert.equal(catalog.windowFor(antigravity, "antigravity", 300).usedPercent, 40)
assert.deepEqual(plain(catalog.cardSlots(antigravity, "antigravity")), [])
// local reports: the family pools carry no cadence, so no session or weekly
const antigravityLocal = {
    primary: { usedPercent: 30, resetDescription: "in 5h" },
    secondary: { usedPercent: 0 },
}
assert.equal(catalog.windowFor(antigravityLocal, "antigravity", 300), null)
assert.equal(catalog.windowFor(antigravityLocal, "antigravity", 10080), null)
assert.deepEqual(plain(catalog.cardSlots(antigravityLocal, "antigravity")),
    ["primary", "secondary", "tertiary"])
assert.equal(catalog.slotTitle("antigravity", "primary", 300), "Gemini Models")
assert.equal(catalog.slotTitle("antigravity", "secondary", 0), "Claude and GPT")
// every other provider keeps the slot contract and duration titles
const legacy = { primary: { usedPercent: 5 }, secondary: { usedPercent: 7 } }
assert.equal(catalog.windowFor(legacy, "codex", 300).usedPercent, 5)
assert.equal(catalog.windowFor(legacy, "codex", 10080).usedPercent, 7)
assert.deepEqual(plain(catalog.cardSlots(antigravity, "codex")),
    ["primary", "secondary", "tertiary"])
assert.equal(catalog.slotTitle("codex", "secondary", 10080), "Weekly")
assert.equal(catalog.slotTitle("codex", "tertiary", 0), "Monthly")

// unknown usage on a named extra window reaches the window helpers
const unknownExtra = catalog.namedWindow(antigravity.extraRateWindows[3])
assert.equal(catalog.windowUsedText(unknownExtra), "–")
assert.equal(catalog.windowBarPercent(unknownExtra), 0)
assert.equal(catalog.namedWindow(antigravity.extraRateWindows[1]).usedPercent, 65)
assert.equal(catalog.namedWindow({ id: "x", window: { isSyntheticPlaceholder: true } }), null)
assert.equal(catalog.namedWindow(null), null)

// "Usage bars fill": remaining by default, used on request; unknown stays empty
assert.equal(catalog.windowUsedText({ usedPercent: 37.4 }), "37")
assert.equal(catalog.windowRemainingText({ usedPercent: 37.4 }), "63")
assert.equal(catalog.windowRemainingText({ usedPercent: 120 }), "0")
assert.equal(catalog.windowRemainingText({ usageKnown: false, usedPercent: 5 }), "–")
assert.equal(catalog.windowRemainingText(null), "–")
assert.equal(catalog.windowBarFill({ usedPercent: 37.4 }, false), 63)
assert.equal(catalog.windowBarFill({ usedPercent: 37.4 }, true), 37)
assert.equal(catalog.windowBarFill({ usedPercent: 120 }, false), 0)
assert.equal(catalog.windowBarFill({ usageKnown: false, usedPercent: 5 }, false), 0)
assert.equal(catalog.windowBarFill(null, true), 0)
// Panel percentage sources (#23): "lowest" weighs usable extra windows too
const scoped = {
    primary: { usedPercent: 12, windowMinutes: 300 },
    secondary: { usedPercent: 40, windowMinutes: 10080 },
    extraRateWindows: [
        { id: "claude-weekly-scoped-fable", title: "Fable only",
          window: { usedPercent: 88, windowMinutes: 10080 } },
        { id: "unknown", title: "Unknown", window: { usedPercent: 99 }, usageKnown: false },
        { id: "placeholder", title: "Placeholder", window: { usedPercent: 100, isSyntheticPlaceholder: true } },
    ],
}
assert.equal(catalog.panelWindow(scoped, "claude", "session").remaining, 88)
assert.equal(catalog.panelWindow(scoped, "claude", "weekly").remaining, 60)
assert.equal(catalog.panelWindow(scoped, "claude", "lowest").remaining, 12)
assert.equal(catalog.panelWindow(scoped, "claude", "lowest").window.usedPercent, 88)
// session and weekly fall back to each other; nothing known gives null
const weeklyOnly = { secondary: { usedPercent: 30, windowMinutes: 10080 } }
assert.equal(catalog.panelWindow(weeklyOnly, "codex", "session").remaining, 70)
assert.equal(catalog.panelWindow({ primary: { usedPercent: 10, windowMinutes: 300 } }, "codex", "weekly").remaining, 90)
assert.equal(catalog.panelWindow({}, "codex", "lowest"), null)
assert.equal(catalog.panelWindow(null, "codex", "session"), null)

// Only a finite usedPercent is a reading; null, NaN or a string are none.
for (const usedPercent of [null, NaN, Infinity, "40", undefined]) {
    assert.equal(catalog.windowUsageKnown({ usedPercent }), false, String(usedPercent))
    assert.equal(catalog.windowRemainingText({ usedPercent }), "–")
    assert.equal(catalog.panelWindow({ primary: { usedPercent, windowMinutes: 300 } }, "codex", "session"), null)
}
assert.equal(catalog.windowUsageKnown({ usedPercent: 0 }), true)
assert.equal(catalog.windowUsageKnown(null), false)

// "lowest" weighs a monthly window in any slot; other sources do not.
const monthly = {
    primary: { usedPercent: 20, windowMinutes: 300 },
    secondary: { usedPercent: 30, windowMinutes: 10080 },
    tertiary: { usedPercent: 95, windowMinutes: 43200 },
}
assert.equal(catalog.panelWindow(monthly, "codex", "lowest").remaining, 5)
assert.equal(catalog.panelWindow(monthly, "codex", "session").remaining, 80)
assert.equal(catalog.panelWindow(monthly, "codex", "weekly").remaining, 70)
// a tertiary window that is not monthly, or not known, stays out
assert.equal(catalog.panelWindow(Object.assign({}, monthly,
    { tertiary: { usedPercent: 95, windowMinutes: 10080 } }), "claude", "lowest").remaining, 70)
assert.equal(catalog.panelWindow(Object.assign({}, monthly,
    { tertiary: { usedPercent: null, windowMinutes: 43200 } }), "codex", "lowest").remaining, 70)

// The merged meter is stale when a value it shows comes from a stale
// provider, and without any value when every provider is.
{
    const picks = {
        codex: { session: { remaining: 40 }, weekly: { remaining: 90 } },
        claude: { session: { remaining: 70 }, weekly: { remaining: 10 } },
        gemini: { session: { remaining: 95 }, weekly: { remaining: 95 } },
    }
    const pickOf = (p, source) => (picks[p] || {})[source] || null
    const staleOf = (stale) => (p) => stale.includes(p)
    const providers = ["codex", "claude", "gemini"]
    const sources = ["session", "weekly"]
    // Gemini shows nothing, so its staleness does not matter
    assert.equal(catalog.mergedStale(providers, sources, pickOf, staleOf(["gemini"])), false)
    // Claude's weekly value is shown: its staleness does
    assert.equal(catalog.mergedStale(providers, sources, pickOf, staleOf(["claude"])), true)
    assert.equal(catalog.mergedStale(providers, sources, pickOf, staleOf(["codex"])), true)
    // the percentage's source counts as well
    picks.gemini.lowest = { remaining: 1 }
    assert.equal(catalog.mergedStale(providers, sources.concat(["lowest"]), pickOf, staleOf(["gemini"])), true)
    // no value: stale only when every provider is
    const none = () => null
    assert.equal(catalog.mergedStale(providers, sources, none, staleOf(["codex", "claude"])), false)
    assert.equal(catalog.mergedStale(providers, sources, none, staleOf(providers)), true)
    assert.equal(catalog.mergedStale([], sources, none, staleOf([])), true)
}

// Balances in usage.providerCost (#58), named as upstream's cost
// presentation names them; a zero balance is listed, a missing one is not.
{
    const usd = (fields) => Object.assign({ used: 0, limit: 0, currencyCode: "USD" }, fields)
    assert.deepEqual(plain(catalog.costBalances("claude", usd({ used: 3.2, limit: 50, balance: 14.46 }))),
        [{ label: "Extra usage balance", amount: 14.46, currencyCode: "USD" }])
    assert.deepEqual(plain(catalog.costBalances("claude", usd({ balance: 0 }))),
        [{ label: "Extra usage balance", amount: 0, currencyCode: "USD" }])
    assert.deepEqual(plain(catalog.costBalances("claude", usd({}))), [])
    assert.deepEqual(plain(catalog.costBalances("claude", usd({ balance: null }))), [])
    // Codex lists its balance in credits only
    assert.deepEqual(plain(catalog.costBalances("codex", { used: 0, limit: 0, currencyCode: "Credits", balance: 1200 })),
        [{ label: "Extra usage balance", amount: 1200, currencyCode: "Credits" }])
    assert.deepEqual(plain(catalog.costBalances("codex", usd({ balance: 5 }))), [])
    // Devin and LiteLLM carry the amount in `used`
    assert.deepEqual(plain(catalog.costBalances("devin", usd({ used: 7.5, period: "Extra usage balance" }))),
        [{ label: "Extra usage", amount: 7.5, currencyCode: "USD" }])
    assert.deepEqual(plain(catalog.costBalances("devin", usd({ used: 7.5, limit: 20, period: "Monthly" }))), [])
    assert.deepEqual(plain(catalog.costBalances("litellm", usd({ used: 12, period: "This month" }))),
        [{ label: "This month", amount: 12, currencyCode: "USD" }])
    assert.deepEqual(plain(catalog.costBalances("litellm", usd({ used: 12, limit: 0 }))),
        [{ label: "Spend", amount: 12, currencyCode: "USD" }])
    assert.deepEqual(plain(catalog.costBalances("litellm", usd({ used: 12, limit: 100 }))), [])
    // any other provider, such as Grok's purchased credits (CodexBar 0.72)
    assert.deepEqual(plain(catalog.costBalances("grok", usd({ balance: 14.46 }))),
        [{ label: "Balance", amount: 14.46, currencyCode: "USD" }])
    assert.deepEqual(plain(catalog.costBalances("grok", null)), [])

    // the generic used/limit line stays away from balance-only snapshots
    assert.equal(catalog.showsCostFallback("claude", usd({ used: 3.2, limit: 50, balance: 14.46 })), true)
    assert.equal(catalog.showsCostFallback("claude", usd({ balance: 14.46 })), false)
    assert.equal(catalog.showsCostFallback("grok", usd({ balance: 0 })), false)
    assert.equal(catalog.showsCostFallback("codex", { used: 0, limit: 0, currencyCode: "Credits" }), false)
    assert.equal(catalog.showsCostFallback("codex", { used: 10, limit: 0, currencyCode: "Quota" }), true)
    assert.equal(catalog.showsCostFallback("devin", usd({ used: 7.5, period: "Extra usage balance" })), false)
    assert.equal(catalog.showsCostFallback("litellm", usd({ used: 12 })), false)
    assert.equal(catalog.showsCostFallback("litellm", usd({ used: 12, limit: 100 })), true)
    assert.equal(catalog.showsCostFallback("cursor", null), false)

    assert.equal(catalog.amountText(14.46, "USD"), "$ 14.46")
    assert.equal(catalog.amountText(-0.5, undefined), "$ -0.50")
    assert.equal(catalog.amountText(1200, "Credits"), "1200.00 Credits")
    assert.equal(catalog.amountText(NaN, "USD"), "")
}

// The windows notifications watch: the card's windows with a reading.
assert.deepEqual(plain(catalog.notificationWindows(scoped, "claude")), [
    { key: "primary", label: "Session", remaining: 88, resetsAt: "" },
    { key: "secondary", label: "Weekly", remaining: 60, resetsAt: "" },
    { key: "extra:claude-weekly-scoped-fable", label: "Fable only", remaining: 12, resetsAt: "" },
])
assert.deepEqual(plain(catalog.notificationWindows(
    { primary: { usedPercent: 30, windowMinutes: 300, resetsAt: "2026-10-06T15:00:00Z" } }, "codex")),
    [{ key: "primary", label: "Session", remaining: 70, resetsAt: "2026-10-06T15:00:00Z" }])
// Antigravity's quota summary replaces its family slots, as on the card
assert.deepEqual(plain(catalog.notificationWindows(antigravity, "antigravity").map((w) => w.key)), [
    "extra:antigravity-quota-summary-gemini-5h",
    "extra:antigravity-quota-summary-gemini-weekly",
    "extra:antigravity-quota-summary-3p-5h",
])
assert.deepEqual(plain(catalog.notificationWindows(null, "codex")), [])

// Reset countdown (#30): the window behind the panel percentage
const countdownNow = Date.parse("2026-09-30T12:00:00Z")
const pickAt = (resetsAt) => ({ remaining: 60, window: { usedPercent: 40, resetsAt } })
assert.equal(catalog.panelCountdown(pickAt("2026-09-30T15:50:00Z"), countdownNow), "3h 50m")
assert.equal(catalog.panelCountdown(pickAt("2026-10-04T01:00:00Z"), countdownNow), "3d 13h")
assert.equal(catalog.panelCountdown(pickAt("2026-09-30T11:00:00Z"), countdownNow), "")
assert.equal(catalog.panelCountdown(pickAt("not a date"), countdownNow), "")
assert.equal(catalog.panelCountdown({ remaining: 60, window: { usedPercent: 40 } }, countdownNow), "")
assert.equal(catalog.panelCountdown(null, countdownNow), "")

console.log("Catalog tests passed")
