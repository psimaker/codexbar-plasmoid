#!/usr/bin/env node

const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const source = fs.readFileSync(
    path.join(__dirname, "..", "contents", "ui", "code", "usageProbes.js"),
    "utf8"
).replace(/^\.pragma library$/m, "")
const lib = {}
vm.createContext(lib)
vm.runInContext(source, lib, { filename: "usageProbes.js" })

const plain = "codexbar usage --provider codex --json --status"
const withSource = "codexbar usage --provider codex --json --source api --status"
const claude = "codexbar usage --provider claude --json --status"

// The first refresh starts a probe; repeated ones while it runs share it.
{
    let r = lib.request(lib.initialState(), "codex", plain, 1, false)
    assert.equal(r.start, true)
    let state = r.state
    r = lib.request(state, "codex", plain, 1, false)
    assert.equal(r.start, false)
    r = lib.request(r.state, "codex", plain, 1, false)
    assert.equal(r.start, false)
    state = r.state
    // other providers are independent
    r = lib.request(state, "claude", claude, 1, false)
    assert.equal(r.start, true)
    state = r.state
    const done = lib.finish(state, "codex", 1)
    assert.equal(done.accept, true)
    assert.equal(done.rerun, false)
    // the next refresh starts a probe again; Claude's still runs
    assert.equal(lib.request(done.state, "codex", plain, 1, false).start, true)
    assert.equal(lib.request(done.state, "claude", claude, 1, false).start, false)
}

// A refresh with another command, or one that needs a newer answer, waits
// for the running probe, whose answer no longer counts, and runs once it is
// done. Several of them run once.
for (const [command, fresh] of [[withSource, false], [plain, true]]) {
    let state = lib.request(lib.initialState(), "codex", plain, 1, false).state
    let r = lib.request(state, "codex", command, 1, fresh)
    assert.equal(r.start, false)
    r = lib.request(r.state, "codex", command, 1, fresh)
    assert.equal(r.start, false)
    // a later shared refresh does not cancel the waiting one
    r = lib.request(r.state, "codex", plain, 1, false)
    const done = lib.finish(r.state, "codex", 1)
    assert.equal(done.accept, false)
    assert.equal(done.rerun, true)
    // the rerun starts right away, and its answer counts
    r = lib.request(done.state, "codex", command, 1, fresh)
    assert.equal(r.start, true)
    const rerun = lib.finish(r.state, "codex", 1)
    assert.equal(rerun.accept, true)
    assert.equal(rerun.rerun, false)
}

// A new CLI check does not wait for a probe of the old one; when the old
// probe finishes, it neither counts nor touches the new one.
{
    let state = lib.request(lib.initialState(), "codex", plain, 1, false).state
    let r = lib.request(state, "codex", plain, 2, false)
    assert.equal(r.start, true)
    state = r.state
    const stale = lib.finish(state, "codex", 1)
    assert.equal(stale.accept, false)
    assert.equal(stale.rerun, false)
    assert.equal(lib.request(stale.state, "codex", plain, 2, false).start, false)
    assert.equal(lib.finish(stale.state, "codex", 2).accept, true)
}

// An answer without a recorded probe does not count.
assert.equal(lib.finish(lib.initialState(), "codex", 1).accept, false)

console.log("Usage probe tests passed")
