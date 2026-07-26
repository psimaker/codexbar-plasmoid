import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import "code/catalog.js" as Catalog
import "code/claudeAccounts.js" as ClaudeAccounts

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
    property string costRefreshInFlight: ""
    property string costSourceInFlight: ""
    property var lastCostAttemptAt: ({})
    readonly property int costAutoRefreshIntervalMs: 60 * 60 * 1000
    readonly property int costSchedulerIntervalMs: 5 * 60 * 1000
    readonly property bool costEnabled: Plasmoid.configuration.showCost
    // Providers whose CLI process died with SIGSEGV are skipped by automatic
    // refreshes. A manual refresh still retries after the CLI was upgraded.
    property var autoRefreshBlocked: ({})
    // per-provider request generation: responses from an older generation
    // (e.g. after a config change re-triggered a refresh) are discarded
    property var requestGen: ({})

    // Optional schema-v1 claude-swap-compatible adapter state. Normal Claude
    // usage/cost queries remain active for the panel, overview and fallback UI.
    readonly property bool claudeAccountsEnabled:
        Plasmoid.configuration.enableClaudeAccounts
        && enabledProviders.indexOf("claude") >= 0
    readonly property string claudeAdapterExecutable: {
        var configured = (Plasmoid.configuration.claudeAdapterPath || "").trim()
        return configured.length > 0 ? configured : "cswap"
    }
    property var claudeAccountData: ({
        valid: false,
        accounts: [],
        activeAccountNumber: null,
        loading: false,
        error: "",
        switchError: "",
        fetchedAt: 0
    })
    property var pendingClaudeList: ({})
    property var pendingClaudeSwitch: ({})
    property int claudeAdapterGen: 0
    property int claudeListGen: 0
    property bool claudeSwitchInFlight: false
    property int claudeSwitchingSlot: 0
    property bool componentReady: false

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
                var pw = Catalog.windowFor(u, p, 300)
                var sw = Catalog.windowFor(u, p, 10080)
                if (Catalog.windowUsageKnown(pw)) parts.push("Session " + (100 - Catalog.normalizedPercent(pw.usedPercent)) + "% left")
                if (Catalog.windowUsageKnown(sw)) parts.push("Weekly " + (100 - Catalog.normalizedPercent(sw.usedPercent)) + "% left")
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

    function shellQuoteExecutable(s) {
        // A settings UI commonly receives ~/.local/bin/...; expand only this
        // leading home shorthand and quote the entire remaining path.
        if (s.indexOf("~/") === 0)
            return '"$HOME"/' + shellQuote(s.substring(2))
        return shellQuote(s)
    }

    function cliCmd(args) {
        var exe = (Plasmoid.configuration.cliPath || "").trim()
        var quoted = exe.length > 0 ? shellQuote(exe) : "codexbar"
        // -k 10: hard-kill if SIGTERM is ignored after the 120s timeout
        return 'PATH="$HOME/.local/bin:$PATH"; timeout -k 10 120 ' + quoted + " " + args + " 2>/dev/null"
    }

    function claudeAdapterCmd(operation, slot) {
        var quoted = shellQuoteExecutable(claudeAdapterExecutable)
        var prefix = 'PATH="$HOME/.local/bin:$PATH"; '
        if (operation === "list") {
            // Bound what Plasma's executable data engine can capture, while
            // retaining one extra byte so the parser can report overflow.
            var pipeline = quoted + " --list --json 2>/dev/null | head -c "
                + (ClaudeAccounts.MAX_OUTPUT_BYTES + 1)
            return prefix + "timeout -k 5 30 sh -c " + shellQuote(pipeline)
        }
        if (operation === "switch" && typeof slot === "number" && isFinite(slot)
                && Math.floor(slot) === slot && slot > 0) {
            // Bound the switch like the list probe so a hung adapter (credential
            // lock, keychain prompt, or backend call) cannot leave
            // claudeSwitchInFlight set and disable every switch button until
            // the plasmoid is reloaded.
            return prefix + "timeout -k 5 30 " + quoted + " --switch-to " + slot + " --json 2>/dev/null"
        }
        return ""
    }

    function updateClaudeAccountData(changes) {
        claudeAccountData = Object.assign({}, claudeAccountData, changes)
        bump()
    }

    function clearClaudeAccountData() {
        claudeAccountData = {
            valid: false,
            accounts: [],
            activeAccountNumber: null,
            loading: false,
            error: "",
            switchError: "",
            fetchedAt: 0
        }
        bump()
    }

    function refreshClaudeAccounts() {
        if (!claudeAccountsEnabled || claudeSwitchInFlight)
            return
        var cmd = claudeAdapterCmd("list", 0)
        if (cmd === "" || pendingClaudeList[cmd] !== undefined)
            return
        var listGen = ++claudeListGen
        pendingClaudeList[cmd] = { adapterGen: claudeAdapterGen, listGen: listGen }
        updateClaudeAccountData({ loading: true })
        executable.connectSource(cmd)
    }

    function claudeAdapterErrorText(exitCode, parseError) {
        if (exitCode === 124 || exitCode === 137)
            return "Timed out querying the Claude account adapter."
        if (exitCode === 127)
            return "Claude account adapter not found — set its executable path in the settings."
        if (parseError && parseError.length > 0)
            return parseError
        if (exitCode === 0)
            return "The Claude account adapter returned no account data."
        return "Claude account adapter failed (exit " + exitCode + ")."
    }

    function claudeAccountForSlot(slot) {
        var accounts = claudeAccountData.accounts || []
        for (var i = 0; i < accounts.length; i++) {
            if (accounts[i].number === slot)
                return accounts[i]
        }
        return null
    }

    function canSwitchClaudeAccount(account) {
        return claudeAccountsEnabled && claudeAccountData.valid
            && !claudeAccountData.loading && !claudeSwitchInFlight
            && ClaudeAccounts.canActivate(account)
    }

    function switchClaudeAccount(slot) {
        if (claudeSwitchInFlight || typeof slot !== "number" || !isFinite(slot)
                || Math.floor(slot) !== slot || slot <= 0)
            return
        var account = claudeAccountForSlot(slot)
        if (!canSwitchClaudeAccount(account))
            return
        var cmd = claudeAdapterCmd("switch", slot)
        if (cmd === "" || pendingClaudeSwitch[cmd] !== undefined)
            return
        claudeSwitchInFlight = true
        claudeSwitchingSlot = slot
        updateClaudeAccountData({ switchError: "" })
        pendingClaudeSwitch[cmd] = { adapterGen: claudeAdapterGen, slot: slot }
        executable.connectSource(cmd)
    }

    // Per-account staleness: prefer the adapter's reported usage measurement
    // time, falling back to the dataset poll timestamp when the adapter did
    // not report freshness. This keeps cached/last-known usage from reading as
    // fresh just because the widget polled again.
    function isClaudeAccountStale(account) {
        rev
        if (!claudeAccountData.valid)
            return true
        var ts = (account && typeof account.usageMeasuredAt === "number")
            ? account.usageMeasuredAt : claudeAccountData.fetchedAt
        if (!ts)
            return true
        var maxAge = Math.max(1, Plasmoid.configuration.refreshIntervalMinutes) * 60000 * 3
        return (Date.now() - ts) > maxAge
    }

    function refreshAll(force) {
        for (var i = 0; i < enabledProviders.length; i++) {
            var provider = enabledProviders[i]
            if (force === true || !autoRefreshBlocked[provider])
                refreshProvider(provider)
        }
        // The account adapter is a separate executable from the codexbar CLI,
        // so a CLI crash block must not suppress its polling.
        refreshClaudeAccounts()
    }

    function supportsCost(p) {
        return Catalog.COST_PROVIDERS.indexOf(p) >= 0
    }

    function deferAutomaticCostScans() {
        var attempts = Object.assign({}, lastCostAttemptAt)
        var now = Date.now()
        for (var i = 0; i < enabledProviders.length; i++) {
            var provider = enabledProviders[i]
            if (supportsCost(provider) && typeof attempts[provider] !== "number")
                attempts[provider] = now
        }
        lastCostAttemptAt = attempts
    }

    function canRefreshCost(p) {
        return costEnabled && supportsCost(p)
            && enabledProviders.indexOf(p) >= 0
            && costRefreshInFlight === ""
    }

    function refreshCost(p, force) {
        if (!canRefreshCost(p))
            return false

        var now = Date.now()
        var previousAttempt = lastCostAttemptAt[p]
        if (force !== true && typeof previousAttempt === "number"
                && now - previousAttempt < costAutoRefreshIntervalMs)
            return false

        var attempts = Object.assign({}, lastCostAttemptAt)
        attempts[p] = now
        lastCostAttemptAt = attempts

        if (!usageData[p])
            usageData[p] = {}
        usageData[p].costLoading = true
        bump()

        var costCmd = cliCmd("cost --provider " + p + " --json")
        pendingCost[costCmd] = { p: p }
        costRefreshInFlight = p
        costSourceInFlight = costCmd
        executable.connectSource(costCmd)
        return true
    }

    function refreshNextCost() {
        if (!costEnabled || costRefreshInFlight !== "")
            return
        for (var i = 0; i < enabledProviders.length; i++) {
            if (refreshCost(enabledProviders[i], false))
                return
        }
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
    }

    function usageErrorText(exitCode, parseFailed) {
        if (exitCode === 124 || exitCode === 137)
            return "Timed out querying the codexbar CLI"
        if (exitCode === 139)
            return "codexbar CLI crashed (SIGSEGV) — update to v0.43.0 or newer, then refresh manually"
        if (exitCode === 127)
            return "codexbar CLI not found — set the path in the settings"
        if (parseFailed)
            return "Unexpected codexbar output (JSON parse failed)"
        if (exitCode === 0)
            return "No usage data available"
        return "No usage data — check codexbar login/config (exit " + exitCode + ")"
    }

    function handleData(source, exitCode, stdout) {
        var accountReq = pendingClaudeList[source]
        if (accountReq !== undefined) {
            delete pendingClaudeList[source]
            if (accountReq.adapterGen !== claudeAdapterGen || accountReq.listGen !== claudeListGen) {
                // A disable/re-enable or path edit may resolve to the same
                // command string. Once the old source is disconnected, start
                // the fresh generation that was previously de-duplicated.
                if (claudeAccountsEnabled)
                    refreshClaudeAccounts()
                return
            }
            var listNowMs = Date.now()
            var parsedAccounts = (exitCode === 124 || exitCode === 137)
                ? { ok: false, error: "" }
                : ClaudeAccounts.parseList(stdout, listNowMs)
            if (parsedAccounts.ok) {
                updateClaudeAccountData({
                    valid: true,
                    accounts: parsedAccounts.value.accounts,
                    activeAccountNumber: parsedAccounts.value.activeAccountNumber,
                    loading: false,
                    error: "",
                    fetchedAt: listNowMs
                })
            } else {
                updateClaudeAccountData({
                    loading: false,
                    error: claudeAdapterErrorText(exitCode, parsedAccounts.error)
                })
            }
            return
        }

        var switchReq = pendingClaudeSwitch[source]
        if (switchReq !== undefined) {
            delete pendingClaudeSwitch[source]
            claudeSwitchInFlight = false
            claudeSwitchingSlot = 0
            if (switchReq.adapterGen === claudeAdapterGen) {
                var parsedSwitch = ClaudeAccounts.parseSwitch(stdout, switchReq.slot)
                updateClaudeAccountData({
                    switchError: parsedSwitch.ok ? ""
                        : claudeAdapterErrorText(exitCode, parsedSwitch.error)
                })
            } else {
                bump()
            }
            // Switching affects both the adapter projection and the ambient
            // Claude snapshot used by panel/overview/status/cost UI.
            if (enabledProviders.indexOf("claude") >= 0)
                refreshProvider("claude")
            refreshClaudeAccounts()
            return
        }

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

            if (exitCode === 139)
                autoRefreshBlocked[req.p] = true
            else
                delete autoRefreshBlocked[req.p]

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
            if (costSourceInFlight === source) {
                costRefreshInFlight = ""
                costSourceInFlight = ""
            }
            var dc = usageData[creq.p]
            if (!dc)
                dc = usageData[creq.p] = {}
            dc.costLoading = false
            var pc = null
            try { pc = JSON.parse((stdout || "").trim()) } catch (e2) { pc = null }
            if (exitCode === 0 && pc && pc.length > 0) {
                dc.cost = pc[0]
                dc.costUpdatedAt = Date.now()
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
        var pw = Catalog.windowFor(u, p, 300)
        var sw = Catalog.windowFor(u, p, 10080)
        var rp = Catalog.windowUsageKnown(pw) ? 100 - Catalog.normalizedPercent(pw.usedPercent) : -1
        var rs = Catalog.windowUsageKnown(sw) ? 100 - Catalog.normalizedPercent(sw.usedPercent) : -1
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
        onTriggered: root.refreshAll(false)
    }

    Timer {
        id: costRefreshTimer
        interval: root.costSchedulerIntervalMs
        running: root.costEnabled
        repeat: true
        onTriggered: root.refreshNextCost()
    }

    Component.onCompleted: {
        componentReady = true
        currentTab = defaultTab()
        deferAutomaticCostScans()
        refreshAll(false)
    }

    onClaudeAccountsEnabledChanged: {
        if (!componentReady)
            return
        claudeAdapterGen++
        claudeListGen++
        clearClaudeAccountData()
        if (claudeAccountsEnabled)
            refreshClaudeAccounts()
    }

    onClaudeAdapterExecutableChanged: {
        if (!componentReady)
            return
        claudeAdapterGen++
        claudeListGen++
        clearClaudeAccountData()
        if (claudeAccountsEnabled)
            refreshClaudeAccounts()
    }

    onEnabledProvidersChanged: {
        var valid = currentTab === "about"
                || (currentTab === "overview" && enabledProviders.length > 1)
                || enabledProviders.indexOf(currentTab) >= 0
        if (!valid)
            currentTab = defaultTab()
        deferAutomaticCostScans()
        refreshAll(true)
    }

    onCostEnabledChanged: {
        if (costEnabled)
            deferAutomaticCostScans()
    }

    onExpandedChanged: {
        if (expanded && (currentTab === "" || currentTab === "about"))
            currentTab = defaultTab()
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh")
            icon.name: "view-refresh-symbolic"
            onTriggered: root.refreshAll(true)
        },
        PlasmaCore.Action {
            text: root.costRefreshInFlight === root.currentTab
                  ? i18n("Refreshing cost history…")
                  : i18n("Refresh cost history")
            icon.name: "view-refresh-symbolic"
            visible: root.costEnabled && root.supportsCost(root.currentTab)
            enabled: root.canRefreshCost(root.currentTab)
            onTriggered: root.refreshCost(root.currentTab, true)
        }
    ]

    compactRepresentation: CompactBar {
        plasmoidRoot: root
    }

    fullRepresentation: FullView {
        plasmoidRoot: root
    }
}
