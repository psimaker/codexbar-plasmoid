#!/usr/bin/env node

const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const source = fs.readFileSync(
    path.join(__dirname, "..", "contents", "ui", "code", "notifications.js"),
    "utf8"
).replace(/^\.pragma library$/m, "")
const lib = {}
vm.createContext(lib)
vm.runInContext(source, lib, { filename: "notifications.js" })

// objects cross the vm boundary with a foreign prototype; compare plain copies
function plain(value) { return JSON.parse(JSON.stringify(value)) }

const all = { threshold: 10, quota: true, status: true }
const row = (remaining, resetsAt, statusLevel) => ({
    failed: false,
    windows: [{ key: "primary", label: "Session", remaining, resetsAt }],
    statusLevel,
})
function step(state, r, options = all, provider = "codex") {
    return lib.transition(state, provider, r, options)
}

// The first answer only sets the baseline, whatever it shows.
{
    const first = step({}, row(5, "2026-10-06T15:00:00Z", "major"))
    assert.deepEqual(plain(first.events), [])
    assert.deepEqual(plain(first.state), {
        "codex/primary": { remaining: 5, reset: "2026-10-06T15:00:00Z" },
        "codex/status": { level: "major" },
    })
}

// Crossing the threshold reports low once; staying below does not repeat.
{
    let s = step({}, row(40, "R1")).state
    let r = step(s, row(10, "R1"))
    assert.deepEqual(plain(r.events), [{ kind: "low", provider: "codex", label: "Session", remaining: 10 }])
    r = step(r.state, row(4, "R1"))
    assert.deepEqual(plain(r.events), [])
    // a custom threshold
    s = step({}, row(30, "R1")).state
    assert.equal(step(s, row(25, "R1"), { threshold: 25, quota: true }).events.length, 1)
    assert.equal(step(s, row(26, "R1"), { threshold: 25, quota: true }).events.length, 0)
}

// A reset is a new reset time with more quota left than before.
{
    const s = step({}, row(3, "R1")).state
    assert.deepEqual(plain(step(s, row(100, "R2")).events),
        [{ kind: "reset", provider: "codex", label: "Session", remaining: 100 }])
    // a moved reset time without more quota is no reset
    assert.deepEqual(plain(step(s, row(3, "R2")).events), [])
    // nor is more quota without a known reset time
    assert.deepEqual(plain(step(step({}, row(3, "")).state, row(100, "R2")).events), [])
}

// Status changes, recovery included; unknown levels are ignored.
{
    let s = step({}, row(50, "R1", "none")).state
    let r = step(s, row(50, "R1", "major"))
    assert.deepEqual(plain(r.events), [{ kind: "status", provider: "codex", level: "major" }])
    r = step(r.state, row(50, "R1", "none"))
    assert.deepEqual(plain(r.events), [{ kind: "status", provider: "codex", level: "none" }])
    assert.deepEqual(plain(step(r.state, row(50, "R1", "unknown")).events), [])
    assert.deepEqual(plain(step(r.state, row(50, "R1", undefined)).events), [])
}

// Each kind only when enabled, while the baseline still follows.
{
    const s = step({}, row(40, "R1", "none")).state
    const quiet = step(s, row(5, "R1", "major"), { threshold: 10, quota: false, status: false })
    assert.deepEqual(plain(quiet.events), [])
    assert.deepEqual(plain(quiet.state["codex/primary"]), { remaining: 5, reset: "R1" })
    assert.deepEqual(plain(step(s, row(5, "R1", "major"), { threshold: 10, quota: false, status: true }).events),
        [{ kind: "status", provider: "codex", level: "major" }])
}

// A failed probe forgets the provider, so its recovery is a new baseline.
{
    let s = step({}, row(40, "R1", "none")).state
    s = step(s, { failed: true }).state
    assert.deepEqual(plain(s), {})
    assert.deepEqual(plain(step(s, row(5, "R1", "major")).events), [])
}

// Providers are independent.
{
    let s = step({}, row(40, "R1"), all, "codex").state
    s = step(s, row(40, "R1"), all, "claude").state
    const r = step(s, row(5, "R1"), all, "claude")
    assert.equal(r.events.length, 1)
    assert.equal(r.events[0].provider, "claude")
    assert.deepEqual(plain(r.state["codex/primary"]), { remaining: 40, reset: "R1" })
    // a provider prefix does not match another provider's keys
    const other = step({ "codexspark/primary": { remaining: 1, reset: "" } }, row(40, "R1"), all, "codex")
    assert.ok(other.state["codexspark/primary"])
}

// The threshold stays within 1 to 99 and defaults to 10.
assert.equal(lib.threshold(undefined), 10)
assert.equal(lib.threshold(0), 10)
assert.equal(lib.threshold(150), 99)
assert.equal(lib.threshold("25"), 25)

console.log("Notification tests passed")
