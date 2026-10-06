import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import "code/catalog.js" as Catalog
import "code/claudeAccounts.js" as ClaudeAccounts
import "code/cliStatus.js" as CliStatus
import "code/configProviders.js" as ConfigProviders
import "code/providerSources.js" as ProviderSources

PlasmoidItem {
    id: root

    // ---- configuration ----
    // CodexBar's config.json decides which providers are enabled once the CLI
    // can read and safely write it (#25): [{ id, name, enabled, source }], or
    // null while the widget's own enabledProviders list applies.
    property var configProviderList: null
    readonly property bool configMode: configProviderList !== null
    readonly property var enabledProviders: {
        var list = configProviderList !== null
            ? ConfigProviders.enabledIds(configProviderList)
            : keyProviderIds().filter(function (id) { return Catalog.PROVIDERS[id] !== undefined })
        // Catalog order first; providers the catalog does not know, such as
        // user plugins, follow in CodexBar's order.
        var order = Catalog.orderedIds()
        function rank(id) {
            var i = order.indexOf(id)
            return i >= 0 ? i : order.length + list.indexOf(id)
        }
        return list.slice().sort(function (a, b) { return rank(a) - rank(b) })
    }
    property var pendingConfig: ({})
    property var pendingConfigWrite: ({})
    // Orders the widget's reads and writes of config.json: one write at a
    // time, the latest Apply wins (ConfigProviders.read and friends).
    property var configSync: ConfigProviders.syncState()
    // Set while config.json's state is copied into the settings keys.
    property bool mirroringConfig: false
    // A failed one-time migration keeps this session on the widget's own list.
    property bool configMigrationFailed: false

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
    readonly property string commandPathPrefix:
        'PATH="$HOME/.local/bin:$PATH:/usr/local/bin:/usr/bin:/bin"; '
    readonly property string cliExecutable:
        CliStatus.executableForPath(Plasmoid.configuration.cliPath)
    // Optional KEY=VALUE file exported only into the CLI child process, so
    // provider API keys never have to live in Plasma's applet configuration.
    readonly property string cliEnvironmentFile:
        (Plasmoid.configuration.cliEnvironmentFile || "").trim()
    property string lastCheckedCliExecutable: ""
    property var cliState: CliStatus.initialState()
    property var pendingCliChecks: ({})
    property int cliRequestSerial: 0
    readonly property bool cliSetupRequired: CliStatus.isSetupRequired(cliState.code)
    // ---- bundled CLI installer (contents/scripts/install-cli.sh) ----
    property bool cliInstallRunning: false
    property string cliInstallOutput: ""
    property int cliInstallExitCode: -1 // -1: never ran
    property var pendingCliInstall: ({})
    readonly property string cliInstallerPath: {
        var url = Qt.resolvedUrl("../scripts/install-cli.sh").toString()
        if (url.indexOf("file://") !== 0)
            return ""
        return decodeURIComponent(url.substring(7))
    }
    // Providers whose CLI process crashed are skipped by automatic refreshes.
    // A manual refresh still retries, for example after the CLI was upgraded.
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
        switchWarnings: [],
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

    function cliCmd(args, timeoutSeconds) {
        // Plasma's environment may omit user or system bin directories.
        return commandPathPrefix + environmentFilePrefix()
            + cliInvocation(args, timeoutSeconds)
    }

    // One bounded codexbar call, without the PATH and environment prefix.
    function cliInvocation(args, timeoutSeconds) {
        var quoted = cliExecutable === "codexbar"
            ? "codexbar" : shellQuoteExecutable(cliExecutable)
        var seconds = typeof timeoutSeconds === "number" ? timeoutSeconds : 120
        var killDelay = seconds <= 10 ? 5 : 10
        return "timeout -k " + killDelay + " " + seconds + " "
            + quoted + " " + args + " 2>/dev/null"
    }

    // `set -a; . file; set +a` is the EnvironmentFile idiom: every KEY=VALUE
    // line becomes exported. A missing file is skipped rather than failing
    // every probe, and the file is only read for codexbar invocations.
    function environmentFilePrefix() {
        if (cliEnvironmentFile === "")
            return ""
        var quoted = shellQuoteExecutable(cliEnvironmentFile)
        return "if [ -f " + quoted + " ]; then set -a; . " + quoted + "; set +a; fi; "
    }

    function uniqueCliCommand(command, kind, generation) {
        cliRequestSerial++
        return command + " # codexbar-" + kind + "-" + generation
            + "-" + cliRequestSerial
    }

    function stopLoadingIndicators() {
        for (var provider in usageData) {
            if (usageData[provider]) {
                usageData[provider].loading = false
                usageData[provider].costLoading = false
            }
        }
    }

    function startCliCheck() {
        stopLoadingIndicators()
        // The old check's config.json results are dropped with it.
        configSync = ConfigProviders.restart(configSync)
        lastCheckedCliExecutable = cliExecutable
        cliState = CliStatus.beginCheck(cliState)
        var generation = cliState.generation
        var command = uniqueCliCommand(cliCmd("--version", 10), "version", generation)
        pendingCliChecks[command] = { generation: generation }
        bump()
        executable.connectSource(command)
    }

    function retryCli() {
        autoRefreshBlocked = ({})
        startCliCheck()
    }

    // Runs the bundled installer, which downloads the official CodexBar CLI
    // release for this machine into ~/.local/share/codexbar-cli, verifies the
    // checksum and links ~/.local/bin/codexbar (already on the probe PATH).
    function installCli() {
        if (cliInstallRunning || cliInstallerPath === "")
            return
        cliInstallRunning = true
        cliInstallOutput = ""
        cliInstallExitCode = -1
        var command = uniqueCliCommand(
            commandPathPrefix + "timeout -k 10 1800 sh "
                + shellQuote(cliInstallerPath) + " 2>&1",
            "install", cliState.generation)
        pendingCliInstall[command] = true
        bump()
        executable.connectSource(command)
    }

    function finishCliInstall(exitCode, stdout) {
        cliInstallRunning = false
        cliInstallExitCode = exitCode
        cliInstallOutput = (stdout || "").trim()
        if (exitCode === 0) {
            // The installer targets ~/.local/bin/codexbar; a stale custom
            // path would keep pointing the widget at the broken executable.
            if ((Plasmoid.configuration.cliPath || "").trim() !== "")
                Plasmoid.configuration.cliPath = ""
            retryCli()
        }
        bump()
    }

    // Starts a user-configured launch command detached from the widget, with
    // the same PATH the CLI gets (so ~/.local/bin tools are found).
    function runCommand(cmd) {
        var command = typeof cmd === "string" ? cmd.trim() : ""
        if (command === "")
            return
        executable.connectSource(uniqueCliCommand(
            commandPathPrefix + "setsid -f sh -c " + shellQuote(command) + " >/dev/null 2>&1",
            "launch", cliState.generation))
    }

    function manualRefresh() {
        if (cliSetupRequired || cliState.code === CliStatus.UNKNOWN)
            retryCli()
        else
            refreshAll(true)
    }

    function claudeAdapterCmd(operation, slot) {
        var quoted = shellQuoteExecutable(claudeAdapterExecutable)
        if (operation === "list") {
            // Bound what Plasma's executable data engine can capture, while
            // retaining one extra byte so the parser can report overflow.
            var pipeline = quoted + " --list --json 2>/dev/null | head -c "
                + (ClaudeAccounts.MAX_OUTPUT_BYTES + 1)
            return commandPathPrefix + "timeout -k 5 30 sh -c " + shellQuote(pipeline)
        }
        if (operation === "switch" && typeof slot === "number" && isFinite(slot)
                && Math.floor(slot) === slot && slot > 0) {
            // Bound the switch like the list probe so a hung adapter (credential
            // lock, keychain prompt, or backend call) cannot leave
            // claudeSwitchInFlight set, and cap its captured output just like
            // the automatic list response.
            var switchPipeline = quoted + " --switch-to " + slot
                + " --json 2>/dev/null | head -c "
                + (ClaudeAccounts.MAX_OUTPUT_BYTES + 1)
            return commandPathPrefix + "timeout -k 5 30 sh -c " + shellQuote(switchPipeline)
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
            switchWarnings: [],
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
        updateClaudeAccountData({ switchError: "", switchWarnings: [] })
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
        // Last-known windows are served because the live fetch failed, so they
        // are non-current regardless of how recently they were measured.
        if (account && account.usageIsLastGood === true)
            return true
        var ts = (account && typeof account.usageMeasuredAt === "number")
            ? account.usageMeasuredAt : claudeAccountData.fetchedAt
        if (!ts)
            return true
        var maxAge = Math.max(1, Plasmoid.configuration.refreshIntervalMinutes) * 60000 * 3
        return (Date.now() - ts) > maxAge
    }

    function keyProviderIds() {
        var raw = (Plasmoid.configuration.enabledProviders || "").split(",")
        var list = []
        for (var i = 0; i < raw.length; i++) {
            var s = raw[i].trim()
            if (s.length > 0 && list.indexOf(s) < 0)
                list.push(s)
        }
        return list
    }

    function refreshAll(force) {
        // Read config.json first so changes made with the CLI or the app
        // show up; the probes follow once it is read. While a write runs,
        // the read after it does that.
        if (CliStatus.canRunUsage(cliState.code)
                && CliStatus.supportsConfigSource(cliState.detectedVersion)
                && !configMigrationFailed) {
            var refresh = ConfigProviders.refresh(configSync, force)
            configSync = refresh.state
            if (refresh.read)
                loadConfig(refresh.read)
            return
        }
        // Leaving config mode (an older CLI) re-runs this through
        // onEnabledProvidersChanged with the widget's own list.
        if (leaveConfigMode())
            return
        probeAll(force)
    }

    // Back to the widget's own provider list; true when that changed it.
    function leaveConfigMode() {
        if (Plasmoid.configuration.configProviders !== "")
            Plasmoid.configuration.configProviders = ""
        if (configProviderList === null)
            return false
        configProviderList = null
        return true
    }

    // Reads config.json; token comes from ConfigProviders.refresh or readBack.
    function loadConfig(token) {
        var command = uniqueCliCommand(commandPathPrefix + environmentFilePrefix()
            + cliInvocation("config providers --json", 30) + "; printf '\\036'; "
            + cliInvocation("config dump --json", 30), "config", cliState.generation)
        pendingConfig[command] = { token: token, cliGeneration: cliState.generation }
        executable.connectSource(command)
    }

    // Runs a write from ConfigProviders.request or read: its steps one after
    // the other, so they cannot race on the file. config.json is read back
    // (and probed) afterwards.
    function writeConfig(write) {
        var command = uniqueCliCommand(commandPathPrefix + environmentFilePrefix()
            + write.steps.map(function (step) {
                return cliInvocation("config " + step + " --json", 30)
            }).join(" && "),
            "config-write", cliState.generation)
        pendingConfigWrite[command] = { write: write, cliGeneration: cliState.generation }
        executable.connectSource(command)
    }

    // A selection applied on the settings page goes to config.json.
    function applyProviderSelection(wanted) {
        var request = ConfigProviders.request(configSync, configProviderList, wanted, true, false)
        configSync = request.state
        if (request.write)
            writeConfig(request.write)
    }

    // Why a write to config.json failed, in the CLI's words when it gave some.
    function configWriteErrorText(exitCode, stdout) {
        var message = ConfigProviders.writeError(stdout)
        if (message !== "")
            return message
        if (exitCode === 124 || exitCode === 137)
            return i18n("the CodexBar CLI timed out")
        if (exitCode === 127)
            return i18n("the CodexBar CLI was not found")
        if (CliStatus.isCrash(exitCode))
            return i18n("the CodexBar CLI crashed")
        return i18n("the CodexBar CLI failed (exit %1)", exitCode)
    }

    // The settings page shows config.json's state: enabledProviders mirrors
    // it, and configProviders caches the full list with names and sources.
    function mirrorConfig(list) {
        var enabled = ConfigProviders.enabledIds(list).join(",")
        var cache = JSON.stringify(list)
        mirroringConfig = true
        if (Plasmoid.configuration.enabledProviders !== enabled)
            Plasmoid.configuration.enabledProviders = enabled
        if (Plasmoid.configuration.configProviders !== cache)
            Plasmoid.configuration.configProviders = cache
        mirroringConfig = false
    }

    function probeAll(force) {
        if (CliStatus.canRunUsage(cliState.code)) {
            for (var i = 0; i < enabledProviders.length; i++) {
                var provider = enabledProviders[i]
                if (force === true || !autoRefreshBlocked[provider])
                    refreshProvider(provider)
            }
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
        return CliStatus.canRunUsage(cliState.code)
            && costEnabled && supportsCost(p)
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

        var cliGeneration = cliState.generation
        var costCmd = uniqueCliCommand(
            cliCmd("cost --provider " + p + " --json"),
            "cost-" + p, cliGeneration)
        pendingCost[costCmd] = { p: p, cliGeneration: cliGeneration }
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
        if (!CliStatus.canRunUsage(cliState.code))
            return
        if (!usageData[p])
            usageData[p] = {}
        var gen = (requestGen[p] || 0) + 1
        requestGen[p] = gen
        usageData[p].loading = true
        bump()

        var cliGeneration = cliState.generation
        var cmd = uniqueCliCommand(
            cliCmd("usage --provider " + p + " --json"
                   + ProviderSources.cliArguments(Plasmoid.configuration.providerSources, p)
                   + (Plasmoid.configuration.showStatus ? " --status" : "")),
            "usage-" + p, cliGeneration)
        pendingUsage[cmd] = { p: p, gen: gen, cliGeneration: cliGeneration }
        executable.connectSource(cmd)
    }

    function usageErrorText(p, exitCode, parseFailed) {
        if (exitCode === 124 || exitCode === 137)
            return i18n("Timed out querying the CodexBar CLI")
        var required = Catalog.meta(p).minCli
        if (exitCode !== 0 && exitCode !== 127 && !CliStatus.isCrash(exitCode) && required
                && cliState.detectedVersion !== ""
                && CliStatus.compareVersions(cliState.detectedVersion, required) < 0)
            return i18n("%1 needs CodexBar CLI %2 or newer (installed: %3)",
                        Catalog.meta(p).name, required, cliState.detectedVersion)
        if (CliStatus.isCrash(exitCode))
            return i18n("CodexBar CLI crashed while fetching %1 — automatic refreshes skip it until you refresh manually", Catalog.meta(p).name)
        if (exitCode === 127)
            return i18n("CodexBar CLI not found — set the path in the settings")
        if (parseFailed)
            return i18n("Unexpected CodexBar CLI output (JSON parse failed)")
        if (exitCode === 0)
            return i18n("No usage data available")
        return i18n("No usage data — check CodexBar login/configuration (exit %1)", exitCode)
    }

    // The CLI answered for other providers only, so it does not know this
    // one: the provider is newer than the installed CLI or was removed.
    function unsupportedProviderText(p) {
        var required = Catalog.meta(p).minCli
        if (required && cliState.detectedVersion !== ""
                && CliStatus.compareVersions(cliState.detectedVersion, required) < 0)
            return i18n("%1 needs CodexBar CLI %2 or newer (installed: %3)",
                        Catalog.meta(p).name, required, cliState.detectedVersion)
        return i18n("%1 is not supported by the installed CodexBar CLI", Catalog.meta(p).name)
    }

    function handleData(source, exitCode, stdout) {
        var cliCheck = pendingCliChecks[source]
        if (cliCheck !== undefined) {
            delete pendingCliChecks[source]
            if (cliCheck.generation !== cliState.generation)
                return
            cliState = CliStatus.applyVersionResult(
                cliState, cliCheck.generation, exitCode, stdout)
            bump()
            refreshAll(true)
            return
        }

        if (pendingCliInstall[source] !== undefined) {
            delete pendingCliInstall[source]
            finishCliInstall(exitCode, stdout)
            return
        }

        var configReq = pendingConfig[source]
        if (configReq !== undefined) {
            delete pendingConfig[source]
            if (configReq.cliGeneration !== cliState.generation)
                return
            var parts = (stdout || "").split("\u001e")
            var list = ConfigProviders.parse(parts[0], parts.length > 1 ? parts[1] : "",
                                             Catalog.cliProviderId)
            var read = ConfigProviders.read(configSync, configReq.token, list,
                                            Plasmoid.configuration.configMigrated, keyProviderIds())
            configSync = read.state
            var action = read.action
            if (action.type === "drop")
                return
            if (action.type === "leave") {
                // config.json could not be read: keep the widget's own list,
                // and a pending migration waits for a read that works.
                if (!leaveConfigMode())
                    probeAll(action.force)
                return
            }
            for (var n = 0; n < list.length; n++)
                Catalog.registerName(list[n].id, list[n].name)
            configProviderList = list
            if (action.migrated)
                Plasmoid.configuration.configMigrated = true
            if (action.type === "write") {
                writeConfig(action)
                return
            }
            mirrorConfig(list)
            probeAll(action.force)
            return
        }

        var writeReq = pendingConfigWrite[source]
        if (writeReq !== undefined) {
            delete pendingConfigWrite[source]
            if (writeReq.cliGeneration !== cliState.generation)
                return
            // Shown in the popup and on the Providers page until a write
            // works or it is dismissed.
            var writeError = exitCode === 0 ? "" : configWriteErrorText(exitCode, stdout)
            if (Plasmoid.configuration.configWriteError !== writeError)
                Plasmoid.configuration.configWriteError = writeError
            if (writeError !== "" && writeReq.write.migration) {
                // Keep the widget's own list rather than losing it.
                console.warn("codexbar: moving the provider list to config.json failed:", writeError)
                configMigrationFailed = true
                var abandoned = ConfigProviders.abandon(configSync, writeReq.write)
                configSync = abandoned.state
                if (!leaveConfigMode())
                    probeAll(abandoned.force)
                return
            }
            if (writeError !== "")
                console.warn("codexbar: config write failed:", writeError)
            loadConfig(ConfigProviders.readBack(configSync, writeReq.write))
            return
        }

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
                // Adapter warnings ride along with both outcomes: a switch can
                // report success and still warn that a credential needs repair.
                updateClaudeAccountData({
                    switchError: parsedSwitch.ok ? ""
                        : claudeAdapterErrorText(exitCode, parsedSwitch.error),
                    switchWarnings: parsedSwitch.ok ? parsedSwitch.value.warnings
                                                    : (parsedSwitch.warnings || [])
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
            if (requestGen[req.p] !== req.gen
                    || req.cliGeneration !== cliState.generation)
                return // stale response from an older refresh
            var d = usageData[req.p]
            if (!d)
                d = usageData[req.p] = {}
            d.loading = false
            d.fetchedAt = Date.now()

            if (CliStatus.isCrash(exitCode))
                autoRefreshBlocked[req.p] = true
            else
                delete autoRefreshBlocked[req.p]

            var trimmed = (stdout || "").trim()
            var parsed = null
            var parseFailed = false
            if (trimmed.length > 0) {
                try { parsed = JSON.parse(trimmed) } catch (e) { parseFailed = true }
            }
            // An unknown --provider name makes the CLI report the providers
            // enabled in its own config; only this provider's entries count.
            var entries = Catalog.entriesForProvider(parsed, req.p)
            var cliError = Catalog.errorForProvider(parsed, req.p)
            if (entries.length > 0 && entries[0].usage) {
                d.entry = entries[0]
                d.entries = entries
                d.error = ""
                d.errorCode = ""
                cliState = CliStatus.applyUsageResult(
                    cliState, req.cliGeneration, exitCode, true, false)
            } else if (cliError !== "") {
                // The CLI explains the failure itself, such as a missing
                // login or a config.json it cannot decode, so it works.
                d.error = cliError
                d.errorCode = ""
            } else if (entries.length === 0 && Array.isArray(parsed) && parsed.length > 0) {
                // The CLI itself works, so its state stays as it is.
                delete d.entry
                delete d.entries
                d.error = unsupportedProviderText(req.p)
                d.errorCode = ""
            } else {
                d.error = usageErrorText(req.p, exitCode, parseFailed)
                d.errorCode = CliStatus.usageFailureCode(exitCode, parseFailed)
                cliState = CliStatus.applyUsageResult(
                    cliState, req.cliGeneration, exitCode, false, parseFailed)
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
            if (creq.cliGeneration !== cliState.generation)
                return
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

    // the window behind a panel percentage and its remaining percent, or null
    function panelPick(p, source) {
        rev
        var d = usageData[p]
        if (!d || !d.entry || !d.entry.usage)
            return null
        return Catalog.panelWindow(d.entry.usage, p, source)
    }

    // remaining percent for the panel icon / percent label; -1 = unknown
    function remainingPercent(p, source) {
        var pick = panelPick(p, source)
        return pick ? pick.remaining : -1
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
        startCliCheck()
    }

    onCliExecutableChanged: {
        if (componentReady && CliStatus.pathChangeRequiresCheck(
                lastCheckedCliExecutable, cliExecutable))
            retryCli()
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

    Connections {
        target: Plasmoid.configuration
        function onProviderSourcesChanged() {
            if (root.componentReady)
                root.refreshAll(true)
        }
        function onEnabledProvidersChanged() {
            // A new selection from the settings page goes to config.json;
            // copying config.json's state back into the key does not.
            if (root.componentReady && root.configMode && !root.mirroringConfig)
                root.applyProviderSelection(root.keyProviderIds())
        }
        function onProviderOverridesChanged() {
            // Overrides only change how the panel draws; no re-probe needed.
            if (root.componentReady)
                root.bump()
        }
    }

    onCliEnvironmentFileChanged: {
        if (componentReady)
            refreshAll(true)
    }

    onEnabledProvidersChanged: {
        var valid = currentTab === "about"
                || (currentTab === "overview" && enabledProviders.length > 1)
                || enabledProviders.indexOf(currentTab) >= 0
        if (!valid)
            currentTab = defaultTab()
        deferAutomaticCostScans()
        // In config mode every read of config.json is followed by probes.
        // Before the component is ready the CLI check is still to come, and
        // it refreshes everything once it knows the CLI.
        if (componentReady && !configMode)
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
            onTriggered: root.manualRefresh()
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
