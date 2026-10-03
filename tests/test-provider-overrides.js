#!/usr/bin/env node

const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const source = fs.readFileSync(
    path.join(__dirname, "..", "contents", "ui", "code", "providerOverrides.js"),
    "utf8"
).replace(/^\.pragma library$/m, "")
const lib = {}
vm.createContext(lib)
vm.runInContext(source, lib, { filename: "providerOverrides.js" })

// objects cross the vm boundary with a foreign prototype; compare plain copies
function plain(value) { return JSON.parse(JSON.stringify(value)) }

// parsing tolerates junk and drops invalid values/entries
assert.deepEqual(plain(lib.parse("")), {})
assert.deepEqual(plain(lib.parse(undefined)), {})
assert.deepEqual(plain(lib.parse("not json")), {})
assert.deepEqual(plain(lib.parse("[]")), {})
assert.deepEqual(plain(lib.parse("{}")), {})
assert.deepEqual(plain(lib.parse('{"codex":{"hideCritters":true}}')),
    { codex: { hideCritters: true } })
// unknown keys (for example from a newer or older version) are dropped
assert.deepEqual(plain(lib.parse('{"codex":{"refreshIntervalMinutes":10}}')), {})
assert.deepEqual(plain(lib.parse('{"codex":{"panelDisplayMode":"bogus"}}')), {})
assert.deepEqual(plain(lib.parse('{"codex":{"showPercentInPanel":"yes"}}')), {})
assert.deepEqual(plain(lib.parse('{"codex":{"showPercentInPanel":true}}')),
    { codex: { showPercentInPanel: true } })
assert.deepEqual(plain(lib.parse('{"codex":{}}')), {})

// serialization is stable, sorted, and drops empties/invalid values
assert.equal(lib.serialize({}), "{}")
assert.equal(lib.serialize({ claude: {}, codex: { hideCritters: true } }),
    '{"codex":{"hideCritters":true}}')
assert.equal(lib.serialize({ kilo: { panelDisplayMode: "bogus" } }), "{}")

// lookups
assert.deepEqual(plain(lib.settingsFor('{"codex":{"hideCritters":true}}', "codex")),
    { hideCritters: true })
assert.deepEqual(plain(lib.settingsFor('{"codex":{"hideCritters":true}}', "claude")), {})
assert.equal(lib.hasOverride('{"codex":{"hideCritters":true}}', "codex"), true)
assert.equal(lib.hasOverride('{"codex":{"hideCritters":true}}', "claude"), false)

// a parsed map works wherever the stored string does
const parsed = lib.parse('{"codex":{"hideCritters":true}}')
assert.deepEqual(plain(lib.settingsFor(parsed, "codex")), { hideCritters: true })
assert.equal(lib.effectiveHideCritters(parsed, "codex", false), true)
assert.equal(lib.hasOverride(parsed, "claude"), false)

// multi-key updates; last empty entry removes the provider
raw = lib.withSettings("{}", "claude", { panelDisplayMode: "logos", percentStyle: "used" })
assert.equal(raw, '{"claude":{"panelDisplayMode":"logos","percentStyle":"used"}}')
raw = lib.withSettings(raw, "claude", { panelDisplayMode: null, percentStyle: null })
assert.equal(raw, "{}")
assert.equal(lib.withSettings("{}", "claude", { panelDisplayMode: "bogus" }), "{}")

// reset forgets every override for one provider only
raw = lib.withSettings('{"codex":{"hideCritters":true}}', "claude",
    { panelDisplayMode: "logos" })
assert.equal(lib.resetProvider(raw, "codex"),
    '{"claude":{"panelDisplayMode":"logos"}}')
assert.equal(lib.resetProvider(raw, "nobody"), raw)

// providers with overrides, in display order, unknown ids last
assert.deepEqual(plain(lib.overriddenProviders("{}", ["codex", "claude"])), [])
assert.deepEqual(plain(lib.overriddenProviders(
    '{"claude":{"hideCritters":true},"codex":{"panelDisplayMode":"logos"},"zeta":{"hideCritters":true},"alpha":{"hideCritters":true}}',
    ["codex", "claude", "gemini"])), ["codex", "claude", "alpha", "zeta"])
// entries holding only invalid values do not count
assert.deepEqual(plain(lib.overriddenProviders('{"codex":{"panelDisplayMode":"bogus"}}', ["codex"])), [])
assert.deepEqual(plain(lib.overriddenProviders('{"codex":{"hideCritters":true}}')), ["codex"])
// the parsed map works too, like the other helpers
assert.deepEqual(plain(lib.overriddenProviders(lib.parse('{"claude":{"hideCritters":true}}'), ["claude"])), ["claude"])
// "Reset All" is an empty map
assert.deepEqual(plain(lib.overriddenProviders(lib.serialize({}), ["codex"])), [])

// effective values prefer valid overrides, else the global (normalized)
assert.equal(lib.effectiveHideCritters(raw, "codex", false), true)
assert.equal(lib.effectiveHideCritters(raw, "kilo", false), false)
assert.equal(lib.effectiveDisplayMode(raw, "claude", "meters"), "logos")
assert.equal(lib.effectiveDisplayMode(raw, "codex", "meters"), "meters")
assert.equal(lib.effectiveDisplayMode(raw, "codex", "bogus"), "meters")
assert.equal(lib.effectiveShowPercent('{"codex":{"showPercentInPanel":true}}', "codex", false), true)
assert.equal(lib.effectiveShowPercent("{}", "codex", true), true)
assert.equal(lib.effectivePercentSource("{}", "codex", "weekly"), "weekly")
assert.equal(lib.effectivePercentSource("{}", "codex", "bogus"), "session")
assert.equal(lib.effectivePercentStyle("{}", "codex", "used"), "used")
assert.equal(lib.effectiveHideCritters('{"codex":{"hideCritters":true}}', "codex", false), true)
assert.equal(lib.effectiveHideCritters("{}", "codex", false), false)

// panel icon layout: overridden providers leave the merged meter, the rest stay
const globals = { panelDisplayMode: "meters", showPercentInPanel: false,
                  panelPercentSource: "session", percentStyle: "remaining",
                  hideCritters: false }
const enabled = ["codex", "claude", "gemini"]
const layout = (raw, g, separate) => plain(lib.panelIconModel(raw, enabled, g || globals, separate === true))
// no overrides: one merged meter covering everyone
assert.deepEqual(layout("{}"), { icons: ["__merged__"], merged: enabled })
// a display override pulls out only that provider
assert.deepEqual(layout('{"codex":{"panelDisplayMode":"logos"}}'),
    { icons: ["__merged__", "codex"], merged: ["claude", "gemini"] })
// any ticked panel override splits the provider out, even one equal to the global
assert.deepEqual(layout('{"codex":{"panelDisplayMode":"meters"}}'),
    { icons: ["__merged__", "codex"], merged: ["claude", "gemini"] })
// other panel overrides also need their own icon to be visible
assert.deepEqual(layout('{"claude":{"showPercentInPanel":true}}'),
    { icons: ["__merged__", "claude"], merged: ["codex", "gemini"] })
assert.deepEqual(layout('{"claude":{"hideCritters":true}}'),
    { icons: ["__merged__", "claude"], merged: ["codex", "gemini"] })
assert.deepEqual(layout('{"claude":{"showPercentInPanel":false}}'),
    { icons: ["__merged__", "claude"], merged: ["codex", "gemini"] })
assert.deepEqual(layout('{"claude":{"percentStyle":"remaining"}}'),
    { icons: ["__merged__", "claude"], merged: ["codex", "gemini"] })
// every provider overridden: no empty merged meter
assert.deepEqual(layout('{"codex":{"hideCritters":true},"claude":{"hideCritters":true},"gemini":{"hideCritters":true}}'),
    { icons: enabled, merged: [] })
// per-provider global layouts are unchanged by overrides
assert.deepEqual(layout('{"codex":{"panelDisplayMode":"meters"}}', Object.assign({}, globals, { panelDisplayMode: "logos" })),
    { icons: enabled, merged: [] })
assert.deepEqual(layout("{}", globals, true), { icons: enabled, merged: [] })
// nothing enabled: the merged fallback stays clickable
assert.deepEqual(plain(lib.panelIconModel("{}", [], globals, false)), { icons: ["__merged__"], merged: [] })
assert.deepEqual(plain(lib.panelIconModel("{}", [], globals, true)), { icons: ["__merged__"], merged: [] })

// setting registry: the single source for per-provider mirroring
assert.deepEqual(plain(lib.SETTING_KEYS),
    ["panelDisplayMode", "showPercentInPanel",
     "panelPercentSource", "percentStyle", "showResetCountdown", "hideCritters",
     "middleClickAction", "doubleClickAction", "launchCommand"])
assert.equal(lib.defFor("nope"), null)
assert.deepEqual(plain(lib.keysForSection("percentage")),
    ["panelPercentSource", "percentStyle", "showResetCountdown"])
assert.deepEqual(plain(lib.keysForSection("nope")), [])

// every registry entry is well formed and validation follows it
for (const key of lib.SETTING_KEYS) {
    const def = plain(lib.defFor(key))
    assert.ok(lib.SECTIONS.indexOf(def.section) >= 0, `${key} section`)
    if (def.control === "enum") {
        assert.ok(Array.isArray(plain(def.values)) && def.values.length > 0)
        for (const value of def.values)
            assert.equal(lib.isValidValue(key, value), true)
        assert.equal(lib.isValidValue(key, "bogus"), false)
    } else if (def.control === "bool") {
        assert.equal(lib.isValidValue(key, true), true)
        assert.equal(lib.isValidValue(key, false), true)
        assert.equal(lib.isValidValue(key, "yes"), false)
    } else if (def.control === "text") {
        assert.equal(lib.isValidValue(key, "konsole -e codex"), true)
        assert.equal(lib.isValidValue(key, "   "), false)
        assert.equal(lib.isValidValue(key, true), false)
        assert.equal(lib.isValidValue(key, "x".repeat(1001)), false)
    } else {
        assert.fail(`unknown control for ${key}`)
    }
}

// percentage rows depend on the effective show-percentage value
assert.equal(plain(lib.defFor("panelPercentSource")).requires, "showPercentInPanel")
assert.equal(plain(lib.defFor("percentStyle")).requires, "showPercentInPanel")
assert.equal(plain(lib.defFor("showResetCountdown")).requires, "showPercentInPanel")
// click actions (#18): per-provider action and command, else the globals
assert.deepEqual(plain(lib.keysForSection("clicks")),
    ["middleClickAction", "doubleClickAction", "launchCommand"])
const clicks = '{"codex":{"middleClickAction":"command","launchCommand":"  konsole -e codex  "}}'
assert.equal(lib.effectiveClickAction(clicks, "codex", "middleClickAction", "refresh"), "command")
assert.equal(lib.effectiveClickAction(clicks, "claude", "middleClickAction", "refresh"), "refresh")
assert.equal(lib.effectiveClickAction(clicks, "codex", "doubleClickAction", "bogus"), "none")
assert.equal(lib.effectiveLaunchCommand(clicks, "codex", "true"), "konsole -e codex")
assert.equal(lib.effectiveLaunchCommand(clicks, "claude", " kitty "), "kitty")
assert.equal(lib.effectiveLaunchCommand("{}", "claude", undefined), "")
assert.equal(lib.serialize({ codex: { launchCommand: "  " } }), "{}")
// a click override alone also gives the provider its own icon
assert.deepEqual(layout('{"claude":{"middleClickAction":"refresh"}}'),
    { icons: ["__merged__", "claude"], merged: ["codex", "gemini"] })

// the reset countdown follows the global setting unless ticked
assert.equal(lib.effectiveShowResetCountdown("{}", "codex", true), true)
assert.equal(lib.effectiveShowResetCountdown('{"codex":{"showResetCountdown":false}}', "codex", true), false)
assert.equal(lib.effectiveShowResetCountdown('{"codex":{"showResetCountdown":"yes"}}', "codex", false), false)
assert.equal("requires" in plain(lib.defFor("showPercentInPanel")), false)

// footer preview: uncommitted dialog values serialize, then the panel's own
// effective* helpers resolve them (overrides win, the rest follow globals)
const dialogRaw = lib.serialize({ codex: { panelDisplayMode: "logos", showPercentInPanel: true } })
assert.equal(lib.effectiveDisplayMode(dialogRaw, "codex", "meters"), "logos")
assert.equal(lib.effectiveShowPercent(dialogRaw, "codex", false), true)
assert.equal(lib.effectivePercentSource(dialogRaw, "codex", "session"), "session")

console.log("Provider overrides tests passed")
