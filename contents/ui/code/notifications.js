// Opt-in notifications, with the transition rules of upstream's Linux app
// (Integrations/Linux/Shared/Notifications.js): only changes seen while the
// widget runs count, so nothing is announced on startup, for a provider
// whose probe failed or right after it recovers, or for a provider that
// reports several accounts.
.pragma library

var STATUS_LEVELS = ["none", "minor", "major", "critical", "maintenance"]
var DEFAULT_THRESHOLD = 10

function threshold(value) {
    var n = Math.round(Number(value))
    return isFinite(n) && n > 0 ? Math.max(1, Math.min(99, n)) : DEFAULT_THRESHOLD
}

// One provider's answer. row is { failed, windows: [{ key, label,
// remaining, resetsAt }], statusLevel } (failed when the probe failed or the
// CLI reported more than one account). options is { threshold, quota,
// status }: which events to report. The state is kept either way, so
// turning notifications on does not start from nothing.
// Returns { state, events }; events are { kind: "low" | "reset" | "status",
// provider, label, remaining, level }.
function transition(previous, provider, row, options) {
    var prefix = provider + "/"
    var state = {}
    for (var key in previous) {
        if (key.indexOf(prefix) !== 0)
            state[key] = previous[key]
    }
    var events = []
    if (!row || row.failed)
        return { state: state, events: events }
    var opts = options || {}
    var limit = threshold(opts.threshold)
    var windows = row.windows || []
    for (var i = 0; i < windows.length; i++) {
        var w = windows[i]
        var windowKey = prefix + w.key
        var old = previous[windowKey]
        var reset = typeof w.resetsAt === "string" ? w.resetsAt : ""
        state[windowKey] = { remaining: w.remaining, reset: reset }
        if (!old || opts.quota !== true)
            continue
        if (old.remaining > limit && w.remaining <= limit) {
            events.push({ kind: "low", provider: provider, label: w.label, remaining: w.remaining })
        } else if (old.reset !== "" && reset !== "" && old.reset !== reset && w.remaining > old.remaining) {
            events.push({ kind: "reset", provider: provider, label: w.label, remaining: w.remaining })
        }
    }
    var level = row.statusLevel
    if (STATUS_LEVELS.indexOf(level) >= 0) {
        var statusKey = prefix + "status"
        var before = previous[statusKey]
        state[statusKey] = { level: level }
        if (before && before.level !== level && opts.status === true)
            events.push({ kind: "status", provider: provider, level: level })
    }
    return { state: state, events: events }
}
