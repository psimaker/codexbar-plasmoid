import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import "code/catalog.js" as Catalog

PlasmoidItem {
    id: root

    // ---- configuration ----
    readonly property var enabledProviders: {
        var raw = (Plasmoid.configuration.enabledProviders || "").split(",")
        var list = []
        for (var i = 0; i < raw.length; i++) {
            var s = raw[i].trim()
            if (s.length > 0 && Catalog.PROVIDERS[s] !== undefined && list.indexOf(s) < 0)
                list.push(s)
        }
        var order = Catalog.orderedIds()
        list.sort(function (a, b) { return order.indexOf(a) - order.indexOf(b) })
        return list
    }

    // ---- data model ----
    // providerId -> { entry, entries, cost, costUpdatedAt, error, loading, fetchedAt }
    property var usageData: ({})
    property int rev: 0
    property double nowMs: Date.now()
    property string currentTab: ""

    property var pendingUsage: ({})
    property var pendingCost: ({})
    // per-provider request generation: responses from an older generation
    // (e.g. after a config change re-triggered a refresh) are discarded
    property var requestGen: ({})

    // must fit the full representation (19 grid units wide) before switching
    switchWidth: Kirigami.Units.gridUnit * 19
    switchHeight: Kirigami.Units.gridUnit * 16

    toolTipMainText: "CodexBar"
    toolTipSubText: {
        rev
        var lines = []
        for (var i = 0; i < enabledProviders.length; i++) {
            var p = enabledProviders[i]
            var d = usageData[p]
            var m = Catalog.meta(p)
            if (d && d.entry && d.entry.usage) {
                var u = d.entry.usage
                var parts = []
                var pw = Catalog.usableWindow(u.primary)
                var sw = Catalog.usableWindow(u.secondary)
                if (Catalog.windowUsageKnown(pw)) parts.push("Session " + (100 - pw.usedPercent) + "% left")
                if (Catalog.windowUsageKnown(sw)) parts.push("Weekly " + (100 - sw.usedPercent) + "% left")
                lines.push(m.name + " — " + (parts.length > 0 ? parts.join(" · ") : "no data"))
            } else if (d && d.loading) {
                lines.push(m.name + " — refreshing…")
            } else {
                lines.push(m.name + " — no data")
            }
        }
        return lines.join("\n")
    }

    function bump() {
        rev++
    }

    function defaultTab() {
        return enabledProviders.length === 1 ? enabledProviders[0] : "overview"
    }

    function shellQuote(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'"
    }

    function cliCmd(args) {
        var exe = (Plasmoid.configuration.cliPath || "").trim()
        var quoted = exe.length > 0 ? shellQuote(exe) : "codexbar"
        // -k 10: hard-kill if SIGTERM is ignored after the 120s timeout
        return 'PATH="$HOME/.local/bin:$PATH"; timeout -k 10 120 ' + quoted + " " + args + " 2>/dev/null"
    }

    function refreshAll() {
        for (var i = 0; i < enabledProviders.length; i++)
            refreshProvider(enabledProviders[i])
    }

    function refreshProvider(p) {
        if (!usageData[p])
            usageData[p] = {}
        var gen = (requestGen[p] || 0) + 1
        requestGen[p] = gen
        usageData[p].loading = true
        bump()

        var cmd = cliCmd("usage --provider " + p + " --json" + (Plasmoid.configuration.showStatus ? " --status" : ""))
        pendingUsage[cmd] = { p: p, gen: gen }
        executable.connectSource(cmd)

        if (Plasmoid.configuration.showCost && Catalog.COST_PROVIDERS.indexOf(p) >= 0) {
            var costCmd = cliCmd("cost --provider " + p + " --json")
            pendingCost[costCmd] = { p: p, gen: gen }
            executable.connectSource(costCmd)
        }
    }

    function usageErrorText(exitCode, parseFailed) {
        if (exitCode === 124 || exitCode === 137)
            return "Timed out querying the codexbar CLI"
        if (exitCode === 127)
            return "codexbar CLI not found — set the path in the settings"
        if (parseFailed)
            return "Unexpected codexbar output (JSON parse failed)"
        if (exitCode === 0)
            return "No usage data available"
        return "No usage data — check codexbar login/config (exit " + exitCode + ")"
    }

    function handleData(source, exitCode, stdout) {
        var req = pendingUsage[source]
        if (req !== undefined) {
            delete pendingUsage[source]
            if (requestGen[req.p] !== req.gen)
                return // stale response from an older refresh
            var d = usageData[req.p]
            if (!d)
                d = usageData[req.p] = {}
            d.loading = false
            d.fetchedAt = Date.now()

            var trimmed = (stdout || "").trim()
            var parsed = null
            var parseFailed = false
            if (trimmed.length > 0) {
                try { parsed = JSON.parse(trimmed) } catch (e) { parseFailed = true }
            }
            if (parsed && parsed.length > 0 && parsed[0].usage) {
                d.entry = parsed[0]
                d.entries = parsed
                d.error = ""
            } else {
                d.error = usageErrorText(exitCode, parseFailed)
            }
            bump()
            return
        }

        var creq = pendingCost[source]
        if (creq !== undefined) {
            delete pendingCost[source]
            if (requestGen[creq.p] !== creq.gen)
                return
            var dc = usageData[creq.p]
            if (!dc)
                dc = usageData[creq.p] = {}
            var pc = null
            try { pc = JSON.parse((stdout || "").trim()) } catch (e2) { pc = null }
            if (pc && pc.length > 0) {
                dc.cost = pc[0]
                dc.costUpdatedAt = Date.now()
            } else {
                // drop stale cost data instead of showing outdated numbers forever
                dc.cost = null
                dc.costUpdatedAt = 0
            }
            bump()
        }
    }

    // remaining percent for the panel icon / percent label; -1 = unknown
    function remainingPercent(p, source) {
        rev
        var d = usageData[p]
        if (!d || !d.entry || !d.entry.usage)
            return -1
        var u = d.entry.usage
        var pw = Catalog.usableWindow(u.primary)
        var sw = Catalog.usableWindow(u.secondary)
        var rp = Catalog.windowUsageKnown(pw) ? 100 - pw.usedPercent : -1
        var rs = Catalog.windowUsageKnown(sw) ? 100 - sw.usedPercent : -1
        if (source === "weekly")
            return rs >= 0 ? rs : rp
        if (source === "lowest") {
            var c = []
            if (rp >= 0) c.push(rp)
            if (rs >= 0) c.push(rs)
            return c.length > 0 ? Math.min.apply(null, c) : -1
        }
        return rp >= 0 ? rp : rs
    }

    function isStale(p) {
        rev
        var d = usageData[p]
        if (!d || !d.fetchedAt)
            return true
        if (d.error && d.error.length > 0)
            return true
        var maxAge = Math.max(1, Plasmoid.configuration.refreshIntervalMinutes) * 60000 * 3
        return (Date.now() - d.fetchedAt) > maxAge
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            var stdout = data["stdout"] !== undefined ? data["stdout"] : ""
            var exitCode = data["exit code"] !== undefined ? data["exit code"] : -1
            executable.disconnectSource(sourceName)
            root.handleData(sourceName, exitCode, stdout)
        }
    }

    Timer {
        // drives "Resets in …" countdowns and staleness
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            root.nowMs = Date.now()
            root.bump()
        }
    }

    Timer {
        id: refreshTimer
        interval: Math.max(1, Plasmoid.configuration.refreshIntervalMinutes) * 60000
        running: true
        repeat: true
        onTriggered: root.refreshAll()
    }

    Component.onCompleted: {
        currentTab = defaultTab()
        refreshAll()
    }

    onEnabledProvidersChanged: {
        var valid = currentTab === "about"
                || (currentTab === "overview" && enabledProviders.length > 1)
                || enabledProviders.indexOf(currentTab) >= 0
        if (!valid)
            currentTab = defaultTab()
        refreshAll()
    }

    onExpandedChanged: {
        if (expanded && (currentTab === "" || currentTab === "about"))
            currentTab = defaultTab()
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh")
            icon.name: "view-refresh-symbolic"
            onTriggered: root.refreshAll()
        }
    ]

    compactRepresentation: CompactBar {
        plasmoidRoot: root
    }

    fullRepresentation: FullView {
        plasmoidRoot: root
    }
}
