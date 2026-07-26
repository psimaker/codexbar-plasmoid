// Strict, credential-free projection of CodexBar's schema-v1 claude-swap
// adapter. Only display-safe account fields are retained.
.pragma library

var MAX_OUTPUT_BYTES = 262144

function hasOwn(object, key) {
    return Object.prototype.hasOwnProperty.call(object, key)
}

function isObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value)
}

function isPositiveInteger(value) {
    return typeof value === "number" && isFinite(value)
        && Math.floor(value) === value && value > 0
}

function optionalText(object, key) {
    return typeof object[key] === "string" ? object[key].trim() : ""
}

function exceedsUtf8Limit(text, limit) {
    var bytes = 0
    for (var i = 0; i < text.length; i++) {
        var code = text.charCodeAt(i)
        if (code <= 0x7f) {
            bytes += 1
        } else if (code <= 0x7ff) {
            bytes += 2
        } else if (code >= 0xd800 && code <= 0xdbff
                   && i + 1 < text.length) {
            var next = text.charCodeAt(i + 1)
            if (next >= 0xdc00 && next <= 0xdfff) {
                bytes += 4
                i++
            } else {
                bytes += 3
            }
        } else {
            bytes += 3
        }
        if (bytes > limit)
            return true
    }
    return false
}

function parseJson(text, operation) {
    var output = String(text || "")
    if (exceedsUtf8Limit(output, MAX_OUTPUT_BYTES))
        return { ok: false, error: "The Claude account adapter output is too large." }
    var raw = output.trim()
    if (raw.length === 0)
        return { ok: false, error: "The Claude account adapter returned no output." }
    try {
        var value = JSON.parse(raw)
        if (!isObject(value))
            return { ok: false, error: "The Claude account adapter returned an invalid " + operation + " object." }
        return { ok: true, value: value }
    } catch (e) {
        return { ok: false, error: "The Claude account adapter returned invalid JSON." }
    }
}

function errorEnvelope(object) {
    if (!isObject(object.error))
        return ""
    var type = typeof object.error.type === "string" && object.error.type.trim() !== ""
        ? object.error.type.trim() : "Error"
    var message = typeof object.error.message === "string" && object.error.message.trim() !== ""
        ? object.error.message.trim() : "unknown error"
    return type + ": " + message
}

function schemaError(object) {
    if (!hasOwn(object, "schemaVersion") || typeof object.schemaVersion !== "number"
            || !isFinite(object.schemaVersion) || Math.floor(object.schemaVersion) !== object.schemaVersion)
        return "The Claude account adapter output has no numeric schemaVersion."
    if (object.schemaVersion !== 1)
        return "Unsupported Claude account adapter schema version " + object.schemaVersion + "; expected version 1."
    return ""
}

function parseWindow(raw, slot, name) {
    if (raw === undefined || raw === null)
        return { ok: true, value: null }
    if (!isObject(raw))
        return { ok: false, error: "Account " + slot + " has an invalid " + name + " usage window." }
    if (typeof raw.pct !== "number" || !isFinite(raw.pct))
        return { ok: false, error: "Account " + slot + " has an invalid " + name + " usage percentage." }

    var resetsAt = null
    // Some compatible schema-v1 adapters emit an explicit JSON null here.
    if (hasOwn(raw, "resetsAt") && raw.resetsAt !== null) {
        if (typeof raw.resetsAt !== "string" || raw.resetsAt.trim() === ""
                || isNaN(Date.parse(raw.resetsAt)))
            return { ok: false, error: "Account " + slot + " has an invalid " + name + " reset timestamp." }
        resetsAt = raw.resetsAt
    }
    return {
        ok: true,
        value: {
            usedPercent: Math.max(0, Math.min(100, raw.pct)),
            resetsAt: resetsAt,
            usageKnown: true
        }
    }
}

// usage.scoped is additive schema-v1 data. Ignore malformed rows so a future
// model label cannot suppress otherwise valid account-wide windows.
function parseScopedWindows(raw) {
    if (!Array.isArray(raw))
        return []
    var windows = []
    for (var i = 0; i < raw.length; i++) {
        var row = raw[i]
        if (!isObject(row) || typeof row.name !== "string" || row.name.trim() === ""
                || typeof row.pct !== "number" || !isFinite(row.pct))
            continue
        var resetsAt = null
        if (hasOwn(row, "resetsAt")) {
            if (typeof row.resetsAt !== "string" || row.resetsAt.trim() === ""
                    || isNaN(Date.parse(row.resetsAt)))
                continue
            resetsAt = row.resetsAt
        }
        windows.push({
            name: row.name.trim(),
            usedPercent: Math.max(0, Math.min(100, row.pct)),
            resetsAt: resetsAt,
            usageKnown: true
        })
    }
    return windows
}

function parseList(text) {
    var decoded = parseJson(text, "account list")
    if (!decoded.ok)
        return decoded
    var object = decoded.value
    var versionError = schemaError(object)
    if (versionError !== "")
        return { ok: false, error: versionError }
    var reportedError = errorEnvelope(object)
    if (reportedError !== "")
        return { ok: false, error: reportedError }
    if (!Array.isArray(object.accounts))
        return { ok: false, error: "The Claude account adapter output has no accounts array." }
    if (!hasOwn(object, "activeAccountNumber"))
        return { ok: false, error: "The Claude account adapter output has no activeAccountNumber." }
    if (object.activeAccountNumber !== null && !isPositiveInteger(object.activeAccountNumber))
        return { ok: false, error: "The Claude account adapter returned an invalid active account slot." }

    var accounts = []
    var slots = {}
    var activeSlots = []
    for (var i = 0; i < object.accounts.length; i++) {
        var row = object.accounts[i]
        if (!isObject(row))
            return { ok: false, error: "The Claude account adapter returned an invalid account row." }
        if (!isPositiveInteger(row.number))
            return { ok: false, error: "The Claude account adapter returned a non-positive account slot." }
        if (slots[row.number] === true)
            return { ok: false, error: "The Claude account adapter returned duplicate account slot " + row.number + "." }
        slots[row.number] = true
        if (typeof row.active !== "boolean")
            return { ok: false, error: "Account " + row.number + " has no active flag." }
        if (typeof row.usageStatus !== "string")
            return { ok: false, error: "Account " + row.number + " has no usageStatus." }

        var usage = isObject(row.usage) ? row.usage : {}
        var fiveHour = parseWindow(usage.fiveHour, row.number, "five-hour")
        if (!fiveHour.ok)
            return fiveHour
        var sevenDay = parseWindow(usage.sevenDay, row.number, "seven-day")
        if (!sevenDay.ok)
            return sevenDay

        var email = optionalText(row, "email")
        // These are canonical claude-swap schema-v1 identity fields. Keep
        // malformed optional values non-fatal so older/custom adapters remain
        // compatible while giving same-email accounts a useful label.
        var organizationName = optionalText(row, "organizationName")
        var alias = optionalText(row, "alias")
        var displayLabel = alias || organizationName || email
        var account = {
            number: row.number,
            email: email,
            organizationName: organizationName,
            alias: alias,
            displayLabel: displayLabel !== "" ? displayLabel : "Account " + row.number,
            active: row.active,
            usageStatus: row.usageStatus,
            fiveHour: fiveHour.value,
            sevenDay: sevenDay.value,
            scoped: parseScopedWindows(usage.scoped)
        }
        if (row.active)
            activeSlots.push(row.number)
        accounts.push(account)
    }

    var expectedActive = object.activeAccountNumber === null ? [] : [object.activeAccountNumber]
    if (activeSlots.length !== expectedActive.length
            || (activeSlots.length === 1 && activeSlots[0] !== expectedActive[0]))
        return { ok: false, error: "The Claude account adapter active-account fields disagree." }

    accounts.sort(function (a, b) {
        if (a.active !== b.active)
            return a.active ? -1 : 1
        return a.number - b.number
    })
    return {
        ok: true,
        value: {
            activeAccountNumber: object.activeAccountNumber,
            accounts: accounts
        }
    }
}

function parseSwitch(text, requestedSlot) {
    if (!isPositiveInteger(requestedSlot))
        return { ok: false, error: "The requested Claude account slot is invalid." }
    var decoded = parseJson(text, "account switch")
    if (!decoded.ok)
        return decoded
    var object = decoded.value
    var versionError = schemaError(object)
    if (versionError !== "")
        return { ok: false, error: versionError }
    var reportedError = errorEnvelope(object)
    if (reportedError !== "")
        return { ok: false, error: reportedError }
    if (typeof object.switched !== "boolean")
        return { ok: false, error: "The Claude account adapter switch result has no switched flag." }
    if (typeof object.reason !== "string" || object.reason.trim() === "")
        return { ok: false, error: "The Claude account adapter switch result has no reason." }
    if (!hasOwn(object, "from"))
        return { ok: false, error: "The Claude account adapter switch result has no source account." }
    if (object.from !== null
            && (!isObject(object.from) || !isPositiveInteger(object.from.number)))
        return { ok: false, error: "The Claude account adapter switch result has an invalid source account." }
    if (!isObject(object.to) || !isPositiveInteger(object.to.number))
        return { ok: false, error: "The Claude account adapter switch result has no target slot." }
    if (object.to.number !== requestedSlot)
        return { ok: false, error: "The Claude account adapter reported slot " + object.to.number
                    + " after slot " + requestedSlot + " was requested." }
    if (!object.switched && object.reason !== "already-active")
        return { ok: false, error: "Account switch did not complete (" + object.reason + ")." }
    return { ok: true, value: { switched: object.switched, reason: object.reason } }
}

function canActivate(account) {
    if (!account || account.active)
        return false
    return account.usageStatus === "ok" || account.usageStatus === "api_key"
        || account.usageStatus === "unavailable"
}

function statusError(account) {
    if (!account)
        return ""
    switch (account.usageStatus) {
    case "ok":
        return account.fiveHour || account.sevenDay
            || (account.scoped && account.scoped.length > 0)
            ? "" : "No usage windows reported."
    case "token_expired":
        return "Token expired. Switch to this account in the adapter to refresh it."
    case "api_key":
        return "API-key account; subscription usage is unavailable."
    case "keychain_unavailable":
        return "The adapter could not read this account's Keychain entry."
    case "no_credentials":
        return "No stored credentials for this account slot."
    case "unavailable":
        return "Usage fetch failed."
    default:
        return "Unrecognized Claude account adapter status: " + account.usageStatus
    }
}
