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
assert.equal(usageFailure(139).code, cli.INCOMPATIBLE)
assert.equal(usageFailure(0, true).code, cli.UNEXPECTED)

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

console.log("CLI status tests passed")
