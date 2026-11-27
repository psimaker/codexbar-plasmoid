#!/usr/bin/env node

const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const source = fs.readFileSync(
    path.join(__dirname, "..", "contents", "ui", "code", "claudeAccounts.js"),
    "utf8"
).replace(/^\.pragma library$/m, "")
const lib = {}
vm.createContext(lib)
vm.runInContext(source, lib, { filename: "claudeAccounts.js" })

// objects cross the vm boundary with a foreign prototype; compare plain copies
function plain(value) { return JSON.parse(JSON.stringify(value)) }

const now = Date.parse("2026-11-27T12:00:00Z")

function list(payload) {
    return lib.parseList(JSON.stringify(payload), now)
}

function accounts(payload) {
    const parsed = list(payload)
    assert.equal(parsed.ok, true, parsed.error)
    return parsed.value.accounts
}

function row(fields) {
    return Object.assign({ active: false, usageStatus: "ok" }, fields)
}

// A read-only adapter, as claude-rotate-codexbar writes it since 2026-11-27:
// supportsAccountSwitching false, aliases for a shared email, a window left
// out when it has no data, and a rate-limited account served from last-good.
{
    const parsed = list({
        schemaVersion: 1,
        activeAccountNumber: 1,
        supportsAccountSwitching: false,
        accounts: [
            row({ number: 1, email: "me@example.com", alias: "个人", active: true,
                  usage: { sevenDay: { pct: 40, resetsAt: "2026-11-30T00:00:00Z" } } }),
            row({ number: 2, email: "me@example.com", alias: "Fintutor",
                  usageStatus: "unavailable", usage: null,
                  lastGoodUsage: { fiveHour: { pct: 100, resetsAt: "2026-11-27T13:00:00Z" },
                                   sevenDay: { pct: 71 } },
                  lastGoodFetchedAt: "2026-11-27T11:30:00Z" }),
            row({ number: 3, email: "other@example.com", usageStatus: "token_expired", usage: null })
        ]
    })
    assert.equal(parsed.ok, true, parsed.error)
    assert.equal(parsed.value.supportsAccountSwitching, false)
    const [first, second, third] = parsed.value.accounts
    assert.deepEqual(plain(parsed.value.accounts.map(a => a.displayLabel)), ["个人", "Fintutor", "other@example.com"])

    // the missing fiveHour window is just absent
    assert.equal(first.fiveHour, null)
    assert.equal(first.sevenDay.usedPercent, 40)
    assert.equal(first.usageIsLastGood, false)

    // last-known numbers, stamped with their capture time, never as current
    assert.equal(second.usageIsLastGood, true)
    assert.equal(second.fiveHour.usedPercent, 100)
    assert.equal(second.sevenDay.usedPercent, 71)
    assert.equal(second.usageMeasuredAt, Date.parse("2026-11-27T11:30:00Z"))
    assert.equal(lib.statusError(second), "Usage fetch failed.")

    // no account offers a switch, and the hints do not point to one
    assert.equal(parsed.value.accounts.some(a => lib.canActivate(a)), false)
    assert.equal(lib.statusError(third), "Token expired. Refresh it with the account adapter.")
}

// supportsAccountSwitching: absent means true; anything but a boolean is
// rejected like CodexBar's parser does
{
    const parsed = list({
        schemaVersion: 1, activeAccountNumber: 1,
        accounts: [row({ number: 1, active: true }), row({ number: 2, usageStatus: "token_expired" })]
    })
    assert.equal(parsed.value.supportsAccountSwitching, true)
    assert.equal(lib.canActivate(parsed.value.accounts[1]), true)
    assert.equal(lib.statusError(parsed.value.accounts[1]), "Token expired. Switch to this account to refresh it.")
    for (const value of [null, 0, 1, "false", [], {}]) {
        const bad = list({ schemaVersion: 1, activeAccountNumber: null, supportsAccountSwitching: value, accounts: [] })
        assert.equal(bad.ok, false, JSON.stringify(value))
        assert.match(bad.error, /supportsAccountSwitching/)
    }
}

// display labels follow CodexBar's ClaudeSwapAccountProjection
function labels(rows) {
    return plain(accounts({ schemaVersion: 1, activeAccountNumber: null, accounts: rows }).map(a => a.displayLabel))
}
// a unique email stays the email even with an organization name
assert.deepEqual(labels([row({ number: 1, email: "work@example.com", organizationName: "Sendbird" }),
                         row({ number: 2, email: "personal@example.com", organizationName: "Acme" })]),
    ["work@example.com", "personal@example.com"])
// a shared email takes the organization name, else the slot
assert.deepEqual(labels([row({ number: 1, email: "shared@example.com", organizationName: "Sendbird" }),
                         row({ number: 4, email: "shared@example.com" })]),
    ["shared@example.com · Sendbird", "shared@example.com · Account 4"])
// also when the emails only differ by case
assert.deepEqual(labels([row({ number: 1, email: "Shared@example.com", organizationName: "Sendbird" }),
                         row({ number: 2, email: "shared@example.com", organizationName: "Acme" })]),
    ["Shared@example.com · Sendbird", "shared@example.com · Acme"])
// a label that still collides gets the slot appended
assert.deepEqual(labels([row({ number: 1, email: "shared@example.com", organizationName: "Sendbird" }),
                         row({ number: 4, email: "shared@example.com", organizationName: "Sendbird" })]),
    ["shared@example.com · Sendbird · Account 1", "shared@example.com · Sendbird · Account 4"])
// the alias wins; a whitespace alias does not count; no email is "Account N"
assert.deepEqual(labels([row({ number: 1, email: "shared@example.com", organizationName: "Sendbird", alias: " Work " }),
                         row({ number: 2, email: "shared@example.com", organizationName: "Acme", alias: "  " }),
                         row({ number: 3, email: "", alias: "Empty slot" }),
                         row({ number: 5 })]),
    ["Work", "shared@example.com · Acme", "Empty slot", "Account 5"])

// a JSON null window is read as absent instead of rejecting every account
// (CodexBar rejects it); so is a null resetsAt and a null usage object
{
    const [a, b] = accounts({
        schemaVersion: 1, activeAccountNumber: 1,
        accounts: [
            row({ number: 1, active: true, usage: { fiveHour: null, sevenDay: { pct: 12, resetsAt: null } } }),
            row({ number: 2, usage: null })
        ]
    })
    assert.equal(a.fiveHour, null)
    assert.equal(a.sevenDay.usedPercent, 12)
    assert.equal(a.sevenDay.resetsAt, null)
    assert.equal(b.fiveHour, null)
    assert.equal(lib.statusError(b), "No usage windows reported.")
}

// unknown fields anywhere are ignored
{
    const [a] = accounts({
        schemaVersion: 1, activeAccountNumber: 1, generatedBy: "future-adapter",
        accounts: [row({ number: 1, active: true, profileId: "secret", plan: "max",
                         usage: { fiveHour: { pct: 5, countdown: "1h", extra: [1] }, future: {} } })]
    })
    assert.equal(a.fiveHour.usedPercent, 5)
    assert.equal(a.profileId, undefined)
    assert.equal(a.plan, undefined)
}

// a malformed live window still rejects the list, as in CodexBar
{
    const bad = list({ schemaVersion: 1, activeAccountNumber: 1,
                       accounts: [row({ number: 1, active: true, usage: { fiveHour: { pct: "high" } } })] })
    assert.equal(bad.ok, false)
    assert.match(bad.error, /five-hour usage percentage/)
}

// the last-good fallback
function lastGood(fields) {
    return accounts({ schemaVersion: 1, activeAccountNumber: null,
                      accounts: [row(Object.assign({ number: 1, usageStatus: "unavailable", usage: null }, fields))] })[0]
}
// without a capture time it is not shown at all
assert.equal(lastGood({ lastGoodUsage: { fiveHour: { pct: 50 } } }).usageIsLastGood, false)
assert.equal(lastGood({ lastGoodUsage: { fiveHour: { pct: 50 } }, lastGoodFetchedAt: "soon" }).usageIsLastGood, false)
// an age in seconds is a capture time too
{
    const a = lastGood({ lastGoodUsage: { fiveHour: { pct: 50 } }, lastGoodAgeSeconds: 600 })
    assert.equal(a.usageIsLastGood, true)
    assert.equal(a.usageMeasuredAt, now - 600000)
}
// a malformed window in it is dropped on its own instead of rejecting the list
{
    const a = lastGood({ lastGoodUsage: { fiveHour: { pct: "x" }, sevenDay: { pct: 30 } },
                         lastGoodFetchedAt: "2026-11-27T11:00:00Z" })
    assert.equal(a.usageIsLastGood, true)
    assert.equal(a.fiveHour, null)
    assert.equal(a.sevenDay.usedPercent, 30)
}
// nothing usable in it means no fallback
assert.equal(lastGood({ lastGoodUsage: { fiveHour: { pct: "x" } },
                        lastGoodFetchedAt: "2026-11-27T11:00:00Z" }).usageIsLastGood, false)
// an "ok" row never falls back, and live windows win over the fallback
{
    const ok = lastGood({ usageStatus: "ok", lastGoodUsage: { fiveHour: { pct: 50 } },
                          lastGoodFetchedAt: "2026-11-27T11:00:00Z" })
    assert.equal(ok.usageIsLastGood, false)
    assert.equal(ok.fiveHour, null)
    const live = lastGood({ usage: { fiveHour: { pct: 20 } }, lastGoodUsage: { fiveHour: { pct: 50 } },
                            lastGoodFetchedAt: "2026-11-27T11:00:00Z" })
    assert.equal(live.usageIsLastGood, false)
    assert.equal(live.fiveHour.usedPercent, 20)
}

// spend needs a non-negative amount and a positive limit
{
    const spendOf = spend => accounts({ schemaVersion: 1, activeAccountNumber: 1,
                                        accounts: [row({ number: 1, active: true, usage: { spend: spend } })] })[0].spend
    assert.deepEqual(plain(spendOf({ used: 3, limit: 10, pct: 30, currency: "USD" })),
        { used: 3, limit: 10, currency: "USD", usedPercent: 30, resetsAt: null, usageKnown: true })
    assert.equal(spendOf({ used: 3, limit: 0, pct: 30 }), null)
    assert.equal(spendOf({ used: -1, limit: 10, pct: 0 }), null)
}

// the top-level shape stays strict
assert.equal(list({ schemaVersion: 2, activeAccountNumber: null, accounts: [] }).ok, false)
assert.equal(list({ schemaVersion: 1, accounts: [] }).ok, false)
assert.equal(list({ schemaVersion: 1, activeAccountNumber: 2, accounts: [row({ number: 1, active: true })] }).ok, false)
assert.equal(lib.parseList("not json", now).ok, false)

console.log("Claude account tests passed")
