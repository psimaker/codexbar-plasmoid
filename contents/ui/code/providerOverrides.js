// Per-provider GUI setting overrides ("Provider GUI Settings").
//
// Stored as one JSON string, e.g.
//   {"codex":{"hideCritters":true},"claude":{"panelDisplayMode":"logos"}}
// An absent provider entry, an absent key, or an invalid value means "use the
// global setting". Only ticked values are stored, so editing a global
// setting keeps flowing to every provider that did not override it.
//
// DEFINITIONS describes each overridable setting (section, control kind and
// valid values) and the dialog builds its rows from it; SETTING_KEYS lists
// the keys in dialog order and is what parsing keeps, so a new setting needs
// both. Labels stay in QML so they can be translated. The helpers take either
// the stored string or a map from parse(), so a caller can parse once.
.pragma library

var SECTIONS = ["appearance", "percentage", "critters", "clicks"]

// What a middle or double click on a panel icon does.
var CLICK_ACTIONS = ["none", "refresh", "dashboard", "status", "command"]

var DEFINITIONS = {
    panelDisplayMode: { section: "appearance", control: "enum", values: ["meters", "logos", "logos-and-meters"] },
    showPercentInPanel: { section: "appearance", control: "bool" },
    panelPercentSource: { section: "percentage", control: "enum", values: ["session", "weekly", "lowest"], requires: "showPercentInPanel" },
    percentStyle: { section: "percentage", control: "enum", values: ["remaining", "used"], requires: "showPercentInPanel" },
    showResetCountdown: { section: "percentage", control: "bool", requires: "showPercentInPanel" },
    hideCritters: { section: "critters", control: "bool" },
    middleClickAction: { section: "clicks", control: "enum", values: CLICK_ACTIONS },
    doubleClickAction: { section: "clicks", control: "enum", values: CLICK_ACTIONS },
    launchCommand: { section: "clicks", control: "text" }
}

// Dialog order: section order, then key order within each section.
var SETTING_KEYS = ["panelDisplayMode",
                    "showPercentInPanel", "panelPercentSource",
                    "percentStyle", "showResetCountdown", "hideCritters",
                    "middleClickAction", "doubleClickAction", "launchCommand"]

var DISPLAY_MODES = DEFINITIONS.panelDisplayMode.values
var PERCENT_SOURCES = DEFINITIONS.panelPercentSource.values
var PERCENT_STYLES = DEFINITIONS.percentStyle.values

var DEFAULT_DISPLAY_MODE = "meters"
var DEFAULT_PERCENT_SOURCE = "session"
var DEFAULT_PERCENT_STYLE = "remaining"

function defFor(key) {
    if (typeof key !== "string" || DEFINITIONS[key] === undefined)
        return null
    return DEFINITIONS[key]
}

function keysForSection(section) {
    return SETTING_KEYS.filter(function (key) {
        return DEFINITIONS[key].section === section
    })
}

function isValidDisplayMode(value) {
    return isValidValue("panelDisplayMode", value)
}

function isValidPercentSource(value) {
    return isValidValue("panelPercentSource", value)
}

function isValidPercentStyle(value) {
    return isValidValue("percentStyle", value)
}

function isValidValue(key, value) {
    var def = defFor(key)
    if (def === null)
        return false
    if (def.control === "enum")
        return def.values.indexOf(value) >= 0
    if (def.control === "bool")
        return typeof value === "boolean"
    if (def.control === "text")
        return typeof value === "string" && value.trim().length > 0 && value.length <= 1000
    return false
}

// Drop unknown keys and invalid values; never throws.
function sanitizeEntry(value) {
    var out = {}
    if (value === null || typeof value !== "object" || Array.isArray(value))
        return out
    for (var i = 0; i < SETTING_KEYS.length; i++) {
        var key = SETTING_KEYS[i]
        if (isValidValue(key, value[key]))
            out[key] = value[key]
    }
    return out
}

function parse(raw) {
    var map = {}
    if (typeof raw !== "string" || raw.trim() === "")
        return map
    var decoded = null
    try {
        decoded = JSON.parse(raw)
    } catch (e) {
        return map
    }
    if (decoded === null || typeof decoded !== "object" || Array.isArray(decoded))
        return map
    var ids = Object.keys(decoded)
    for (var i = 0; i < ids.length; i++) {
        var id = ids[i]
        if (typeof id !== "string" || id.length === 0)
            continue
        var entry = sanitizeEntry(decoded[id])
        if (Object.keys(entry).length > 0)
            map[id] = entry
    }
    return map
}

function serialize(map) {
    var out = {}
    if (map !== null && typeof map === "object" && !Array.isArray(map)) {
        var ids = Object.keys(map).sort()
        for (var i = 0; i < ids.length; i++) {
            var entry = sanitizeEntry(map[ids[i]])
            if (Object.keys(entry).length > 0)
                out[ids[i]] = entry
        }
    }
    return JSON.stringify(out)
}

// Override object for one provider ({} when it follows all globals).
function settingsFor(raw, id) {
    var map = raw !== null && typeof raw === "object" ? raw : parse(raw)
    if (typeof id !== "string" || map[id] === undefined)
        return {}
    return map[id]
}

function hasOverride(raw, id) {
    return Object.keys(settingsFor(raw, id)).length > 0
}

// Set several keys at once; unknown keys are ignored, nullish values clear.
function withSettings(raw, id, values) {
    var map = parse(raw)
    if (typeof id !== "string" || id.length === 0)
        return serialize(map)
    var entry = map[id] !== undefined ? map[id] : {}
    var changed = false
    for (var i = 0; i < SETTING_KEYS.length; i++) {
        var key = SETTING_KEYS[i]
        if (values === null || typeof values !== "object" || values[key] === undefined)
            continue
        var value = values[key]
        if (value === null || value === "") {
            if (entry[key] !== undefined) {
                delete entry[key]
                changed = true
            }
        } else if (isValidValue(key, value)) {
            if (entry[key] !== value) {
                entry[key] = value
                changed = true
            }
        }
    }
    if (!changed)
        return serialize(map)
    if (Object.keys(entry).length === 0)
        delete map[id]
    else
        map[id] = entry
    return serialize(map)
}

// Forget every override for one provider ("reset to global").
function resetProvider(raw, id) {
    var map = parse(raw)
    if (typeof id === "string" && map[id] !== undefined)
        delete map[id]
    return serialize(map)
}

// Provider ids that have at least one override, in the given display order;
// ids missing from that order (e.g. dropped from the catalog) follow, sorted.
function overriddenProviders(raw, order) {
    var ids = Object.keys(raw !== null && typeof raw === "object" ? raw : parse(raw))
    var known = Array.isArray(order) ? order : []
    var out = []
    for (var i = 0; i < known.length; i++) {
        if (ids.indexOf(known[i]) >= 0)
            out.push(known[i])
    }
    var rest = ids.filter(function (id) { return out.indexOf(id) < 0 }).sort()
    return out.concat(rest)
}

// Effective values: the override wins only when valid, else the global.
function effectiveDisplayMode(raw, id, globalMode) {
    var entry = settingsFor(raw, id)
    if (isValidDisplayMode(entry.panelDisplayMode))
        return entry.panelDisplayMode
    return isValidDisplayMode(globalMode) ? globalMode : DEFAULT_DISPLAY_MODE
}

function effectiveShowPercent(raw, id, globalShow) {
    var entry = settingsFor(raw, id)
    if (typeof entry.showPercentInPanel === "boolean")
        return entry.showPercentInPanel
    return globalShow === true
}

function effectivePercentSource(raw, id, globalSource) {
    var entry = settingsFor(raw, id)
    if (isValidPercentSource(entry.panelPercentSource))
        return entry.panelPercentSource
    return isValidPercentSource(globalSource) ? globalSource : DEFAULT_PERCENT_SOURCE
}

function effectivePercentStyle(raw, id, globalStyle) {
    var entry = settingsFor(raw, id)
    if (isValidPercentStyle(entry.percentStyle))
        return entry.percentStyle
    return isValidPercentStyle(globalStyle) ? globalStyle : DEFAULT_PERCENT_STYLE
}

function effectiveShowResetCountdown(raw, id, globalShow) {
    var entry = settingsFor(raw, id)
    if (typeof entry.showResetCountdown === "boolean")
        return entry.showResetCountdown
    return globalShow === true
}

function effectiveHideCritters(raw, id, globalHide) {
    var entry = settingsFor(raw, id)
    if (typeof entry.hideCritters === "boolean")
        return entry.hideCritters
    return globalHide === true
}

// Click action of one kind ("middleClickAction" or "doubleClickAction").
function effectiveClickAction(raw, id, key, globalAction) {
    var entry = settingsFor(raw, id)
    if (isValidValue(key, entry[key]))
        return entry[key]
    return isValidValue(key, globalAction) ? globalAction : "none"
}

function effectiveLaunchCommand(raw, id, globalCommand) {
    var entry = settingsFor(raw, id)
    if (isValidValue("launchCommand", entry.launchCommand))
        return entry.launchCommand.trim()
    return typeof globalCommand === "string" ? globalCommand.trim() : ""
}

function normalizeDisplayMode(mode) {
    return isValidDisplayMode(mode) ? mode : DEFAULT_DISPLAY_MODE
}

// True when a provider has any ticked override. Ticking one means "draw this
// provider on its own", even when the value matches the global setting, so it
// can leave the merged meter.
function needsOwnIcon(raw, id) {
    return Object.keys(settingsFor(raw, id)).length > 0
}

// Panel icons for the enabled providers. Per-provider layouts (logo modes or
// one meter per provider) give every provider its own icon. The merged meter
// layout keeps providers that follow the globals in one "__merged__" icon and
// gives only providers with a ticked panel override their own icon.
// Returns { icons: [...], merged: [provider ids aggregated by __merged__] }.
function panelIconModel(raw, enabled, globals, separate) {
    var ids = Array.isArray(enabled) ? enabled : []
    if (ids.length === 0)
        return { icons: ["__merged__"], merged: [] }
    if (separate === true || normalizeDisplayMode(globals.panelDisplayMode) !== "meters")
        return { icons: ids.slice(), merged: [] }
    var merged = []
    var own = []
    for (var i = 0; i < ids.length; i++) {
        if (needsOwnIcon(raw, ids[i]))
            own.push(ids[i])
        else
            merged.push(ids[i])
    }
    return { icons: merged.length > 0 ? ["__merged__"].concat(own) : own, merged: merged }
}
