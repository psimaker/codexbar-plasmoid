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

// Weekly windows (sevenDay and scoped, never fiveHour) additively carry the
// adapter's own pace verdict. Reading it beats recomputing one locally: the
// adapter measures against the real fetch time and applies its own suppression
// rules for the first day or so of the week. Its projected-exhaustion fields
// are deliberately not read — claude-swap keeps that linear extrapolation out
// of every human surface because the error bars are too wide to state as fact.
function parsePace(raw) {
    return {
        expectedPct: (typeof raw.expectedPct === "number" && isFinite(raw.expectedPct))
            ? Math.max(0, Math.min(100, raw.expectedPct)) : null,
        aheadOfPace: typeof raw.aheadOfPace === "boolean" ? raw.aheadOfPace : null
    }
}

function parseWindow(raw, slot, name, weekly) {
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
    var pace = weekly === true ? parsePace(raw) : { expectedPct: null, aheadOfPace: null }
    return {
        ok: true,
        value: {
            usedPercent: Math.max(0, Math.min(100, raw.pct)),
            resetsAt: resetsAt,
            expectedPct: pace.expectedPct,
            aheadOfPace: pace.aheadOfPace,
            usageKnown: true
        }
    }
}

// usage.spend is additive schema-v1 pay-as-you-go data, and per-account: the
// CodexBar CLI can only report cost for whichever account is currently active.
// Malformed values are ignored rather than fatal, matching parseScopedWindows,
// so an unfamiliar spend shape cannot suppress the usage windows next to it.
function parseSpend(raw) {
    if (!isObject(raw))
        return null
    if (typeof raw.pct !== "number" || !isFinite(raw.pct)
            || typeof raw.used !== "number" || !isFinite(raw.used)
            || typeof raw.limit !== "number" || !isFinite(raw.limit))
        return null
    var resetsAt = null
    if (hasOwn(raw, "resetsAt") && raw.resetsAt !== null
            && typeof raw.resetsAt === "string" && raw.resetsAt.trim() !== ""
            && !isNaN(Date.parse(raw.resetsAt)))
        resetsAt = raw.resetsAt
    return {
        used: raw.used,
        limit: raw.limit,
        currency: typeof raw.currency === "string" ? raw.currency.trim() : "",
        usedPercent: Math.max(0, Math.min(100, raw.pct)),
        resetsAt: resetsAt,
        usageKnown: true
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
        // Match account-wide windows: an explicit JSON null means the adapter
        // has no reset timestamp, not that the scoped window is malformed.
        if (hasOwn(row, "resetsAt") && row.resetsAt !== null) {
            if (typeof row.resetsAt !== "string" || row.resetsAt.trim() === ""
                    || isNaN(Date.parse(row.resetsAt)))
                continue
            resetsAt = row.resetsAt
        }
        var pace = parsePace(row)
        windows.push({
            name: row.name.trim(),
            usedPercent: Math.max(0, Math.min(100, row.pct)),
            resetsAt: resetsAt,
            expectedPct: pace.expectedPct,
            aheadOfPace: pace.aheadOfPace,
            usageKnown: true
        })
    }
    return windows
}

// Optional per-account usage freshness. schema-v1 adapters may report when
// each account's usage was measured so cached or last-known values are not
// shown as fresh. The ISO 8601 timestamp wins; the non-negative age in seconds
// is measured back from the poll time. Absent or malformed values yield null,
// which makes the card fall back to the dataset poll timestamp.
function parseMeasuredAt(row, nowMs, timestampKey, ageSecondsKey) {
    if (hasOwn(row, timestampKey) && row[timestampKey] !== null) {
        if (typeof row[timestampKey] === "string" && row[timestampKey].trim() !== "") {
            var ms = Date.parse(row[timestampKey])
            if (!isNaN(ms))
                return ms
        }
        return null
    }
    if (hasOwn(row, ageSecondsKey) && row[ageSecondsKey] !== null) {
        if (typeof row[ageSecondsKey] === "number" && isFinite(row[ageSecondsKey])
                && row[ageSecondsKey] >= 0)
            return nowMs - Math.floor(row[ageSecondsKey] * 1000)
        return null
    }
    return null
}

// A live measurement is stamped with usageFetchedAt/usageAgeSeconds; the
// last-known fallback carries the same pair renamed for lastGoodUsage.
function parseUsageMeasuredAt(row, nowMs, usageIsLastGood) {
    return usageIsLastGood
        ? parseMeasuredAt(row, nowMs, "lastGoodFetchedAt", "lastGoodAgeSeconds")
        : parseMeasuredAt(row, nowMs, "usageFetchedAt", "usageAgeSeconds")
}

function parseList(text, nowMs) {
    if (nowMs === undefined)
        nowMs = Date.now()
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

        // A schema-v1 row carries either a live `usage` object or, once a fetch
        // fails, a display-grade `lastGoodUsage` fallback in the same shape with
        // its own measurement timestamps. Project both through the one strict
        // window parser so cached windows are shown as non-current rather than
        // dropped, and never let a fallback masquerade as a live measurement.
        var live = isObject(row.usage) ? row.usage : null
        var lastGood = live === null && isObject(row.lastGoodUsage) ? row.lastGoodUsage : null
        var usageIsLastGood = lastGood !== null
        var usage = live || lastGood || {}
        var windowLabel = usageIsLastGood ? "last-known " : ""
        var fiveHour = parseWindow(usage.fiveHour, row.number, windowLabel + "five-hour", false)
        if (!fiveHour.ok)
            return fiveHour
        var sevenDay = parseWindow(usage.sevenDay, row.number, windowLabel + "seven-day", true)
        if (!sevenDay.ok)
            return sevenDay

        var email = optionalText(row, "email")
        // These are canonical claude-swap schema-v1 identity fields. Keep
        // malformed optional values non-fatal so older/custom adapters remain
        // compatible while giving same-email accounts a useful label.
        var organizationName = optionalText(row, "organizationName")
        var alias = optionalText(row, "alias")
        var displayLabel = alias || organizationName || email
        // Additive: claude-swap sets this from whether the account has an
        // organization uuid, without exposing the uuid itself. organizationName
        // already carries the org's name when known, so this only adds
        // information when the name is absent — an org account whose name a
        // compatible adapter could not resolve is still worth telling apart
        // from a personal one instead of silently falling back to email.
        var isOrganization = typeof row.isOrganization === "boolean" ? row.isOrganization : null
        var account = {
            number: row.number,
            email: email,
            organizationName: organizationName,
            isOrganization: isOrganization,
            alias: alias,
            displayLabel: displayLabel !== "" ? displayLabel : "Account " + row.number,
            active: row.active,
            // Additive schema-v1 flag, emitted only for slots the user held
            // out of automatic rotation. Such a slot stays a valid explicit
            // switch target, so this is display-only and never gates the
            // switch action.
            disabled: row.disabled === true,
            usageStatus: row.usageStatus,
            fiveHour: fiveHour.value,
            sevenDay: sevenDay.value,
            scoped: parseScopedWindows(usage.scoped),
            spend: parseSpend(usage.spend),
            usageIsLastGood: usageIsLastGood,
            usageMeasuredAt: parseUsageMeasuredAt(row, nowMs, usageIsLastGood)
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

var MAX_SWITCH_WARNINGS = 6

// A schema-v1 switch result carries warnings that exist nowhere else: in --json
// mode the adapter routes them into the payload instead of stderr, and they
// report credential damage the user has to act on (live tokens wiped by Claude
// Code, a foreign credential left in place, a session-mode instance racing the
// default login). A switch can report switched: true and still warn, so these
// are surfaced independently of the success path.
function parseWarnings(raw) {
    if (!Array.isArray(raw))
        return []
    var warnings = []
    var dropped = 0
    for (var i = 0; i < raw.length; i++) {
        if (typeof raw[i] !== "string" || raw[i].trim() === "")
            continue
        if (warnings.length >= MAX_SWITCH_WARNINGS) {
            dropped++
            continue
        }
        warnings.push(raw[i].trim())
    }
    // Say what was held back rather than truncating a credential warning away.
    if (dropped > 0)
        warnings.push(dropped + " more adapter warning(s) not shown.")
    return warnings
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
    var warnings = parseWarnings(object.warnings)
    if (!object.switched && object.reason !== "already-active")
        return {
            ok: false,
            error: "Account switch did not complete (" + object.reason + ").",
            warnings: warnings
        }
    return {
        ok: true,
        value: { switched: object.switched, reason: object.reason, warnings: warnings }
    }
}

// The adapter's pace verdict, phrased in the vocabulary the CLI-backed cards
// already use. There is no exhaustion estimate here on purpose; see parsePace.
function paceText(win) {
    if (!win || typeof win.expectedPct !== "number")
        return ""
    var delta = win.usedPercent - win.expectedPct
    var magnitude = Math.round(Math.abs(delta))
    if (win.aheadOfPace === true)
        return magnitude > 0 ? "Pace: " + magnitude + "% in deficit" : "Pace: Ahead of pace"
    if (magnitude === 0 || Math.abs(delta) <= 2)
        return "Pace: On pace"
    return "Pace: " + magnitude + "% " + (delta > 0 ? "in deficit" : "in reserve")
}

// Statuses an explicit switch can act on. "unavailable" only means the usage
// fetch failed, and both credential faults below are what a switch repairs:
// switching refreshes an expired token, and it stashes a foreign credential
// before restoring the slot's own. The remaining statuses need the user to
// re-login or unlock a keychain first, so they stay non-actionable here
// instead of offering a button that cannot succeed.
var SWITCHABLE_STATUSES = ["ok", "api_key", "unavailable", "token_expired", "foreign_credential"]

function canActivate(account) {
    if (!account || account.active)
        return false
    return SWITCHABLE_STATUSES.indexOf(account.usageStatus) >= 0
}

// Only adds a tag when organizationName is empty and isOrganization was
// reported: an org account whose name is unresolvable still shouldn't read as
// personal, and claude-swap's own displays use exactly this org-name-or-
// "personal" tag once the name is missing (see its _get_display_tag).
function organizationTag(account) {
    if (!account || account.organizationName || account.isOrganization === null)
        return ""
    return account.isOrganization ? "Organization" : "Personal"
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
        return "Token expired. Switch to this account to refresh it."
    case "foreign_credential":
        return "The stored credential belongs to another account. Switch to this account to repair it."
    case "relogin_required":
        return "The stored login is no longer valid. Re-login with the adapter to restore this account."
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
