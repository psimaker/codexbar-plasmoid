#!/usr/bin/env node

const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const source = fs.readFileSync(
    path.join(__dirname, "..", "contents", "ui", "code", "providerSources.js"),
    "utf8"
).replace(/^\.pragma library$/m, "")
const lib = {}
vm.createContext(lib)
vm.runInContext(source, lib, { filename: "providerSources.js" })

// objects cross the vm boundary with a foreign prototype; compare plain copies
function plain(value) { return JSON.parse(JSON.stringify(value)) }

// parsing tolerates junk and normalizes case
assert.deepEqual(plain(lib.parse("opencodego=api, claude=OAuth ,,bogus,=api,kilo=nope")),
    { opencodego: "api", claude: "oauth" })
assert.deepEqual(plain(lib.parse(undefined)), {})
assert.deepEqual(plain(lib.parse("codex=auto")), {})

// serialization is stable and drops the default
assert.equal(lib.serialize({ kilo: "cli", claude: "oauth", codex: "auto" }), "claude=oauth,kilo=cli")

// lookups
assert.equal(lib.sourceFor("opencodego=api", "opencodego"), "api")
assert.equal(lib.sourceFor("opencodego=api", "claude"), "auto")
assert.equal(lib.sourceFor("", "claude"), "auto")

// updates
assert.equal(lib.withSource("", "opencodego", "api"), "opencodego=api")
assert.equal(lib.withSource("opencodego=api", "claude", "web"), "claude=web,opencodego=api")
assert.equal(lib.withSource("claude=web,opencodego=api", "claude", "auto"), "opencodego=api")
assert.equal(lib.withSource("opencodego=api", "opencodego", "invalid"), "")
assert.equal(lib.withSource("opencodego=api", "", "api"), "opencodego=api")

// CLI arguments
assert.equal(lib.cliArguments("opencodego=api", "opencodego"), " --source api")
assert.equal(lib.cliArguments("opencodego=api", "codex"), "")
assert.equal(lib.cliArguments("", "codex"), "")

// A page that stays open follows sources changed underneath it, except the
// ones it changed itself.
// nothing changed on the page: take the settings' sources
assert.equal(lib.rebase("claude=oauth", "claude=oauth", "claude=cli,codex=api"), "claude=cli,codex=api")
// the page set Codex to API; Claude was changed underneath
assert.equal(lib.rebase("claude=oauth", "claude=oauth,codex=api", "claude=web"), "claude=web,codex=api")
// the page set Claude back to Auto, which wins over the newer setting
assert.equal(lib.rebase("claude=oauth", "", "claude=web"), "")
// a source removed underneath and untouched on the page goes
assert.equal(lib.rebase("claude=oauth,kilo=cli", "claude=oauth,kilo=cli", "kilo=cli"), "kilo=cli")
// the page's own Apply comes back unchanged
assert.equal(lib.rebase("claude=oauth", "claude=cli", "claude=cli"), "claude=cli")

console.log("Provider source tests passed")
