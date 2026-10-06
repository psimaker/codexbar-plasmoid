// CodexBar's config.json decides which providers exist and which are enabled
// (#25). `codexbar config providers --json` lists them by CodexBar's internal
// id; the widget keys providers by their --provider name, so callers pass the
// id mapping (Catalog.cliProviderId).
.pragma library

// Outputs of `config providers --json` and `config dump --json` as
// [{ id, name, enabled, defaultEnabled, source }] in the CLI's order, or null
// when the first is no provider list: not JSON, not an array, no provider in
// it, or an error entry such as the one the CLI prints for a config.json it
// cannot decode. A dump that cannot be read leaves every source at "auto".
function parse(providersJson, dumpJson, toCliId) {
    var list = null
    try {
        list = JSON.parse(providersJson)
    } catch (e) {
        return null
    }
    if (!Array.isArray(list))
        return null
    var sources = {}
    try {
        var dump = JSON.parse(dumpJson)
        var entries = dump && Array.isArray(dump.providers) ? dump.providers : []
        for (var d = 0; d < entries.length; d++) {
            var entry = entries[d]
            if (entry && typeof entry.id === "string" && typeof entry.source === "string")
                sources[entry.id] = entry.source
        }
    } catch (e) {
        // no sources; keep "auto"
    }
    var out = []
    for (var i = 0; i < list.length; i++) {
        var p = list[i]
        if (p && p.error)
            return null
        if (!p || typeof p.provider !== "string" || p.provider === "")
            continue
        out.push({
            id: toCliId(p.provider),
            name: typeof p.displayName === "string" && p.displayName !== "" ? p.displayName : p.provider,
            enabled: p.enabled === true,
            defaultEnabled: p.defaultEnabled === true,
            source: sources[p.provider] || "auto"
        })
    }
    return out.length > 0 ? out : null
}

function enabledIds(list) {
    return (list || []).filter(function (p) { return p.enabled }).map(function (p) { return p.id })
}

// CodexBar's default selection, which config.json has until it is changed.
function defaultIds(list) {
    return (list || []).filter(function (p) { return p.defaultEnabled }).map(function (p) { return p.id })
}

// Whether both lists hold the same ids, in whatever order.
function sameIds(a, b) {
    function within(x, y) { return x.every(function (id) { return y.indexOf(id) >= 0 }) }
    return within(a, b) && within(b, a)
}

// What config.json enables after the one-time move of the widget's own list
// (#25), in list order. While config.json still has CodexBar's default
// selection, the widget's providers are added and none is disabled; once it
// was changed, config.json wins as it is. A config.json set back to the
// defaults on purpose looks untouched, so it still gets the widget's list.
function migratedIds(list, widgetIds) {
    var ids = widgetIds || []
    var add = sameIds(enabledIds(list), defaultIds(list))
    return (list || []).filter(function (p) {
        return p.enabled || (add && ids.indexOf(p.id) >= 0)
    }).map(function (p) { return p.id })
}

// `config` subcommands that make config.json enable exactly the wanted ids,
// in list order. Wanted ids the config does not know are ignored.
function changes(list, wanted) {
    var out = []
    var ids = wanted || []
    for (var i = 0; i < (list || []).length; i++) {
        var want = ids.indexOf(list[i].id) >= 0
        if (want !== list[i].enabled)
            out.push((want ? "enable" : "disable") + " --provider " + list[i].id)
    }
    return out
}

// Data sources the widget offers besides "auto" (ProviderSources.SOURCES).
// A stored source it does not know stays until another one is picked.
var SETTABLE_SOURCES = ["web", "cli", "oauth", "api"]

// The sources config.json stores, as { id: source } without "auto" and
// without sources the widget does not know: what the settings page mirrors
// once config.json holds the sources (CodexBar 0.72.1).
function storedSources(list) {
    var out = {}
    for (var i = 0; i < (list || []).length; i++) {
        if (SETTABLE_SOURCES.indexOf(list[i].source) >= 0)
            out[list[i].id] = list[i].source
    }
    return out
}

// `config set-source` subcommands that make config.json store the wanted
// sources ({ id: source }, "auto" for a provider left out), in list order.
function sourceChanges(list, wanted) {
    var out = []
    var sources = wanted || {}
    for (var i = 0; i < (list || []).length; i++) {
        var entry = list[i]
        var want = sources[entry.id] || "auto"
        var known = entry.source === "auto" || SETTABLE_SOURCES.indexOf(entry.source) >= 0
        if (want === entry.source || (!known && want === "auto"))
            continue
        out.push("set-source --provider " + entry.id + " --source " + want)
    }
    return out
}

// The sources config.json stores after the widget's own choices (its
// --source overrides) move there once: a provider without a stored source
// takes the widget's, and a stored source wins.
function migratedSources(list, widgetSources) {
    var out = storedSources(list)
    var own = widgetSources || {}
    for (var i = 0; i < (list || []).length; i++) {
        var id = list[i].id
        if (list[i].source === "auto" && own[id] !== undefined)
            out[id] = own[id]
    }
    return out
}

// The selection a settings page saves when it started from the enabled ids
// `base`, shows `chosen`, and the settings now hold `current`: providers
// ticked or unticked on the page change `current`, the others keep their
// state there. Newly ticked ids follow current's.
function rebaseSelection(base, chosen, current) {
    var out = (current || []).filter(function (id) {
        return !(base.indexOf(id) >= 0 && chosen.indexOf(id) < 0)
    })
    for (var i = 0; i < chosen.length; i++) {
        if (base.indexOf(chosen[i]) < 0 && out.indexOf(chosen[i]) < 0)
            out.push(chosen[i])
    }
    return out
}

// The CLI's error in the output of `config enable|disable --json` steps run
// one after the other: the step that failed prints an error entry, such as
// [{"provider":"cli","error":{"message":"Permission denied"}}], after the
// results of the steps before it. Empty when there is none.
function writeError(output) {
    var lines = String(output || "").split("\n")
    for (var i = lines.length - 1; i >= 0; i--) {
        var parsed = null
        try {
            parsed = JSON.parse(lines[i])
        } catch (e) {
            continue
        }
        var entries = Array.isArray(parsed) ? parsed : [parsed]
        for (var j = 0; j < entries.length; j++) {
            var error = entries[j] && entries[j].error
            if (error && typeof error.message === "string" && error.message.trim() !== "")
                return error.message.trim()
        }
    }
    return ""
}

// ---- one write at a time ----
// The widget changes config.json with one write at a time and reads it back
// after each. A selection applied while a write runs waits, and a newer one
// replaces it, so the latest Apply wins. A refresh meanwhile waits for the
// read-back, and a read that started before a write is dropped, because it
// may show config.json from before the write. This orders the widget's own
// reads and writes only; the CLI, the app and other widgets write on their own.
//
// State: serial counts the writes, writing covers a write and its read-back,
// queued is { wanted, sources, force } waiting for them, and force remembers
// that a refresh that waited or was dropped wanted crash-blocked providers
// probed. Reads carry a token { serial, force, readBack, migration,
// sourceMigration }.

function syncState() {
    return { serial: 0, writing: false, queued: null, force: false }
}

// A refresh wants config.json read. Returns { state, read }: read is the
// token for the read to start, or null while a write runs.
function refresh(state, force) {
    if (state.writing)
        return { state: Object.assign({}, state, { force: state.force || force === true }), read: null }
    return {
        state: state,
        read: { serial: state.serial, force: force === true, readBack: false, migration: false, sourceMigration: false }
    }
}

function startWrite(state, steps, force, migration, sourceMigration) {
    return {
        state: Object.assign({}, state, { serial: state.serial + 1, writing: true }),
        write: { steps: steps, force: force === true, migration: migration === true,
                 sourceMigration: sourceMigration === true }
    }
}

// Make config.json, last read as `list`, enable exactly `wanted` and, when
// `sources` is given, store those sources (as sourceChanges takes them).
// Returns { state, write }: write is { steps, force, migration,
// sourceMigration } to run now, or null when nothing has to change or a
// running write makes it wait.
function request(state, list, wanted, force, migration, sources) {
    if (state.writing) {
        var queued = {
            wanted: (wanted || []).slice(),
            sources: sources ? Object.assign({}, sources) : null,
            force: force === true
        }
        return { state: Object.assign({}, state, { queued: queued }), write: null }
    }
    var steps = changes(list, wanted)
    if (sources)
        steps = steps.concat(sourceChanges(list, sources))
    if (steps.length === 0)
        return { state: state, write: null }
    return startWrite(state, steps, force, migration, false)
}

// The token for the read-back after `write`, whether it worked or not.
function readBack(state, write) {
    return {
        serial: state.serial, force: write.force, readBack: true, migration: write.migration,
        sourceMigration: write.sourceMigration === true
    }
}

// A failed migration write leaves config mode for the session: the write is
// over and nothing waits for it. Returns { state, force } for the probe.
function abandon(state, write) {
    return {
        state: Object.assign({}, state, { writing: false, queued: null, force: false }),
        force: write.force || state.force
    }
}

// The CLI is checked again, and the old check's write and read-back results
// will be dropped, so stop waiting for them. A waiting selection stays.
function restart(state) {
    return Object.assign({}, state, { writing: false, force: false })
}

// A read finished with `list`, or null when config.json could not be read.
// `migrated` says whether the widget's own list was moved to config.json
// (#25), `widgetIds` is that list. `widgetSources` is the widget's own
// { id: source } while they still have to move to config.json (CLI 0.72.1
// or newer), else null. Returns { state, action }, by action.type:
//   drop   a write started after this read did, so it may be outdated
//   leave  unreadable: keep the widget's own list and probe (action.force)
//   write  run action.steps (a write as from request) before showing anything
//   show   mirror the list and probe (action.force)
// action.migrated on write and show says the list migration is done now,
// action.sourcesMigrated on show the same for the sources.
function read(state, token, list, migrated, widgetIds, widgetSources) {
    if (!token.readBack && (state.writing || token.serial !== state.serial))
        return { state: Object.assign({}, state, { force: state.force || token.force }), action: { type: "drop" } }
    var force = token.force || state.force
    var next = Object.assign({}, state, { writing: false, force: false })
    if (list === null) {
        next.queued = null
        return { state: next, action: { type: "leave", force: force } }
    }
    if (!migrated && !token.migration) {
        // Once, the widget's own providers are added to a config.json that
        // still has CodexBar's defaults; a changed one wins.
        var move = request(next, list, migratedIds(list, widgetIds), force, true)
        if (move.write)
            return { state: move.state, action: Object.assign({ type: "write", migrated: false }, move.write) }
    }
    var moveSources = widgetSources !== null && widgetSources !== undefined
    if (moveSources && !token.sourceMigration) {
        // Once, the widget's sources go to providers without a stored one.
        var steps = sourceChanges(list, migratedSources(list, widgetSources))
        if (steps.length > 0) {
            var sourceMove = startWrite(next, steps, force, false, true)
            return {
                state: sourceMove.state,
                action: Object.assign({ type: "write", migrated: !migrated }, sourceMove.write)
            }
        }
    }
    if (next.queued !== null) {
        var queued = next.queued
        next.queued = null
        var apply = request(next, list, queued.wanted, queued.force || force, false, queued.sources)
        if (apply.write)
            return { state: apply.state, action: Object.assign({ type: "write", migrated: !migrated }, apply.write) }
    }
    return { state: next, action: { type: "show", force: force, migrated: !migrated, sourcesMigrated: moveSources } }
}
