// Shared CodexBar CLI compatibility and probe state.
// Keep the minimum supported version in this file only.
var MINIMUM_VERSION = "0.43.0"

var UNKNOWN = "unknown"
var CHECKING = "checking"
var AVAILABLE = "available"
var MISSING = "missing"
var TIMEOUT = "timeout"
var INCOMPATIBLE = "incompatible"
var UNEXPECTED = "unexpected"

var REASON_NONE = ""
var REASON_VERSION_TOO_OLD = "version-too-old"
var REASON_CRASHED = "crashed"
var REASON_VERSION_UNRECOGNIZED = "version-unrecognized"
var REASON_VERSION_FAILED = "version-failed"

function initialState() {
    return {
        code: UNKNOWN,
        reason: REASON_NONE,
        generation: 0,
        detectedVersion: "",
        usageSucceeded: false,
        usageFailure: ""
    }
}

function copyState(state) {
    return {
        code: state.code,
        reason: state.reason,
        generation: state.generation,
        detectedVersion: state.detectedVersion,
        usageSucceeded: state.usageSucceeded,
        usageFailure: state.usageFailure
    }
}

function beginCheck(state) {
    var next = initialState()
    next.code = CHECKING
    next.generation = state && typeof state.generation === "number"
        ? state.generation + 1 : 1
    return next
}

function executableForPath(configuredPath) {
    var value = typeof configuredPath === "string" ? configuredPath.trim() : ""
    return value.length > 0 ? value : "codexbar"
}

function pathChangeRequiresCheck(previousPath, currentPath) {
    return executableForPath(previousPath) !== executableForPath(currentPath)
}

function parseVersion(output) {
    if (typeof output !== "string")
        return ""
    var cleaned = output.replace(/\x1b\[[0-9;]*[A-Za-z]/g, " ")
    var match = cleaned.match(/(?:^|[^0-9])v?(\d+)\.(\d+)\.(\d+)(?:[-+][0-9A-Za-z.-]+)?(?:$|[^0-9])/)
    if (!match)
        return ""
    return match[1] + "." + match[2] + "." + match[3]
}

function versionParts(version) {
    if (typeof version !== "string" || !/^\d+\.\d+\.\d+$/.test(version))
        return null
    var raw = version.split(".")
    return [parseInt(raw[0], 10), parseInt(raw[1], 10), parseInt(raw[2], 10)]
}

function compareVersions(left, right) {
    var a = versionParts(left)
    var b = versionParts(right)
    if (!a || !b)
        return null
    for (var i = 0; i < 3; i++) {
        if (a[i] < b[i])
            return -1
        if (a[i] > b[i])
            return 1
    }
    return 0
}

function usageFailureCode(exitCode, parseFailed) {
    if (exitCode === 127)
        return MISSING
    if (exitCode === 124 || exitCode === 137)
        return TIMEOUT
    if (exitCode === 139)
        return INCOMPATIBLE
    if (parseFailed || exitCode === 0)
        return UNEXPECTED
    return UNKNOWN
}

function applyVersionResult(state, generation, exitCode, output) {
    if (!state || generation !== state.generation)
        return state

    var next = copyState(state)

    if (exitCode === 139) {
        next.code = INCOMPATIBLE
        next.reason = REASON_CRASHED
        return next
    }

    if (exitCode === 127) {
        if (!next.usageSucceeded)
            next.code = MISSING
        return next
    }

    if (exitCode === 124 || exitCode === 137) {
        if (!next.usageSucceeded)
            next.code = TIMEOUT
        return next
    }

    if (exitCode !== 0) {
        if (!next.usageSucceeded) {
            next.code = next.usageFailure || UNKNOWN
            next.reason = REASON_VERSION_FAILED
        }
        return next
    }

    var version = parseVersion(output)
    if (version === "") {
        if (!next.usageSucceeded) {
            next.code = next.usageFailure || UNKNOWN
            next.reason = REASON_VERSION_UNRECOGNIZED
        }
        return next
    }

    next.detectedVersion = version
    if (compareVersions(version, MINIMUM_VERSION) < 0) {
        next.code = INCOMPATIBLE
        next.reason = REASON_VERSION_TOO_OLD
    } else if (next.usageSucceeded) {
        next.code = AVAILABLE
        next.reason = REASON_NONE
    } else if (next.usageFailure !== "") {
        next.code = next.usageFailure
    } else {
        next.code = AVAILABLE
        next.reason = REASON_NONE
    }
    return next
}

function applyUsageResult(state, generation, exitCode, hasUsage, parseFailed) {
    if (!state || generation !== state.generation)
        return state

    var next = copyState(state)
    if (hasUsage) {
        next.usageSucceeded = true
        next.usageFailure = ""
        if (next.reason !== REASON_VERSION_TOO_OLD && next.reason !== REASON_CRASHED) {
            next.code = AVAILABLE
            next.reason = REASON_NONE
        }
        return next
    }

    if (next.usageSucceeded)
        return next

    next.usageFailure = usageFailureCode(exitCode, parseFailed)
    next.code = next.usageFailure
    if (next.code === INCOMPATIBLE)
        next.reason = REASON_CRASHED
    return next
}

function isSetupRequired(code) {
    return code === MISSING || code === TIMEOUT || code === INCOMPATIBLE
        || code === UNEXPECTED
}

function canRunUsage(code) {
    return code !== CHECKING && code !== MISSING && code !== INCOMPATIBLE
}
