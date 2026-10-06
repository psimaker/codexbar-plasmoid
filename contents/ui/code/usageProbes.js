// One `codexbar usage` probe per provider at a time. A refresh while a probe
// runs shares its answer instead of starting another process, unless it
// needs a newer one: it runs another command (a changed source, status flag,
// environment file or CLI path) or must not reuse an answer fetched before
// it (a manual refresh, a config.json write, a Claude account switch). Such
// a refresh waits and runs once the probe is done; the running probe's
// answer then no longer counts.
.pragma library

// running: { provider: { command, generation } }, queued: { provider: true }
function initialState() {
    return { running: {}, queued: {} }
}

function copy(state) {
    return {
        running: Object.assign({}, state.running),
        queued: Object.assign({}, state.queued)
    }
}

// A refresh of `provider` with `command` during CLI check `generation`;
// `fresh` when it needs an answer fetched after it. Returns { state, start }:
// start says to run the probe now. A probe of an older CLI check does not
// hold a new one back; its answer is dropped anyway.
function request(state, provider, command, generation, fresh) {
    var next = copy(state)
    var running = next.running[provider]
    if (running && running.generation === generation) {
        if (fresh === true || running.command !== command)
            next.queued[provider] = true
        return { state: next, start: false }
    }
    next.running[provider] = { command: command, generation: generation }
    delete next.queued[provider]
    return { state: next, start: true }
}

// The probe of `provider` started during CLI check `generation` finished.
// Returns { state, accept, rerun }: accept says its answer counts, rerun that
// a refresh waited for it and should run now.
function finish(state, provider, generation) {
    var running = state.running[provider]
    if (!running || running.generation !== generation)
        return { state: state, accept: false, rerun: false }
    var next = copy(state)
    var rerun = next.queued[provider] === true
    delete next.running[provider]
    delete next.queued[provider]
    return { state: next, accept: !rerun, rerun: rerun }
}
