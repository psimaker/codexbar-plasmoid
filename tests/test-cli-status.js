#!/usr/bin/env node

const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const source = fs.readFileSync(
    path.join(__dirname, "..", "contents", "ui", "code", "cliStatus.js"),
    "utf8"
)
const cli = {}
vm.createContext(cli)
vm.runInContext(source, cli, { filename: "cliStatus.js" })

function checkingState() {
    return cli.beginCheck(cli.initialState())
}

function usageFailure(exitCode, parseFailed = false) {
    const state = checkingState()
    return cli.applyUsageResult(
        state, state.generation, exitCode, false, parseFailed
    )
}

assert.equal(usageFailure(127).code, cli.MISSING)
assert.equal(usageFailure(124).code, cli.TIMEOUT)
assert.equal(usageFailure(137).code, cli.TIMEOUT)
assert.equal(usageFailure(0, true).code, cli.UNEXPECTED)

// Processes killed by a crash signal, as sh reports them (128 + signal).
for (const code of [132, 133, 134, 135, 136, 139])
    assert.equal(cli.isCrash(code), true, `exit ${code}`)
for (const code of [0, 1, 2, 64, 124, 127, 137, 143])
    assert.equal(cli.isCrash(code), false, `exit ${code}`)

assert.equal(cli.parseVersion("CodexBar 0.43.0\n"), "0.43.0")
assert.equal(cli.parseVersion("codexbar version v0.53.0 (linux)"), "0.53.0")
assert.equal(cli.parseVersion("\u001b[32mCodexBarCLI v1.2.3-beta.1\u001b[0m"), "1.2.3")
assert.equal(cli.parseVersion("CodexBar development build"), "")

assert.equal(cli.compareVersions("0.42.1", cli.MINIMUM_VERSION), -1)
assert.equal(cli.compareVersions("0.43.0", cli.MINIMUM_VERSION), 0)
assert.equal(cli.compareVersions("0.53.0", cli.MINIMUM_VERSION), 1)

let versionState = checkingState()
versionState = cli.applyVersionResult(
    versionState, versionState.generation, 0, "CodexBar 0.42.1"
)
assert.equal(versionState.code, cli.INCOMPATIBLE)
assert.equal(versionState.reason, cli.REASON_VERSION_TOO_OLD)

let unknownVersion = checkingState()
unknownVersion = cli.applyVersionResult(
    unknownVersion, unknownVersion.generation, 0, "CodexBar development build"
)
assert.equal(unknownVersion.code, cli.UNKNOWN)
unknownVersion = cli.applyUsageResult(
    unknownVersion, unknownVersion.generation, 0, true, false
)
assert.equal(unknownVersion.code, cli.AVAILABLE)
assert.equal(unknownVersion.usageSucceeded, true)

const firstCheck = checkingState()
const retry = cli.beginCheck(firstCheck)
assert.equal(retry.code, cli.CHECKING)
assert.equal(retry.generation, firstCheck.generation + 1)

assert.equal(cli.executableForPath(""), "codexbar")
assert.equal(cli.executableForPath("  /opt/codexbar  "), "/opt/codexbar")
assert.equal(cli.pathChangeRequiresCheck("", "codexbar"), false)
assert.equal(cli.pathChangeRequiresCheck("", "/opt/codexbar"), true)

const current = cli.beginCheck(retry)
const staleResult = cli.applyUsageResult(
    current, retry.generation, 127, false, false
)
assert.equal(staleResult, current)
assert.equal(staleResult.code, cli.CHECKING)

// A crash while fetching one provider leaves the CLI usable for the others,
// whichever result arrives first: polling goes on and no setup card shows.
function availableState() {
    const state = checkingState()
    return cli.applyVersionResult(state, state.generation, 0, "CodexBar 0.70.0")
}
function usageResults(state, ...results) {
    return results.reduce((s, [exitCode, hasUsage]) =>
        cli.applyUsageResult(s, s.generation, exitCode, hasUsage, false), state)
}
for (const crash of [139, 132]) {
    const orders = {
        "crash first": usageResults(availableState(), [crash, false], [0, true]),
        "success first": usageResults(availableState(), [0, true], [crash, false]),
        "crash only": usageResults(availableState(), [crash, false]),
    }
    for (const [order, state] of Object.entries(orders)) {
        assert.equal(state.code, cli.AVAILABLE, `${order}, exit ${crash}`)
        assert.equal(state.reason, cli.REASON_NONE, `${order}, exit ${crash}`)
        assert.equal(cli.canRunUsage(state.code), true, `${order}, exit ${crash}`)
        assert.equal(cli.isSetupRequired(state.code), false, `${order}, exit ${crash}`)
    }
}
// A crash does not hide what other failures say about the CLI.
assert.equal(usageResults(availableState(), [139, false], [127, false]).code, cli.MISSING)
assert.equal(usageResults(availableState(), [124, false], [139, false]).code, cli.TIMEOUT)
// A CLI that crashes on --version is not usable at all.
for (const crash of [139, 134]) {
    const state = checkingState()
    const crashed = cli.applyVersionResult(state, state.generation, crash, "")
    assert.equal(crashed.code, cli.INCOMPATIBLE)
    assert.equal(crashed.reason, cli.REASON_CRASHED)
    assert.equal(cli.canRunUsage(crashed.code), false)
}

// config.json becomes the provider source from CLI 0.66 on (#25)
assert.equal(cli.supportsConfigSource("0.66.0"), true)
assert.equal(cli.supportsConfigSource("0.70.1"), true)
assert.equal(cli.supportsConfigSource("0.65.9"), false)
assert.equal(cli.supportsConfigSource(""), false)

// and stores a provider's data source from CLI 0.72.1 on (`config set-source`)
assert.equal(cli.supportsConfigSetSource("0.72.1"), true)
assert.equal(cli.supportsConfigSetSource("0.73.0"), true)
assert.equal(cli.supportsConfigSetSource("0.72.0"), false)
assert.equal(cli.supportsConfigSetSource(""), false)

console.log("CLI status tests passed")
