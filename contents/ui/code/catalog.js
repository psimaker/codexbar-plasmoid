// Provider catalog extracted from CodexBar (Sources/CodexBarCore/Providers/*).
// Keys are the CLI --provider identifiers of the codexbar CLI; `minCli` marks
// providers that older CLI releases within the supported range do not know.
// `logoColor` marks a fully colored logo (its dominant intrinsic color);
// `chipColor` replaces a brand color too light to carry the white logo.
.pragma library

var PROVIDERS = {
    // Order follows `codexbar usage --help` (CodexBar 0.72.0).
    "codex":        { name: "Codex",              color: "#49A3B0", dashboard: "https://chatgpt.com/codex/cloud/settings/analytics#usage", status: "https://status.openai.com/", icon: "ProviderIcon-codex.svg", critter: "codex" },
    "openai":       { name: "OpenAI",             color: "#0F826E", dashboard: "https://platform.openai.com/usage", status: "https://status.openai.com", icon: "ProviderIcon-codex.svg" },
    "azure-openai": { name: "Azure OpenAI",       color: "#0078D4", dashboard: "https://ai.azure.com", status: "https://azure.status.microsoft/en-us/status", icon: "ProviderIcon-codex.svg" },
    "claude":       { name: "Claude",             color: "#CC7C5E", dashboard: "https://console.anthropic.com/settings/billing", status: "https://status.claude.com/", icon: "ProviderIcon-claude.svg", critter: "claude" },
    "clinepass":    { name: "ClinePass",          color: "#5487C8", dashboard: "https://app.cline.bot/dashboard/subscription?personal=true", status: "", icon: "ProviderIcon-clinepass.svg", minCli: "0.44.0" },
    "cursor":       { name: "Cursor",             color: "#F54E00", dashboard: "https://cursor.com/dashboard?tab=usage", status: "https://status.cursor.com", icon: "ProviderIcon-cursor.svg" },
    "opencode":     { name: "OpenCode",           color: "#3B82F6", dashboard: "https://opencode.ai/auth", status: "", icon: "ProviderIcon-opencode.svg" },
    "opencodego":   { name: "OpenCode Go",        color: "#3B82F6", dashboard: "https://opencode.ai/auth", status: "", icon: "ProviderIcon-opencodego.svg" },
    "alibaba-coding-plan": { name: "Alibaba Coding Plan", color: "#FF6A00", dashboard: "https://modelstudio.console.alibabacloud.com/ap-southeast-1/?tab=coding-plan#/efm/coding_plan", status: "https://status.aliyun.com", icon: "ProviderIcon-alibaba.svg" },
    "alibaba-token-plan":  { name: "Alibaba Token Plan",  color: "#FF6A00", dashboard: "https://modelstudio.console.alibabacloud.com/ap-southeast-1/?tab=plan#/efm/subscription/token-plan", status: "https://status.aliyun.com", icon: "ProviderIcon-alibaba.svg" },
    "qwen-cloud":   { name: "Qwen Cloud",         color: "#615CED", dashboard: "https://home.qwencloud.com/billing/subscription/token-plan-individual", status: "https://status.alibabacloud.com", icon: "ProviderIcon-qwencloud.svg", minCli: "0.46.0" },
    "factory":      { name: "Droid",              color: "#FF6B35", dashboard: "https://app.factory.ai/settings/billing", status: "https://status.factory.ai", icon: "ProviderIcon-factory.svg" },
    "fireworks":    { name: "Fireworks",          color: "#F25B1C", dashboard: "https://app.fireworks.ai", status: "", icon: "ProviderIcon-fireworks.svg" },
    "gemini":       { name: "Gemini",             color: "#AB87EA", dashboard: "https://gemini.google.com", status: "https://www.google.com/appsstatus/dashboard/products/npdyhgECDJ6tB66MxXyo/history", icon: "ProviderIcon-gemini.svg" },
    "antigravity":  { name: "Antigravity",        color: "#60BA7E", dashboard: "", status: "https://www.google.com/appsstatus/dashboard/products/npdyhgECDJ6tB66MxXyo/history", icon: "ProviderIcon-antigravity.svg" },
    "copilot":      { name: "Copilot",            color: "#A855F7", dashboard: "https://github.com/settings/copilot", status: "https://www.githubstatus.com/", icon: "ProviderIcon-copilot.svg" },
    "devin":        { name: "Devin",              color: "#317CFF", dashboard: "https://app.devin.ai", status: "", icon: "ProviderIcon-devin.svg" },
    "zai":          { name: "z.ai / GLM",         color: "#E85A6A", dashboard: "https://z.ai/manage-apikey/coding-plan/personal/my-plan", status: "", icon: "ProviderIcon-zai.svg" },
    "minimax":      { name: "MiniMax",            color: "#FE603C", dashboard: "https://platform.minimax.io/user-center/payment/coding-plan?cycle_type=3", status: "", icon: "ProviderIcon-minimax.svg" },
    "manus":        { name: "Manus",              color: "#34322D", dashboard: "https://manus.im", status: "", icon: "ProviderIcon-manus.svg" },
    "kimi":         { name: "Kimi Code",          color: "#FE603C", dashboard: "https://www.kimi.com/code/console", status: "", icon: "ProviderIcon-kimi.svg" },
    "kilo":         { name: "Kilo",               color: "#F27027", dashboard: "https://app.kilo.ai/usage", status: "", icon: "ProviderIcon-kilo.svg" },
    "kiro":         { name: "Kiro",               color: "#9046FF", dashboard: "https://app.kiro.dev/account/usage", status: "https://health.aws.amazon.com/health/status", icon: "ProviderIcon-kiro.svg" },
    "vertexai":     { name: "Vertex AI",          color: "#4285F4", dashboard: "https://console.cloud.google.com/vertex-ai", status: "https://status.cloud.google.com", icon: "ProviderIcon-vertexai.svg" },
    "augment":      { name: "Augment",            color: "#1AA049", dashboard: "https://app.augmentcode.com/account/subscription", status: "https://status.augmentcode.com", icon: "ProviderIcon-augment.svg" },
    "jetbrains":    { name: "JetBrains AI",       color: "#FF3399", dashboard: "", status: "", icon: "ProviderIcon-jetbrains.svg" },
    "moonshot":     { name: "Moonshot / Kimi Open Platform", color: "#205DEB", dashboard: "https://platform.moonshot.ai/console/account", status: "", icon: "ProviderIcon-kimi.svg" },
    "amp":          { name: "Amp",                color: "#F34E3F", dashboard: "https://ampcode.com/settings/usage", status: "", icon: "ProviderIcon-amp.svg" },
    "t3chat":       { name: "T3 Chat",            color: "#F56647", dashboard: "https://t3.chat/settings/customization", status: "", icon: "ProviderIcon-t3chat.svg" },
    "ollama":       { name: "Ollama",             color: "#888888", dashboard: "https://ollama.com/settings", status: "", icon: "ProviderIcon-ollama.svg" },
    "synthetic":    { name: "Synthetic",          color: "#141414", dashboard: "", status: "", icon: "ProviderIcon-synthetic.svg" },
    "openrouter":   { name: "OpenRouter",         color: "#6467F2", dashboard: "https://openrouter.ai/activity", status: "https://status.openrouter.ai", icon: "ProviderIcon-openrouter.svg" },
    "elevenlabs":   { name: "ElevenLabs",         color: "#EBEBE6", chipColor: "#000000", dashboard: "https://elevenlabs.io/app/developers/usage", status: "https://status.elevenlabs.io", icon: "ProviderIcon-elevenlabs.svg" },
    "warp":         { name: "Warp",               color: "#938BB4", dashboard: "https://docs.warp.dev/reference/cli/api-keys", status: "", icon: "ProviderIcon-warp.svg" },
    "windsurf":     { name: "Windsurf",           color: "#34E8BB", dashboard: "https://windsurf.com/subscription/usage", status: "", icon: "ProviderIcon-windsurf.svg" },
    "zed":          { name: "Zed",                color: "#084EFF", dashboard: "", status: "", icon: "ProviderIcon-zed.svg" },
    "perplexity":   { name: "Perplexity",         color: "#20B2AA", dashboard: "https://www.perplexity.ai/account/usage", status: "https://status.perplexity.com/", icon: "ProviderIcon-perplexity.svg" },
    "mimo":         { name: "Xiaomi MiMo",        color: "#FF6900", dashboard: "https://platform.xiaomimimo.com/#/console/balance", status: "", icon: "ProviderIcon-mimo.svg" },
    "doubao":       { name: "Doubao",             color: "#3370FF", logoColor: "#006EFF", dashboard: "https://console.volcengine.com/ark/region:ark+cn-beijing/openManagement?LLM=%7B%7D&advancedActiveKey=subscribe", status: "", icon: "ProviderIcon-doubao.svg" },
    "sakana":       { name: "Sakana AI",          color: "#2975DB", dashboard: "https://console.sakana.ai/billing", status: "", icon: "ProviderIcon-sakana.svg" },
    "abacusai":     { name: "Abacus AI",          color: "#814EE8", dashboard: "https://apps.abacus.ai/chatllm/admin/compute-points-usage", status: "", icon: "ProviderIcon-abacus.svg" },
    "mistral":      { name: "Mistral",            color: "#FF5229", dashboard: "https://admin.mistral.ai/organization/usage", status: "https://status.mistral.ai", icon: "ProviderIcon-mistral.svg" },
    "deepseek":     { name: "DeepSeek",           color: "#4D6BFE", dashboard: "https://platform.deepseek.com/usage", status: "https://status.deepseek.com", icon: "ProviderIcon-deepseek.svg" },
    "deepinfra":    { name: "DeepInfra",          color: "#2A3275", dashboard: "https://deepinfra.com/dash", status: "https://status.deepinfra.com", icon: "ProviderIcon-deepinfra.svg", minCli: "0.45.0" },
    "codebuff":     { name: "Codebuff",           color: "#00FF95", logoColor: "#44FF00", dashboard: "https://www.codebuff.com/usage", status: "", icon: "ProviderIcon-codebuff.svg" },
    "venice":       { name: "Venice",             color: "#3C8FDD", dashboard: "https://venice.ai/settings/api", status: "", icon: "ProviderIcon-venice.svg" },
    "commandcode":  { name: "Command Code",       color: "#8C4EDD", dashboard: "https://commandcode.ai/studio", status: "", icon: "ProviderIcon-commandcode.svg" },
    "qoder":        { name: "Qoder",              color: "#10B981", dashboard: "https://qoder.com/account/usage", status: "", icon: "ProviderIcon-qoder.svg" },
    "stepfun":      { name: "StepFun",            color: "#2196F2", dashboard: "https://platform.stepfun.com/plan-usage", status: "", icon: "ProviderIcon-stepfun.svg" },
    "bedrock":      { name: "AWS Bedrock",        color: "#01A88D", dashboard: "https://console.aws.amazon.com/bedrock", status: "https://health.aws.amazon.com/health/status", icon: "ProviderIcon-bedrock.svg" },
    "grok":         { name: "Grok",               color: "#10A37F", dashboard: "https://grok.com/?_s=usage", status: "https://status.x.ai", icon: "ProviderIcon-grok.svg" },
    "groqcloud":    { name: "Groq",               color: "#F56844", dashboard: "https://console.groq.com/dashboard/usage", status: "https://status.groq.com", icon: "ProviderIcon-groq.svg" },
    "llmproxy":     { name: "LLM Proxy",          color: "#24B47E", dashboard: "", status: "", icon: "ProviderIcon-llmproxy.svg" },
    "litellm":      { name: "LiteLLM",            color: "#4C89F0", dashboard: "", status: "", icon: "ProviderIcon-litellm.svg" },
    "bifrost":      { name: "Bifrost",            color: "#33C09E", dashboard: "", status: "", icon: "ProviderIcon-bifrost.svg", minCli: "0.65.0" },
    "aixy":         { name: "Aixy",               color: "#123650", dashboard: "https://dash.aixy-gateway.com", status: "", icon: "ProviderIcon-aixy.svg", minCli: "0.67.0" },
    "deepgram":     { name: "Deepgram",           color: "#6467F2", dashboard: "https://console.deepgram.com/project/", status: "https://status.deepgram.com", icon: "ProviderIcon-deepgram.svg" },
    "poe":          { name: "Poe",                color: "#5D5CDE", dashboard: "https://poe.com/api/keys", status: "", icon: "ProviderIcon-poe.svg" },
    "chutes":       { name: "Chutes",             color: "#3184FF", dashboard: "https://chutes.ai", status: "", icon: "ProviderIcon-chutes.svg" },
    "neuralwatt":   { name: "Neuralwatt",         color: "#D55934", dashboard: "https://portal.neuralwatt.com/dashboard", status: "", icon: "ProviderIcon-neuralwatt.svg", minCli: "0.44.0" },
    "helmcode":     { name: "Helmcode",           color: "#4934E1", dashboard: "https://cloud.helmcode.com/dashboard", status: "", icon: "ProviderIcon-helmcode.svg", minCli: "0.64.0" },
    "clawrouter":   { name: "ClawRouter",         color: "#596EF6", dashboard: "https://clawrouter.openclaw.ai/dashboard/access", status: "", icon: "ProviderIcon-clawrouter.svg" },
    "longcat":      { name: "LongCat",            color: "#29E154", dashboard: "https://longcat.chat/platform/", status: "", icon: "ProviderIcon-longcat.svg", minCli: "0.44.0" },
    "sub2api":      { name: "sub2api",            color: "#14B8A6", logoColor: "#2DC6D8", dashboard: "", status: "", icon: "ProviderIcon-sub2api.svg" },
    "wayfinder":    { name: "Wayfinder",          color: "#10A37F", dashboard: "", status: "", icon: "ProviderIcon-wayfinder.svg" },
    "zenmux":       { name: "ZenMux",             color: "#6C5CE7", dashboard: "https://zenmux.ai/platform/management", status: "", icon: "ProviderIcon-zenmux.svg", minCli: "0.44.0" },
    "aiand":        { name: "ai&",                color: "#E25C2B", dashboard: "https://console.aiand.com", status: "", icon: "ProviderIcon-aiand.svg", minCli: "0.45.0" },
    "zoommate":     { name: "ZoomMate",           color: "#0B5CFF", logoColor: "#0B5CFF", dashboard: "https://zoommate.zoom.us/#/?settings=credit-usage", status: "https://www.zoomstatus.com/", icon: "ProviderIcon-zoommate.svg", minCli: "0.46.0" },
    "xai":          { name: "xAI",                color: "#8E8E93", dashboard: "https://console.x.ai", status: "https://status.x.ai", icon: "ProviderIcon-xai.svg" },
    "notion":       { name: "Notion AI",          color: "#337EA9", dashboard: "https://app.notion.com/", status: "https://status.notion.so/", icon: "ProviderIcon-notion.svg", minCli: "0.47.0" },
    "ibmbob":       { name: "IBM Bob",            color: "#0E61FA", logoColor: "#0E61FA", dashboard: "https://bob.ibm.com", status: "https://status.bob.ibm.com", icon: "ProviderIcon-ibmbob.svg", minCli: "0.49.0" },
    "nous":         { name: "Nous Portal",        color: "#D6A55C", dashboard: "https://portal.nousresearch.com/usage", status: "", icon: "ProviderIcon-nous.svg", minCli: "0.61.0" },
    "muse":         { name: "Muse Code",          color: "#0668E1", dashboard: "https://dev.meta.ai", status: "", icon: "ProviderIcon-muse.svg", minCli: "0.61.0" },
    "coderabbit":   { name: "CodeRabbit",         color: "#FF5C35", dashboard: "https://app.coderabbit.ai", status: "https://status.coderabbit.ai", icon: "ProviderIcon-coderabbit.svg", minCli: "0.61.0" },
    "replicate":    { name: "Replicate",          color: "#000000", dashboard: "https://replicate.com/account/billing", status: "", icon: "ProviderIcon-replicate.svg", minCli: "0.61.0" },
    "huggingface":  { name: "Hugging Face",       color: "#FFD21E", dashboard: "https://huggingface.co/settings/billing", status: "https://status.huggingface.co", icon: "ProviderIcon-huggingface.svg", minCli: "0.61.0" },
    "raycast":      { name: "Raycast",            color: "#FF6363", dashboard: "https://www.raycast.com/settings", status: "", icon: "ProviderIcon-raycast.svg", minCli: "0.67.0" },
    "pi":           { name: "Pi",                 color: "#7C3AED", dashboard: "https://github.com/badlogic/pi-mono", status: "", icon: "ProviderIcon-pi.svg", minCli: "0.63.0" },
    "v0":           { name: "v0",                 color: "#111111", dashboard: "https://v0.app/settings/billing", status: "", icon: "ProviderIcon-v0.svg", minCli: "0.64.0" },
    "typesafe":     { name: "TypeSafe",           color: "#111111", dashboard: "https://console.typesafe.ai/usage", status: "", icon: "ProviderIcon-typesafe.svg", minCli: "0.64.0" },
    "hyper":        { name: "Charm Hyper",        color: "#FF60FF", dashboard: "https://hyper.charm.land", status: "", icon: "ProviderIcon-hyper.svg", minCli: "0.65.0" },
    "gitkraken":    { name: "GitKraken AI",       color: "#179287", dashboard: "https://gitkraken.dev/account#ai-usage", status: "", icon: "ProviderIcon-gitkraken.svg", minCli: "0.65.0" },
    "devpass":      { name: "DevPass",            color: "#2563EB", dashboard: "https://devpass.llmgateway.io/dashboard", status: "", icon: "ProviderIcon-devpass.svg", minCli: "0.66.0" },
    "atlascloud":   { name: "Atlas Cloud",        color: "#5975F5", dashboard: "https://www.atlascloud.ai/console", status: "", icon: "ProviderIcon-atlascloud.svg", minCli: "0.66.0" },
    "vercel":       { name: "Vercel AI Gateway",  color: "#FFFFFF", chipColor: "#000000", dashboard: "https://vercel.com/d?to=%2F%5Bteam%5D%2F%7E%2Fai-gateway", status: "", icon: "ProviderIcon-vercel.svg", minCli: "0.66.0" },
    "llmman":       { name: "llmman",             color: "#6CC5B0", dashboard: "", status: "", icon: "ProviderIcon-llmman.svg", minCli: "0.66.0" },
    "xkiro":        { name: "xKiro",              color: "#52C99B", dashboard: "https://xkiro.com", status: "", icon: "ProviderIcon-xkiro.svg", minCli: "0.67.0" },
    "museai":       { name: "Muse (muse.ai)",     color: "#0668E1", dashboard: "https://muse.ai/?settings_tab=general", status: "", icon: "ProviderIcon-museai.svg", minCli: "0.71.0" },
    "lithosai":     { name: "LithosAI",           color: "#6B7280", dashboard: "https://console.lithosai.cloud", status: "", icon: "ProviderIcon-lithosai.svg", minCli: "0.71.0" },
    "workbuddy":    { name: "WorkBuddy",          color: "#0DC8A6", dashboard: "https://www.workbuddy.cn/profile/plans-usage", status: "", icon: "ProviderIcon-workbuddy.svg", minCli: "0.72.0" }
}

// Providers whose local logs the `codexbar cost` command can price.
var COST_PROVIDERS = ["claude", "codex"]

// Display names of providers the catalog does not know, such as user plugins
// listed in CodexBar's config.json.
var EXTRA_NAMES = {}

function registerName(id, name) {
    if (PROVIDERS[id] === undefined && typeof name === "string" && name !== "")
        EXTRA_NAMES[id] = name
}

function meta(id) {
    return PROVIDERS[id] || { name: EXTRA_NAMES[id] || id, color: "#888888", dashboard: "", status: "", icon: "" }
}

// A fully colored logo brings its own color and disappears on a chip in the
// same or a nearby shade (upstream brand colors can move while the artwork
// stays). Keep the chip behind such a logo transparent. Themeable logos are
// drawn white, so a near-white brand color gets a darker chip instead.
function logoBackgroundColor(id) {
    var provider = meta(id)
    if (provider.logoColor)
        return "transparent"
    return provider.chipColor || provider.color
}

function orderedIds() {
    return Object.keys(PROVIDERS)
}

// `codexbar usage --json` reports CodexBar's internal provider id, which
// differs from the --provider name for these providers.
var REPORTED_PROVIDER_IDS = {
    "azure-openai": "azureopenai",
    "alibaba-coding-plan": "alibaba",
    "alibaba-token-plan": "alibabatokenplan",
    "qwen-cloud": "qwencloud",
    "abacusai": "abacus",
    "groqcloud": "groq"
}

function reportedProviderId(id) {
    return REPORTED_PROVIDER_IDS[id] || id
}

// The --provider name for an id the CLI reports.
function cliProviderId(reported) {
    for (var id in REPORTED_PROVIDER_IDS) {
        if (REPORTED_PROVIDER_IDS[id] === reported)
            return id
    }
    return reported
}

// The CLI does not reject a --provider name it does not know (a provider
// that is newer than the installed CLI, or one removed upstream); it reports
// the providers enabled in its own config instead. Keep only the entries of
// the requested provider. Entries without a provider field are kept.
function entriesForProvider(entries, id) {
    if (!Array.isArray(entries))
        return []
    var reported = reportedProviderId(id)
    return entries.filter(function (entry) {
        return entry !== null && typeof entry === "object"
            && (typeof entry.provider !== "string"
                || entry.provider === reported || entry.provider === id)
    })
}

// The CLI's own explanation when a usage request fails: the message of the
// provider's error entry, such as a missing login, or of the "cli" entry the
// CLI answers with when it cannot run at all, for example while config.json
// cannot be decoded. Empty when the response holds neither.
function errorForProvider(entries, id) {
    var candidates = entriesForProvider(entries, id).concat(entriesForProvider(entries, "cli"))
    for (var i = 0; i < candidates.length; i++) {
        var error = candidates[i].error
        if (error && typeof error.message === "string" && error.message.trim() !== "")
            return error.message.trim()
    }
    return ""
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

// Extra rate windows report unknown usage on the named entry rather than on
// its window; carry it over so the window helpers treat it as unknown.
function namedWindow(ew) {
    var w = ew ? usableWindow(ew.window) : null
    if (!w || ew.usageKnown !== false)
        return w
    return Object.assign({}, w, { usageKnown: false })
}

// The Kimi endpoint omits `windowMinutes` for its weekly window. Treat slots
// as transport fields rather than as semantic names: providers may return
// rate windows in either order.
function effectiveWindowMinutes(w, providerId, slot) {
    if (!w) return 0
    var minutes = Number(w.windowMinutes)
    if (isFinite(minutes) && minutes > 0) return minutes

    var description = String(w.resetDescription || "").toLowerCase()
    if (/per\s*5\s*hours?|5\s*h(?:ours?)?/.test(description)) return 300
    if (providerId === "kimi" && slot === "primary") return 10080
    return 0
}

function windowFor(usage, providerId, wantedMinutes) {
    if (!usage) return null
    if (providerId === "antigravity")
        return antigravityWindowFor(usage, wantedMinutes)
    var slots = ["primary", "secondary", "tertiary"]
    for (var i = 0; i < slots.length; i++) {
        var w = usableWindow(usage[slots[i]])
        if (w && effectiveWindowMinutes(w, providerId, slots[i]) === wantedMinutes)
            return w
    }
    // Preserve the legacy slot contract for other providers whose API payloads
    // do not include a window duration. Kimi is the only known inverted pair.
    if (providerId !== "kimi") {
        if (wantedMinutes === 300) return usableWindow(usage.primary)
        if (wantedMinutes === 10080) return usableWindow(usage.secondary)
    }
    return null
}

// Antigravity reports its quota per model family. The quota summary arrives
// as named extra windows (Gemini / Claude-GPT, 5-hour / weekly), while
// primary and secondary only repeat the most constrained bucket of each
// family, so neither slot means "session" or "weekly". Like CodexBarCore's
// Antigravity presentation, pick the most constrained known bucket with the
// wanted cadence. Local reports without a summary carry no cadence at all.
var ANTIGRAVITY_SUMMARY_PREFIX = "antigravity-quota-summary-"

function antigravitySummaryWindows(usage) {
    var extras = usage && usage.extraRateWindows ? usage.extraRateWindows : []
    return extras.filter(function (ew) {
        return ew && typeof ew.id === "string"
            && ew.id.indexOf(ANTIGRAVITY_SUMMARY_PREFIX) === 0
    })
}

function antigravityWindowFor(usage, wantedMinutes) {
    var summary = antigravitySummaryWindows(usage)
    var candidates = summary.length > 0
        ? summary.map(namedWindow)
        : [usage.primary, usage.secondary, usage.tertiary].map(usableWindow)
    var best = null
    for (var i = 0; i < candidates.length; i++) {
        var w = candidates[i]
        if (!windowUsageKnown(w) || Number(w.windowMinutes) !== wantedMinutes)
            continue
        if (best === null || Number(w.usedPercent) > Number(best.usedPercent))
            best = w
    }
    return best
}

function windowUsageKnown(w) {
    return w && w.usageKnown !== false && w.usedPercent !== undefined
}

// Time until the reset of the window behind a panel percentage ("3h 50m"),
// or "" when it has no reset time in the future.
function panelCountdown(pick, nowMs) {
    if (!pick || !pick.window || !pick.window.resetsAt)
        return ""
    var t = Date.parse(pick.window.resetsAt)
    if (isNaN(t) || t - nowMs < 1000)
        return ""
    return duration(Math.floor((t - nowMs) / 1000))
}

function remainingPick(w) {
    return windowUsageKnown(w) ? { window: w, remaining: 100 - normalizedPercent(w.usedPercent) } : null
}

// The window behind a panel percentage and its remaining percent, or null.
// source is "session" or "weekly" (each falls back to the other) or "lowest",
// which also weighs usable extra windows such as model-scoped weekly limits,
// since any of them can run out first.
function panelWindow(usage, providerId, source) {
    if (!usage)
        return null
    var session = remainingPick(windowFor(usage, providerId, 300))
    var weekly = remainingPick(windowFor(usage, providerId, 10080))
    if (source === "weekly")
        return weekly || session
    if (source !== "lowest")
        return session || weekly
    var picks = [session, weekly]
    var extras = usage.extraRateWindows || []
    for (var i = 0; i < extras.length; i++)
        picks.push(remainingPick(namedWindow(extras[i])))
    var lowest = null
    for (var j = 0; j < picks.length; j++) {
        if (picks[j] && (lowest === null || picks[j].remaining < lowest.remaining))
            lowest = picks[j]
    }
    return lowest
}

function normalizedPercent(value) {
    var n = Number(value)
    if (!isFinite(n)) return 0
    return Math.max(0, Math.min(100, Math.round(n)))
}

function windowUsedText(w) {
    return windowUsageKnown(w) ? String(normalizedPercent(w.usedPercent)) : "–"
}

function windowRemainingText(w) {
    return windowUsageKnown(w) ? String(100 - normalizedPercent(w.usedPercent)) : "–"
}

function windowBarPercent(w) {
    return windowUsageKnown(w) ? normalizedPercent(w.usedPercent) : 0
}

// Bar fill under CodexBar's "Usage bars fill" preference (usageBarsShowUsed):
// remaining quota by default, used quota when showUsed is set.
function windowBarFill(w, showUsed) {
    if (!windowUsageKnown(w))
        return 0
    var used = normalizedPercent(w.usedPercent)
    return showUsed ? used : 100 - used
}

// Menu pace line, matching CodexBarCore UsagePace / UsagePaceText. Kimi does
// not return the CLI's pre-computed `pace` payload, so reproduce that logic
// from the weekly window without rounding the values used in the projection.
function paceLine(pace, win, windowMinutes, nowMs, providerId) {
    if (pace && pace.summary) {
        var parts = pace.summary.split("|").map(function (p) { return p.trim() })
        var keep = parts.filter(function (p) { return p.indexOf("Expected") !== 0 })
        if (keep.length > 0) return "Pace: " + keep.join(" · ")
    }
    if (windowMinutes !== 10080 || !windowUsageKnown(win) || !win.resetsAt)
        return ""

    var resetMs = Date.parse(win.resetsAt)
    var durationMs = windowMinutes * 60 * 1000
    var timeUntilReset = resetMs - nowMs
    if (isNaN(resetMs) || timeUntilReset <= 0 || timeUntilReset > durationMs)
        return ""

    var elapsed = Math.max(0, Math.min(durationMs, durationMs - timeUntilReset))
    var actual = Math.max(0, Math.min(100, Number(win.usedPercent)))
    if (elapsed === 0 && actual > 0)
        return ""
    var expected = (elapsed / durationMs) * 100
    // CodexBarCore hides pace until enough of the weekly window has elapsed.
    if (expected < 3 && actual < 100)
        return ""
    var delta = actual - expected
    var deltaDisplay = Math.round(Math.abs(delta))
    var left = (Math.abs(delta) <= 2 || deltaDisplay === 0)
        ? "On pace"
        : deltaDisplay + "% " + (delta > 0 ? "in deficit" : "in reserve")

    var right = ""
    if (actual >= 100) {
        right = "Runs out now"
    } else if (elapsed > 0 && actual > 0) {
        var etaMs = (100 - actual) / (actual / elapsed)
        right = etaMs >= timeUntilReset ? "Lasts until reset"
                                         : "Runs out in " + duration(Math.ceil(etaMs / 1000))
    } else if (elapsed > 0 && actual === 0) {
        right = "Lasts until reset"
    }
    return "Pace: " + left + (right !== "" ? " · " + right : "")
}

// Section title for a rate window ("Session", "Weekly", "Monthly", or a custom title)
function windowTitle(windowMinutes, fallback) {
    if (windowMinutes === 300) return "Session"
    if (windowMinutes === 10080) return "Weekly"
    if (windowMinutes >= 40000 && windowMinutes <= 46000) return "Monthly"
    return fallback
}

// Rate-window slots the provider card lists. With an Antigravity quota
// summary every bucket already arrives as a titled extra window, so the
// repeated family slots are skipped and each quota is listed once.
function cardSlots(usage, providerId) {
    if (providerId === "antigravity" && antigravitySummaryWindows(usage).length > 0)
        return []
    return ["primary", "secondary", "tertiary"]
}

// Card title for a slot window. Antigravity's slots are model families
// (CodexBarCore's session/weekly labels for it), not time windows.
function slotTitle(providerId, slot, windowMinutes) {
    if (providerId === "antigravity") {
        if (slot === "primary") return "Gemini Models"
        if (slot === "secondary") return "Claude and GPT"
    }
    var fallback = slot === "primary" ? "Session"
                 : slot === "secondary" ? "Weekly" : "Monthly"
    return windowTitle(windowMinutes, fallback)
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
