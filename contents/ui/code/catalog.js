// Provider catalog extracted from CodexBar (Sources/CodexBarCore/Providers/*).
// Keys are the CLI --provider identifiers of the codexbar CLI.
.pragma library

var PROVIDERS = {
    "codex":        { name: "Codex",              color: "#49A3B0", dashboard: "https://chatgpt.com/codex/settings/usage", status: "https://status.openai.com/", icon: "ProviderIcon-codex.svg", critter: "codex" },
    "claude":       { name: "Claude",             color: "#CC7C5E", dashboard: "https://console.anthropic.com/settings/billing", status: "https://status.claude.com/", icon: "ProviderIcon-claude.svg", critter: "claude" },
    "cursor":       { name: "Cursor",             color: "#00BFA5", dashboard: "https://cursor.com/dashboard?tab=usage", status: "https://status.cursor.com", icon: "ProviderIcon-cursor.svg" },
    "factory":      { name: "Droid",              color: "#FF6B35", dashboard: "https://app.factory.ai/settings/billing", status: "https://status.factory.ai", icon: "ProviderIcon-factory.svg" },
    "gemini":       { name: "Gemini",             color: "#AB87EA", dashboard: "https://gemini.google.com", status: "", icon: "ProviderIcon-gemini.svg" },
    "antigravity":  { name: "Antigravity",        color: "#60BA7E", dashboard: "", status: "", icon: "ProviderIcon-antigravity.svg" },
    "copilot":      { name: "Copilot",            color: "#A855F7", dashboard: "https://github.com/settings/copilot", status: "https://www.githubstatus.com/", icon: "ProviderIcon-copilot.svg" },
    "openai":       { name: "OpenAI",             color: "#10A37F", dashboard: "https://platform.openai.com/usage", status: "https://status.openai.com", icon: "ProviderIcon-codex.svg" },
    "azure-openai": { name: "Azure OpenAI",       color: "#0078D4", dashboard: "https://ai.azure.com", status: "", icon: "ProviderIcon-codex.svg" },
    "opencode":     { name: "OpenCode",           color: "#3B82F6", dashboard: "https://opencode.ai", status: "", icon: "ProviderIcon-opencode.svg" },
    "opencodego":   { name: "OpenCode Go",        color: "#3B82F6", dashboard: "https://opencode.ai", status: "", icon: "ProviderIcon-opencodego.svg" },
    "alibaba-coding-plan": { name: "Alibaba Coding Plan", color: "#FF6A00", dashboard: "", status: "", icon: "ProviderIcon-alibaba.svg" },
    "alibaba-token-plan":  { name: "Alibaba Token Plan",  color: "#FF6A00", dashboard: "", status: "", icon: "ProviderIcon-alibaba.svg" },
    "devin":        { name: "Devin",              color: "#46B482", dashboard: "https://app.devin.ai", status: "", icon: "ProviderIcon-devin.svg" },
    "zai":          { name: "z.ai",               color: "#E85A6A", dashboard: "", status: "", icon: "ProviderIcon-zai.svg" },
    "minimax":      { name: "MiniMax",            color: "#FE603C", dashboard: "https://platform.minimax.io/user-center/payment/coding-plan?cycle_type=3", status: "", icon: "ProviderIcon-minimax.svg" },
    "manus":        { name: "Manus",              color: "#34322D", dashboard: "https://manus.im", status: "", icon: "ProviderIcon-manus.svg" },
    "kimi":         { name: "Kimi",               color: "#FE603C", dashboard: "https://www.kimi.com/code/console", status: "", icon: "ProviderIcon-kimi.svg" },
    "kimik2":       { name: "Kimi K2 (unofficial)", color: "#4C00FF", dashboard: "https://kimrel.com/my-credits", status: "", icon: "ProviderIcon-kimi.svg" },
    "kilo":         { name: "Kilo",               color: "#F27027", dashboard: "https://app.kilo.ai/usage", status: "", icon: "ProviderIcon-kilo.svg" },
    "kiro":         { name: "Kiro",               color: "#FF9900", dashboard: "https://app.kiro.dev/account/usage", status: "", icon: "ProviderIcon-kiro.svg" },
    "vertexai":     { name: "Vertex AI",          color: "#4285F4", dashboard: "https://console.cloud.google.com/vertex-ai", status: "", icon: "ProviderIcon-vertexai.svg" },
    "augment":      { name: "Augment",            color: "#6366F1", dashboard: "https://app.augmentcode.com/account/subscription", status: "https://status.augmentcode.com", icon: "ProviderIcon-augment.svg" },
    "jetbrains":    { name: "JetBrains AI",       color: "#FF3399", dashboard: "", status: "", icon: "ProviderIcon-jetbrains.svg" },
    "moonshot":     { name: "Moonshot / Kimi API", color: "#205DEB", dashboard: "https://platform.moonshot.ai/console/account", status: "", icon: "ProviderIcon-kimi.svg" },
    "amp":          { name: "Amp",                color: "#DC2626", dashboard: "https://ampcode.com/settings/usage", status: "", icon: "ProviderIcon-amp.svg" },
    "t3chat":       { name: "T3 Chat",            color: "#F56647", dashboard: "https://t3.chat/settings/customization", status: "", icon: "ProviderIcon-t3chat.svg" },
    "ollama":       { name: "Ollama",             color: "#888888", dashboard: "https://ollama.com/settings", status: "", icon: "ProviderIcon-ollama.svg" },
    "synthetic":    { name: "Synthetic",          color: "#141414", dashboard: "", status: "", icon: "ProviderIcon-synthetic.svg" },
    "warp":         { name: "Warp",               color: "#938BB4", dashboard: "https://docs.warp.dev/reference/cli/api-keys", status: "", icon: "ProviderIcon-warp.svg" },
    "openrouter":   { name: "OpenRouter",         color: "#6467F2", dashboard: "https://openrouter.ai/settings/credits", status: "", icon: "ProviderIcon-openrouter.svg" },
    "elevenlabs":   { name: "ElevenLabs",         color: "#888888", dashboard: "https://elevenlabs.io/app/developers/usage", status: "", icon: "ProviderIcon-elevenlabs.svg" },
    "windsurf":     { name: "Windsurf",           color: "#34E8BB", dashboard: "https://windsurf.com/subscription/usage", status: "", icon: "ProviderIcon-windsurf.svg" },
    "zed":          { name: "Zed",                color: "#084EFF", dashboard: "", status: "", icon: "ProviderIcon-zed.svg" },
    "perplexity":   { name: "Perplexity",         color: "#20B2AA", dashboard: "https://www.perplexity.ai/account/usage", status: "", icon: "ProviderIcon-perplexity.svg" },
    "mimo":         { name: "Xiaomi MiMo",        color: "#888888", dashboard: "https://platform.xiaomimimo.com/#/console/balance", status: "", icon: "ProviderIcon-mimo.svg" },
    "doubao":       { name: "Doubao",             color: "#3370FF", dashboard: "", status: "", icon: "ProviderIcon-doubao.svg" },
    "sakana":       { name: "Sakana AI",          color: "#888888", dashboard: "https://console.sakana.ai/billing", status: "", icon: "ProviderIcon-sakana.svg" },
    "abacusai":     { name: "Abacus AI",          color: "#38BDF8", dashboard: "https://apps.abacus.ai/chatllm/admin/compute-points-usage", status: "", icon: "ProviderIcon-abacus.svg" },
    "mistral":      { name: "Mistral",            color: "#FF500F", dashboard: "https://admin.mistral.ai/organization/usage", status: "", icon: "ProviderIcon-mistral.svg" },
    "deepseek":     { name: "DeepSeek",           color: "#888888", dashboard: "https://platform.deepseek.com/usage", status: "", icon: "ProviderIcon-deepseek.svg" },
    "codebuff":     { name: "Codebuff",           color: "#44FF00", dashboard: "https://www.codebuff.com/usage", status: "", icon: "ProviderIcon-codebuff.svg" },
    "crof":         { name: "Crof",               color: "#888888", dashboard: "https://crof.ai/dashboard", status: "", icon: "ProviderIcon-crof.svg" },
    "venice":       { name: "Venice",             color: "#888888", dashboard: "https://venice.ai/settings/api", status: "", icon: "ProviderIcon-venice.svg" },
    "commandcode":  { name: "Command Code",       color: "#555555", dashboard: "https://commandcode.ai/studio", status: "", icon: "ProviderIcon-commandcode.svg" },
    "qoder":        { name: "Qoder",              color: "#10B981", dashboard: "", status: "", icon: "ProviderIcon-qoder.svg" },
    "stepfun":      { name: "StepFun",            color: "#888888", dashboard: "https://platform.stepfun.com/plan-usage", status: "", icon: "ProviderIcon-stepfun.svg" },
    "bedrock":      { name: "AWS Bedrock",        color: "#FF9900", dashboard: "https://console.aws.amazon.com/bedrock", status: "", icon: "ProviderIcon-bedrock.svg" },
    "grok":         { name: "Grok",               color: "#10A37F", dashboard: "https://grok.com/?_s=usage", status: "", icon: "ProviderIcon-grok.svg" },
    "groqcloud":    { name: "Groq",               color: "#F56844", dashboard: "https://console.groq.com/dashboard/metrics", status: "", icon: "ProviderIcon-groq.svg" },
    "llmproxy":     { name: "LLM Proxy",          color: "#24B47E", dashboard: "", status: "", icon: "ProviderIcon-llmproxy.svg" },
    "litellm":      { name: "LiteLLM",            color: "#4C89F0", dashboard: "", status: "", icon: "ProviderIcon-litellm.svg" },
    "deepgram":     { name: "Deepgram",           color: "#888888", dashboard: "https://console.deepgram.com/project/", status: "", icon: "ProviderIcon-deepgram.svg" },
    "poe":          { name: "Poe",                color: "#5D5CDE", dashboard: "https://poe.com/api/keys", status: "", icon: "ProviderIcon-poe.svg" },
    "chutes":       { name: "Chutes",             color: "#3184FF", dashboard: "https://chutes.ai", status: "", icon: "ProviderIcon-chutes.svg" },
    "crossmodel":   { name: "CrossModel",         color: "#7C3AED", dashboard: "https://crossmodel.ai/console/usage", status: "", icon: "ProviderIcon-crossmodel.svg" },
    "clawrouter":   { name: "ClawRouter",         color: "#596EF6", dashboard: "https://clawrouter.openclaw.ai/dashboard/access", status: "", icon: "ProviderIcon-clawrouter.svg" },
    "wayfinder":    { name: "Wayfinder",          color: "#10A37F", dashboard: "", status: "", icon: "ProviderIcon-wayfinder.svg" }
}

// Providers whose local logs the `codexbar cost` command can price.
var COST_PROVIDERS = ["claude", "codex"]

function meta(id) {
    return PROVIDERS[id] || { name: id, color: "#888888", dashboard: "", status: "", icon: "" }
}

function orderedIds() {
    return Object.keys(PROVIDERS)
}

// --- formatting helpers (mirror CodexBar's UsageFormatter) ---

function compactTokens(n) {
    if (n === undefined || n === null) return ""
    var sign = n < 0 ? "-" : ""
    var a = Math.abs(n)
    if (a < 1e3) return sign + Math.round(a)
    var units = [[1e9, "B"], [1e6, "M"], [1e3, "K"]]
    var idx = 0
    while (idx < units.length - 1 && a < units[idx][0]) idx++
    function fmt(v) { return v >= 10 ? String(Math.round(v)) : String(Math.round(v * 10) / 10) }
    var s = fmt(a / units[idx][0])
    // rounding can push across the unit boundary (999500 -> "1000K" -> "1M")
    if (parseFloat(s) >= 1000 && idx > 0) {
        idx--
        s = fmt(a / units[idx][0])
    }
    return sign + s + units[idx][1]
}

function money(v) {
    if (v === undefined || v === null) return ""
    return "$ " + v.toFixed(2)
}

// "Resets in 3h 53m" / "Resets in 3d 20h" — like the original menu rows.
// Falls back to the CLI's resetDescription when no exact timestamp exists.
function resetText(win, nowMs) {
    if (!win) return ""
    if (win.resetsAt) {
        var t = Date.parse(win.resetsAt)
        if (!isNaN(t)) {
            var s = Math.floor((t - nowMs) / 1000)
            if (s <= 0) return "Resets now"
            return "Resets in " + duration(s)
        }
    }
    if (win.resetDescription) {
        var desc = win.resetDescription.trim()
        return desc.toLowerCase().indexOf("reset") === 0 ? desc : "Resets " + desc
    }
    return ""
}

function duration(s) {
    // round remaining time UP to whole minutes and drop zero sub-units,
    // matching the upstream UsageFormatter
    var totalMin = Math.max(1, Math.ceil(s / 60))
    var d = Math.floor(totalMin / 1440)
    var h = Math.floor((totalMin % 1440) / 60)
    var m = totalMin % 60
    if (d > 0) return h > 0 ? d + "d " + h + "h" : d + "d"
    if (h > 0) return m > 0 ? h + "h " + m + "m" : h + "h"
    return m + "m"
}

function updatedText(isoDate, nowMs) {
    if (!isoDate) return ""
    var t = Date.parse(isoDate)
    if (isNaN(t)) return ""
    // clamp future timestamps (clock skew) to "just now"
    var s = Math.max(0, Math.floor((nowMs - t) / 1000))
    if (s < 90) return "Updated just now"
    if (s < 3600) return "Updated " + Math.floor(s / 60) + "m ago"
    if (s < 86400) return "Updated " + Math.floor(s / 3600) + "h ago"
    return "Updated " + Math.floor(s / 86400) + "d ago"
}

// --- rate-window helpers (synthetic placeholders, unknown usage) ---

// The CLI marks windows it invented as isSyntheticPlaceholder; treat those
// as absent everywhere.
function usableWindow(w) {
    if (!w) return null
    if (w.isSyntheticPlaceholder === true) return null
    return w
}

function windowUsageKnown(w) {
    return w && w.usageKnown !== false && w.usedPercent !== undefined
}

function windowUsedText(w) {
    return windowUsageKnown(w) ? String(w.usedPercent) : "–"
}

function windowBarPercent(w) {
    return windowUsageKnown(w) ? w.usedPercent : 0
}

// Menu pace line, e.g. "Pace: 24% in reserve · Lasts until reset"
// built from the CLI's pace.summary ("24% in reserve | Expected 51% used | Lasts until reset")
function paceLine(pace) {
    if (!pace || !pace.summary) return ""
    var parts = pace.summary.split("|").map(function (p) { return p.trim() })
    var keep = parts.filter(function (p) { return p.indexOf("Expected") !== 0 })
    if (keep.length === 0) return ""
    return "Pace: " + keep.join(" · ")
}

// Section title for a rate window ("Session", "Weekly", "Monthly", or a custom title)
function windowTitle(windowMinutes, fallback) {
    if (windowMinutes === 300) return "Session"
    if (windowMinutes === 10080) return "Weekly"
    if (windowMinutes >= 40000 && windowMinutes <= 46000) return "Monthly"
    return fallback
}

// Plan text like the original card's top-right label
function planText(entry) {
    if (!entry || !entry.usage) return ""
    var lm = entry.usage.loginMethod || (entry.usage.identity ? entry.usage.identity.loginMethod : "")
    if (!lm) return ""
    var map = {
        "prolite": "Pro 5x", "pro": "Pro", "plus": "Plus", "free": "Free",
        "team": "Team", "business": "Business", "enterprise": "Enterprise", "edu": "Edu",
        "max": "Max", "max5x": "Max 5x", "max20x": "Max 20x", "apikey": "API key"
    }
    return map[lm] || (lm.charAt(0).toUpperCase() + lm.slice(1))
}

function statusColor(indicator) {
    switch (indicator) {
    case "none": return "#2BB673"
    case "minor": return "#F5A623"
    case "major": return "#F57C23"
    case "critical": return "#E0443E"
    default: return "#999999"
    }
}
