// Per-provider `--source` selection for `codexbar usage`.
//
// The setting is stored as one string ("opencodego=api,claude=oauth") so the
// Providers page can own it without a parallel config tree. Unknown providers
// and unknown sources are dropped on read; "auto" is never stored because it
// is the CLI default.
.pragma library

var SOURCES = ["auto", "web", "cli", "oauth", "api"]
var DEFAULT_SOURCE = "auto"

function isValidSource(source) {
    return SOURCES.indexOf(source) >= 0
}

function parse(raw) {
    var map = {}
    if (typeof raw !== "string")
        return map
    var parts = raw.split(",")
    for (var i = 0; i < parts.length; i++) {
        var pair = parts[i].trim()
        var eq = pair.indexOf("=")
        if (eq <= 0)
            continue
        var id = pair.substring(0, eq).trim()
        var source = pair.substring(eq + 1).trim().toLowerCase()
        if (id.length === 0 || !isValidSource(source) || source === DEFAULT_SOURCE)
            continue
        map[id] = source
    }
    return map
}

function serialize(map) {
    var ids = Object.keys(map).sort()
    var parts = []
    for (var i = 0; i < ids.length; i++) {
        var source = map[ids[i]]
        if (isValidSource(source) && source !== DEFAULT_SOURCE)
            parts.push(ids[i] + "=" + source)
    }
    return parts.join(",")
}

function sourceFor(raw, id) {
    var map = parse(raw)
    return map[id] || DEFAULT_SOURCE
}

function withSource(raw, id, source) {
    var map = parse(raw)
    if (typeof id !== "string" || id.length === 0)
        return serialize(map)
    if (!isValidSource(source) || source === DEFAULT_SOURCE)
        delete map[id]
    else
        map[id] = source
    return serialize(map)
}

// Extra CLI arguments for one provider ("" for the CLI default).
function cliArguments(raw, id) {
    var source = sourceFor(raw, id)
    return source === DEFAULT_SOURCE ? "" : " --source " + source
}

// The sources a settings page saves when it started from `base`, shows
// `chosen`, and the settings now hold `current` (all raw strings): a source
// changed on the page keeps the page's choice, the others take current's.
function rebase(base, chosen, current) {
    var from = parse(base)
    var mine = parse(chosen)
    var now = parse(current)
    var ids = Object.keys(from).concat(Object.keys(mine), Object.keys(now))
    var out = {}
    for (var i = 0; i < ids.length; i++) {
        var id = ids[i]
        var changed = (mine[id] || DEFAULT_SOURCE) !== (from[id] || DEFAULT_SOURCE)
        var source = changed ? mine[id] : now[id]
        if (source !== undefined)
            out[id] = source
    }
    return serialize(out)
}
