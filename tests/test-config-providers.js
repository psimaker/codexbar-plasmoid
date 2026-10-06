#!/usr/bin/env node

const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

function load(file) {
    const source = fs.readFileSync(
        path.join(__dirname, "..", "contents", "ui", "code", file), "utf8"
    ).replace(/^\.pragma library$/m, "")
    const context = {}
    vm.createContext(context)
    vm.runInContext(source, context, { filename: file })
    return context
}

const lib = load("configProviders.js")
const catalog = load("catalog.js")

// objects cross the vm boundary with a foreign prototype; compare plain copies
function plain(value) { return JSON.parse(JSON.stringify(value)) }

// `config providers --json` and `config dump --json` as CodexBar 0.70 prints them
const providers = JSON.stringify([
    { displayName: "Codex", enabled: true, provider: "codex", defaultEnabled: true },
    { displayName: "Groq", enabled: false, provider: "groq", defaultEnabled: false },
    { displayName: "Claude", enabled: true, provider: "claude", defaultEnabled: false },
    { displayName: "My Plugin", enabled: true, provider: "myplugin", defaultEnabled: false },
])
const dump = JSON.stringify({ providers: [
    { id: "codex", enabled: true },
    { id: "claude", enabled: true, source: "oauth" },
] })

const list = lib.parse(providers, dump, catalog.cliProviderId)
assert.deepEqual(plain(list), [
    { id: "codex", name: "Codex", enabled: true, defaultEnabled: true, source: "auto" },
    { id: "groqcloud", name: "Groq", enabled: false, defaultEnabled: false, source: "auto" },
    { id: "claude", name: "Claude", enabled: true, defaultEnabled: false, source: "oauth" },
    { id: "myplugin", name: "My Plugin", enabled: true, defaultEnabled: false, source: "auto" },
])
assert.deepEqual(plain(lib.enabledIds(list)), ["codex", "claude", "myplugin"])
assert.deepEqual(plain(lib.defaultIds(list)), ["codex"])

// an unreadable dump keeps every source at auto; an unreadable list is null
assert.equal(lib.parse(providers, "", catalog.cliProviderId)[2].source, "auto")
assert.equal(lib.parse("", dump, catalog.cliProviderId), null)
assert.equal(lib.parse('{"providers":[]}', dump, catalog.cliProviderId), null)
// so is a list without a provider
assert.equal(lib.parse("[]", dump, catalog.cliProviderId), null)
assert.equal(lib.parse('[{"enabled":true},null,{"provider":""}]', "", catalog.cliProviderId), null)
// a provider without a display name shows its id, one without defaultEnabled
// is not enabled by default
assert.equal(lib.parse('[{"provider":"x","enabled":true}]', "", catalog.cliProviderId)[0].name, "x")
assert.equal(lib.parse('[{"provider":"x","enabled":true}]', "", catalog.cliProviderId)[0].defaultEnabled, false)

// A config.json the CLI cannot decode makes `config providers --json` exit 1
// with this envelope (CodexBar 0.70); it is no list of a provider "cli".
const decodeError = {
    kind: "config", code: 1,
    message: "Failed to decode CodexBar config: The data isn't in the correct format.",
}
assert.equal(lib.parse(JSON.stringify([{ provider: "cli", source: "cli", error: decodeError }]),
    JSON.stringify([{ provider: "cli", source: "cli", error: decodeError }]), catalog.cliProviderId), null)
// an error entry voids the providers next to it
assert.equal(lib.parse(JSON.stringify([
    { displayName: "Codex", enabled: true, provider: "codex", defaultEnabled: true },
    { provider: "cli", error: decodeError },
]), dump, catalog.cliProviderId), null)

// Enabled and default providers compare as sets.
assert.equal(lib.sameIds(["codex", "claude"], ["claude", "codex"]), true)
assert.equal(lib.sameIds(["codex", "codex"], ["codex"]), true)
assert.equal(lib.sameIds([], []), true)
assert.equal(lib.sameIds(["codex"], ["codex", "claude"]), false)
assert.equal(lib.sameIds(["codex", "claude"], ["codex"]), false)
assert.equal(lib.sameIds(["claude"], ["codex"]), false)

// One-time migration of the widget's own list (#25). `config providers
// --json` for CodexBar ids of which `on` are enabled; `defaults` are enabled
// without a config.json (only Codex up to CodexBar 0.70).
function configList(on, defaults) {
    return lib.parse(JSON.stringify(["codex", "claude", "cursor", "gemini", "groq"].map((id) => ({
        displayName: id, enabled: on.includes(id), provider: id,
        defaultEnabled: (defaults || ["codex"]).includes(id),
    }))), "", catalog.cliProviderId)
}
// config.json enables migratedIds afterwards, through these writes
function migrate(list, widget) {
    const ids = lib.migratedIds(list, widget)
    return { ids: plain(ids), writes: plain(lib.changes(list, ids)) }
}
const untouched = configList(["codex"])
const curated = configList(["codex", "cursor", "gemini"])
const widgetDefault = ["codex", "claude"] // enabledProviders in contents/config/main.xml
const widgetChanged = ["claude", "cursor"]

// P1 new widget and P5 a widget list never changed since an earlier
// version (both codex,claude), untouched config.json: Codex and Claude
assert.deepEqual(migrate(untouched, widgetDefault),
    { ids: ["codex", "claude"], writes: ["enable --provider claude"] })
// P2 new widget, curated config.json: config.json stays
assert.deepEqual(migrate(curated, widgetDefault), { ids: ["codex", "cursor", "gemini"], writes: [] })
// P3 changed widget list, untouched config.json: both together, nothing disabled
assert.deepEqual(migrate(untouched, widgetChanged), {
    ids: ["codex", "claude", "cursor"],
    writes: ["enable --provider claude", "enable --provider cursor"],
})
// P4 changed widget list, curated config.json: config.json stays
assert.deepEqual(migrate(curated, widgetChanged), { ids: ["codex", "cursor", "gemini"], writes: [] })

// A config.json without Codex, or with nothing enabled, is curated as well.
assert.deepEqual(migrate(configList(["claude"]), widgetChanged), { ids: ["claude"], writes: [] })
assert.deepEqual(migrate(configList([]), widgetDefault), { ids: [], writes: [] })
// A second widget finds the first one's selection and keeps it; the read
// after the first one's write does not write again either.
assert.deepEqual(migrate(configList(["codex", "claude"]), ["gemini"]),
    { ids: ["codex", "claude"], writes: [] })
// The defaults come from the CLI, not from the widget.
assert.deepEqual(migrate(configList(["codex", "claude"], ["codex", "claude"]), ["gemini"]),
    { ids: ["codex", "claude", "gemini"], writes: ["enable --provider gemini"] })
assert.deepEqual(migrate(configList(["codex"], ["codex", "claude"]), ["gemini"]),
    { ids: ["codex"], writes: [] })
// Widget ids config.json does not know are left out.
assert.deepEqual(migrate(untouched, ["crof", "claude"]),
    { ids: ["codex", "claude"], writes: ["enable --provider claude"] })
assert.deepEqual(plain(lib.migratedIds(null, widgetDefault)), [])

// writes: enable exactly what is wanted, in list order, known ids only
assert.deepEqual(plain(lib.changes(list, ["codex", "groqcloud", "unknown"])),
    ["enable --provider groqcloud", "disable --provider claude", "disable --provider myplugin"])
assert.deepEqual(plain(lib.changes(list, ["codex", "claude", "myplugin"])), [])
assert.deepEqual(plain(lib.changes(null, ["codex"])), [])
assert.deepEqual(plain(lib.enabledIds(null)), [])

// A settings page keeps its own ticks on top of what the widget copied from
// config.json while it was open.
const base = ["codex", "claude"]
// nothing ticked here: config.json's newer selection as it is
assert.deepEqual(plain(lib.rebaseSelection(base, base, ["codex", "claude", "groqcloud"])),
    ["codex", "claude", "groqcloud"])
assert.deepEqual(plain(lib.rebaseSelection(base, base, ["codex"])), ["codex"])
// ticked and unticked here, while the CLI enabled Groq
assert.deepEqual(plain(lib.rebaseSelection(base, ["codex", "cursor"], ["codex", "claude", "groqcloud"])),
    ["codex", "groqcloud", "cursor"])
// the page wins where both changed a provider
assert.deepEqual(plain(lib.rebaseSelection(base, ["codex"], ["codex", "claude"])), ["codex"])
assert.deepEqual(plain(lib.rebaseSelection(["codex"], ["codex", "gemini"], ["codex", "gemini"])),
    ["codex", "gemini"])
assert.deepEqual(plain(lib.rebaseSelection(["codex"], ["codex", "gemini"], [])), ["gemini"])
// the page's own Apply comes back unchanged
assert.deepEqual(plain(lib.rebaseSelection(base, ["claude", "gemini"], ["claude", "gemini"])),
    ["claude", "gemini"])

// A failed `config enable|disable --json` step prints the CLI's error entry
// after the results of the steps before it (CodexBar 0.66 to 0.71).
assert.equal(lib.writeError(
    '{"provider":"claude","enabled":true,"displayName":"Claude","configPath":"/home/u/.config/codexbar/config.json"}\n'
    + '[{"error":{"kind":"config","code":1,"message":"Permission denied"},"provider":"cli","source":"cli"}]\n'),
    "Permission denied")
assert.equal(lib.writeError(JSON.stringify([{ provider: "cli", source: "cli", error: decodeError }])),
    decodeError.message)
assert.equal(lib.writeError('{"provider":"claude","enabled":true}\n'), "")
assert.equal(lib.writeError(""), "")
assert.equal(lib.writeError("Error: something\n"), "")
assert.equal(lib.writeError(null), "")

// ---- one write at a time ----
// config.json as the ids it enables; `steps` run against it like the CLI.
function runSteps(enabled, steps) {
    const out = new Set(enabled)
    for (const step of steps) {
        const [verb, , id] = step.split(" ")
        if (verb === "enable") out.add(id)
        else out.delete(id)
    }
    return [...out]
}
// A read of config.json (`file`) that finishes, as main.qml passes it on.
function finishRead(sync, token, file, migrated = true, widget = []) {
    return lib.read(sync, token, configList(file), migrated, widget)
}

// Two Applies in a row, the second before the first write was read back:
// disable Claude, then enable it again. The second used to be dropped,
// because it was compared with the list read before the first write.
{
    let file = ["codex", "claude"]
    const before = configList(file)
    let sync = lib.syncState()
    let r = lib.request(sync, before, ["codex"], true, false)
    sync = r.state
    const first = r.write
    assert.deepEqual(plain(first.steps), ["disable --provider claude"])
    r = lib.request(sync, before, ["codex", "claude"], true, false)
    sync = r.state
    assert.equal(r.write, null)
    // a third Apply replaces the waiting one: the latest wins
    r = lib.request(sync, before, ["codex", "claude", "gemini"], true, false)
    sync = r.state
    assert.equal(r.write, null)
    file = runSteps(file, first.steps)
    let done = finishRead(sync, lib.readBack(sync, first), file)
    sync = done.state
    assert.equal(done.action.type, "write")
    assert.deepEqual(plain(done.action.steps), ["enable --provider claude", "enable --provider gemini"])
    file = runSteps(file, done.action.steps)
    done = finishRead(sync, lib.readBack(sync, done.action), file)
    sync = done.state
    assert.equal(done.action.type, "show")
    assert.equal(done.action.force, true)
    assert.deepEqual(file, ["codex", "claude", "gemini"])
    assert.equal(sync.writing, false)
    assert.equal(sync.queued, null)
}

// A waiting Apply that matches what the first write left needs no write.
{
    let file = ["codex"]
    let sync = lib.syncState()
    let r = lib.request(sync, configList(file), ["codex", "claude"], true, false)
    sync = r.state
    const write = r.write
    sync = lib.request(sync, configList(file), ["codex", "claude"], true, false).state
    file = runSteps(file, write.steps)
    const done = finishRead(sync, lib.readBack(sync, write), file)
    assert.equal(done.action.type, "show")
    assert.equal(done.state.queued, null)
}

// A periodic read that started before an Apply's write is dropped, whether
// it finishes before or after the write's read-back: it may show config.json
// from before the write and would undo the Apply in the widget.
for (const lateRead of [false, true]) {
    let file = ["codex"]
    let sync = lib.syncState()
    const timer = lib.refresh(sync, false)
    sync = timer.state
    const oldFile = configList(file)
    const r = lib.request(sync, configList(file), ["codex", "claude"], true, false)
    sync = r.state
    file = runSteps(file, r.write.steps)
    let stale
    if (!lateRead) {
        stale = lib.read(sync, timer.read, oldFile, true, [])
        assert.equal(stale.action.type, "drop")
        sync = stale.state
    }
    const done = finishRead(sync, lib.readBack(sync, r.write), file)
    sync = done.state
    assert.equal(done.action.type, "show")
    if (lateRead) {
        stale = lib.read(sync, timer.read, oldFile, true, [])
        assert.equal(stale.action.type, "drop")
    }
    assert.deepEqual(file, ["codex", "claude"])
}

// A refresh while a write runs reads nothing itself; the read-back probes,
// with force when the refresh asked for it (a manual refresh).
{
    let sync = lib.syncState()
    const r = lib.request(sync, configList(["codex"]), ["codex", "claude"], false, false)
    sync = r.state
    const manual = lib.refresh(sync, true)
    assert.equal(manual.read, null)
    sync = manual.state
    const done = finishRead(sync, lib.readBack(sync, r.write), ["codex", "claude"])
    assert.equal(done.action.type, "show")
    assert.equal(done.action.force, true)
    assert.equal(done.state.force, false)
    // a dropped read's force reaches the read-back as well
    let next = lib.syncState()
    const timer = lib.refresh(next, true)
    next = timer.state
    const w = lib.request(next, configList(["codex"]), ["codex", "claude"], false, false)
    next = w.state
    next = lib.read(next, timer.read, configList(["codex"]), true, []).state
    assert.equal(finishRead(next, lib.readBack(next, w.write), ["codex", "claude"]).action.force, true)
    // reads go ahead again once the write is done
    assert.notEqual(lib.refresh(done.state, false).read, null)
}

// A failed write reads back config.json as it is, so the widget shows that.
{
    let sync = lib.syncState()
    const r = lib.request(sync, configList(["codex"]), ["codex", "claude"], true, false)
    sync = r.state
    const done = finishRead(sync, lib.readBack(sync, r.write), ["codex"])
    assert.equal(done.action.type, "show")
    assert.equal(done.state.writing, false)
}

// The migration (#25) goes through the same order: the first read writes the
// widget's providers, its read-back records the migration as done, and an
// Apply made meanwhile follows.
{
    let file = ["codex"]
    let sync = lib.syncState()
    const first = lib.refresh(sync, true)
    sync = first.state
    let done = finishRead(sync, first.read, file, false, ["codex", "claude"])
    sync = done.state
    assert.equal(done.action.type, "write")
    assert.equal(done.action.migration, true)
    assert.equal(done.action.migrated, false)
    assert.deepEqual(plain(done.action.steps), ["enable --provider claude"])
    const migration = done.action
    sync = lib.request(sync, configList(file), ["codex", "claude", "cursor"], true, false).state
    file = runSteps(file, migration.steps)
    done = finishRead(sync, lib.readBack(sync, migration), file, false, ["codex", "claude"])
    sync = done.state
    assert.equal(done.action.type, "write")
    assert.equal(done.action.migrated, true)
    assert.deepEqual(plain(done.action.steps), ["enable --provider cursor"])
    file = runSteps(file, done.action.steps)
    done = finishRead(sync, lib.readBack(sync, done.action), file, true, ["codex", "claude"])
    assert.equal(done.action.type, "show")
    assert.equal(done.action.migrated, false)
    assert.deepEqual(file, ["codex", "claude", "cursor"])
    // a curated config.json needs no write and is migrated at once
    const curatedRead = finishRead(lib.syncState(), lib.refresh(lib.syncState(), true).read,
        ["cursor"], false, ["codex", "claude"])
    assert.equal(curatedRead.action.type, "show")
    assert.equal(curatedRead.action.migrated, true)
}

// A failed migration write gives up for the session, with nothing waiting.
{
    let sync = lib.syncState()
    const done = finishRead(sync, lib.refresh(sync, true).read, ["codex"], false, ["codex", "claude"])
    sync = lib.request(done.state, configList(["codex"]), ["codex"], true, false).state
    const abandoned = lib.abandon(sync, done.action)
    assert.equal(abandoned.state.writing, false)
    assert.equal(abandoned.state.queued, null)
    assert.equal(abandoned.force, true)
}

// An unreadable config.json leaves config mode and drops a waiting Apply.
{
    let sync = lib.syncState()
    const r = lib.request(sync, configList(["codex"]), ["codex", "claude"], true, false)
    sync = lib.request(r.state, configList(["codex"]), ["codex"], true, false).state
    const done = lib.read(sync, lib.readBack(sync, r.write), null, true, [])
    assert.equal(done.action.type, "leave")
    assert.equal(done.action.force, true)
    assert.equal(done.state.queued, null)
    assert.equal(done.state.writing, false)
}

// A new CLI check drops the old check's results, so the write stops
// counting as running; a waiting Apply goes with the next read.
{
    let sync = lib.syncState()
    const r = lib.request(sync, configList(["codex"]), ["codex", "claude"], true, false)
    sync = lib.request(r.state, configList(["codex"]), ["codex", "gemini"], true, false).state
    sync = lib.restart(sync)
    assert.equal(sync.writing, false)
    const fresh = lib.refresh(sync, true)
    assert.notEqual(fresh.read, null)
    const done = finishRead(fresh.state, fresh.read, ["codex", "claude"])
    assert.equal(done.action.type, "write")
    assert.deepEqual(plain(done.action.steps), ["disable --provider claude", "enable --provider gemini"])
}

// ---- sources in config.json (`config set-source`, CodexBar 0.72.1) ----
// config.json storing `sources` (by CodexBar id) and enabling `on`.
function sourceList(sources, on = ["codex", "claude"]) {
    const ids = ["codex", "claude", "cursor", "groq"]
    return lib.parse(JSON.stringify(ids.map((id) => ({
        displayName: id, enabled: on.includes(id), provider: id, defaultEnabled: id === "codex",
    }))), JSON.stringify({ providers: Object.entries(sources).map(([id, source]) => ({ id, source })) }),
    catalog.cliProviderId)
}

// The settings page offers the same sources.
{
    const sources = load("providerSources.js")
    assert.deepEqual(plain(lib.SETTABLE_SOURCES),
        plain(sources.SOURCES).filter((s) => s !== sources.DEFAULT_SOURCE))
}

{
    const stored = sourceList({ claude: "oauth", cursor: "localprobe" })
    // the settings page mirrors the stored sources it knows
    assert.deepEqual(plain(lib.storedSources(stored)), { claude: "oauth" })
    // set-source steps in list order; a provider left out wants auto
    assert.deepEqual(plain(lib.sourceChanges(stored, { claude: "oauth" })), [])
    assert.deepEqual(plain(lib.sourceChanges(stored, { codex: "api", groqcloud: "api" })), [
        "set-source --provider codex --source api",
        "set-source --provider claude --source auto",
        "set-source --provider groqcloud --source api",
    ])
    // a stored source the widget does not know stays until another is picked
    assert.deepEqual(plain(lib.sourceChanges(stored, { claude: "oauth", cursor: "web" })),
        ["set-source --provider cursor --source web"])
    // providers config.json does not list are left alone
    assert.deepEqual(plain(lib.sourceChanges(stored, { claude: "oauth", gemini: "api" })), [])
    // the widget's own sources go to providers without a stored one only
    assert.deepEqual(plain(lib.migratedSources(stored, { codex: "api", claude: "cli", cursor: "api" })),
        { claude: "oauth", codex: "api" })
    assert.deepEqual(plain(lib.sourceChanges(stored,
        lib.migratedSources(stored, { codex: "api", claude: "cli", cursor: "api" }))),
        ["set-source --provider codex --source api"])
}

// An Apply writes its enable/disable and set-source steps in one go; one
// made while a write runs waits with its sources. Without sources, an Apply
// leaves the stored ones alone.
{
    let sync = lib.syncState()
    let r = lib.request(sync, sourceList({ claude: "oauth" }), ["codex", "claude", "cursor"], true, false,
        { claude: "cli" })
    sync = r.state
    const first = r.write
    assert.deepEqual(plain(first.steps),
        ["enable --provider cursor", "set-source --provider claude --source cli"])
    assert.equal(first.sourceMigration, false)
    r = lib.request(sync, sourceList({ claude: "oauth" }), ["codex", "claude"], true, false,
        { claude: "oauth", codex: "api" })
    sync = r.state
    assert.equal(r.write, null)
    const done = lib.read(sync, lib.readBack(sync, first),
        sourceList({ claude: "cli" }, ["codex", "claude", "cursor"]), true, [], null)
    assert.equal(done.action.type, "write")
    assert.deepEqual(plain(done.action.steps), [
        "disable --provider cursor",
        "set-source --provider codex --source api",
        "set-source --provider claude --source oauth",
    ])
    assert.equal(lib.request(lib.syncState(), sourceList({ claude: "oauth" }), ["codex", "claude"],
        true, false).write, null)
}

// With a CLI that stores sources, the first read moves the widget's own
// sources once, and the read-back reports the move as done.
{
    const widget = { codex: "api", claude: "cli" }
    const first = lib.refresh(lib.syncState(), true)
    let done = lib.read(first.state, first.read, sourceList({ claude: "oauth" }), true, [], widget)
    let sync = done.state
    assert.equal(done.action.type, "write")
    assert.equal(done.action.sourceMigration, true)
    assert.equal(done.action.migration, false)
    assert.deepEqual(plain(done.action.steps), ["set-source --provider codex --source api"])
    done = lib.read(sync, lib.readBack(sync, done.action), sourceList({ claude: "oauth", codex: "api" }),
        true, [], widget)
    assert.equal(done.action.type, "show")
    assert.equal(done.action.sourcesMigrated, true)
    assert.equal(done.state.writing, false)
    // nothing to move: done at once
    const none = lib.read(lib.syncState(), lib.refresh(lib.syncState(), true).read,
        sourceList({ claude: "oauth" }), true, [], { claude: "cli" })
    assert.equal(none.action.type, "show")
    assert.equal(none.action.sourcesMigrated, true)
    // an older CLI, or sources moved before: nothing to report
    const older = lib.read(lib.syncState(), lib.refresh(lib.syncState(), true).read,
        sourceList({}), true, [], null)
    assert.equal(older.action.sourcesMigrated, false)
}

// A fresh widget moves its providers first and its sources right after.
{
    const widget = { claude: "cli" }
    const first = lib.refresh(lib.syncState(), true)
    let done = lib.read(first.state, first.read, sourceList({}, ["codex"]), false, ["codex", "claude"], widget)
    let sync = done.state
    assert.equal(done.action.migration, true)
    assert.deepEqual(plain(done.action.steps), ["enable --provider claude"])
    done = lib.read(sync, lib.readBack(sync, done.action), sourceList({}), false, ["codex", "claude"], widget)
    sync = done.state
    assert.equal(done.action.type, "write")
    assert.equal(done.action.migrated, true)
    assert.equal(done.action.sourceMigration, true)
    assert.deepEqual(plain(done.action.steps), ["set-source --provider claude --source cli"])
    done = lib.read(sync, lib.readBack(sync, done.action), sourceList({ claude: "cli" }), true,
        ["codex", "claude"], widget)
    assert.equal(done.action.type, "show")
    assert.equal(done.action.sourcesMigrated, true)
}

// A failed move keeps the widget's sources for the session: main.qml reads
// back without sources to move, so nothing reports them as moved.
{
    const first = lib.refresh(lib.syncState(), true)
    let done = lib.read(first.state, first.read, sourceList({}), true, [], { codex: "api" })
    const sync = done.state
    done = lib.read(sync, lib.readBack(sync, done.action), sourceList({}), true, [], null)
    assert.equal(done.action.type, "show")
    assert.equal(done.action.sourcesMigrated, false)
}

console.log("Config provider tests passed")
