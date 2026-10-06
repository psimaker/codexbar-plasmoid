import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "code/catalog.js" as Catalog

// The per-provider card: header, rate-window sections with progress bars,
// credits, cost and status — mirrors CodexBar's menu card.
ColumnLayout {
    id: card

    required property var plasmoidRoot
    required property string providerId
    property bool extrasOnly: false

    readonly property var meta: Catalog.meta(providerId)
    // shallow-copy so the property change signal fires on every data revision
    readonly property var d: {
        plasmoidRoot.rev
        var x = plasmoidRoot.usageData[providerId]
        return x ? Object.assign({}, x) : null
    }
    readonly property var entry: d && d.entry ? d.entry : null
    readonly property var usage: entry && entry.usage ? entry.usage : null
    readonly property color brandColor: meta.color

    spacing: Kirigami.Units.smallSpacing

    function sections() {
        plasmoidRoot.rev
        var out = []
        if (!usage)
            return out
        var slots = Catalog.cardSlots(usage, providerId)
        for (var i = 0; i < slots.length; i++) {
            var slot = slots[i]
            var w = Catalog.usableWindow(usage[slot])
            if (!w)
                continue
            var minutes = Catalog.effectiveWindowMinutes(w, providerId, slot)
            out.push({
                title: Catalog.slotTitle(providerId, slot, minutes),
                win: w,
                minutes: minutes,
                pace: minutes === 10080 && entry.pace && entry.pace.secondary
                      ? entry.pace.secondary : null
            })
        }
        // Kimi's transport slots are inverted. Keep legacy ordering for every
        // other provider, especially those without window duration metadata.
        if (providerId === "kimi") {
            out.sort(function (a, b) {
                var am = a.minutes > 0 ? a.minutes : Number.MAX_VALUE
                var bm = b.minutes > 0 ? b.minutes : Number.MAX_VALUE
                return am - bm
            })
        }
        if (usage.extraRateWindows) {
            for (var i = 0; i < usage.extraRateWindows.length; i++) {
                var ew = usage.extraRateWindows[i]
                var w = Catalog.namedWindow(ew)
                if (w)
                    out.push({
                        title: ew.title || "Extra",
                        win: w,
                        minutes: Catalog.effectiveWindowMinutes(w, providerId, "extra"),
                        pace: null
                    })
            }
        }
        return out
    }

    // earliest available reset credit that has not expired yet
    function nextResetCredit() {
        var now = plasmoidRoot.nowMs
        if (!usage || !usage.codexResetCredits || !usage.codexResetCredits.credits)
            return null
        var best = null
        var credits = usage.codexResetCredits.credits
        for (var i = 0; i < credits.length; i++) {
            var c = credits[i]
            if (c.status === "available" && c.expires_at) {
                var t = Date.parse(c.expires_at)
                if (!isNaN(t) && t > now && (best === null || t < best))
                    best = t
            }
        }
        return best
    }

    // CodexBarCore CreditsSnapshot.displayRemaining: a workspace balance or a
    // read balance counts; an unread placeholder (balanceReadSucceeded=false)
    // must not surface as a real zero. Returns null when nothing is showable.
    function creditsRemaining() {
        var c = entry ? entry.credits : null
        if (!c || typeof c !== "object")
            return null
        if (c.balanceReadSucceeded === true && c.balanceIsWorkspace === true)
            return c.remaining
        if (c.codexCreditLimit && typeof c.codexCreditLimit.remaining === "number")
            return c.codexCreditLimit.remaining
        if (c.balanceReadSucceeded === false)
            return null
        return typeof c.remaining === "number" ? c.remaining : null
    }

    // Generic `usage.details` sections (CodexBar >= 0.48): provider-specific
    // rows the CLI already rendered as label/value text, optional progress.
    function detailSections() {
        plasmoidRoot.rev
        var out = []
        if (!usage || !usage.details || !usage.details.length)
            return out
        for (var i = 0; i < usage.details.length; i++) {
            var section = usage.details[i]
            if (!section || !section.rows || !section.rows.length)
                continue
            var rows = []
            for (var r = 0; r < section.rows.length; r++) {
                var row = section.rows[r]
                if (!row || typeof row.label !== "string")
                    continue
                var value = typeof row.value === "string" ? row.value : ""
                if (typeof row.secondaryValue === "string" && row.secondaryValue !== "")
                    value = value !== "" ? value + " · " + row.secondaryValue : row.secondaryValue
                var percent = -1
                if (row.progress && typeof row.progress.used === "number"
                        && typeof row.progress.total === "number" && row.progress.total > 0)
                    percent = Catalog.normalizedPercent(row.progress.used / row.progress.total * 100)
                rows.push({ label: row.label, value: value, percent: percent })
            }
            if (rows.length > 0)
                out.push({ title: typeof section.title === "string" ? section.title : "", rows: rows })
        }
        return out
    }

    // Providers without a session window report a cost/quota budget instead
    // (CLIRenderer.appendPrimaryLines fallback).
    function providerCostLine() {
        plasmoidRoot.rev
        if (!usage || !usage.providerCost || Catalog.usableWindow(usage.primary))
            return ""
        var cost = usage.providerCost
        if (typeof cost.used !== "number" || typeof cost.limit !== "number" || cost.limit <= 0
                || !Catalog.showsCostFallback(providerId, cost))
            return ""
        var label = cost.currencyCode === "Quota" ? i18n("Quota") : i18n("Cost")
        var unit = cost.currencyCode && cost.currencyCode !== "Quota" ? " " + cost.currencyCode : ""
        var text = label + ": " + cost.used.toFixed(1) + " / " + cost.limit.toFixed(1) + unit
        if (typeof cost.period === "string" && cost.period !== "")
            text += " · " + cost.period
        return text
    }

    function todayCost() {
        plasmoidRoot.rev
        if (!d || !d.cost || !d.cost.daily)
            return null
        // follows the clock so the day rolls over at midnight
        var now = new Date(plasmoidRoot.nowMs)
        var key = now.getFullYear() + "-"
                + ("0" + (now.getMonth() + 1)).slice(-2) + "-"
                + ("0" + now.getDate()).slice(-2)
        for (var i = d.cost.daily.length - 1; i >= 0; i--) {
            if (d.cost.daily[i].date === key)
                return d.cost.daily[i]
        }
        return { totalCost: 0, totalTokens: 0 }
    }

    // ---- header ----
    RowLayout {
        visible: !card.extrasOnly
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        TruncatedLabel {
            text: card.meta.name
            font.weight: Font.Bold
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        PlasmaComponents3.Label {
            visible: text !== ""
            text: Catalog.planText(card.entry)
            opacity: 0.6
            font: Kirigami.Theme.smallFont
        }
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        visible: !card.extrasOnly && text !== ""
        text: {
            plasmoidRoot.rev
            if (card.d && card.d.loading)
                return i18n("Refreshing…")
            if (plasmoidRoot.cliSetupRequired)
                return ""
            if (card.d && card.d.error && card.d.error.length > 0)
                return card.d.error
            if (card.usage && card.usage.updatedAt)
                return Catalog.updatedText(card.usage.updatedAt, plasmoidRoot.nowMs)
            return ""
        }
        color: card.d && card.d.error && card.d.error.length > 0 && !(card.d && card.d.loading)
               ? Kirigami.Theme.negativeTextColor
               : Kirigami.Theme.textColor
        opacity: card.d && card.d.error && card.d.error.length > 0 ? 0.9 : 0.6
        font: Kirigami.Theme.smallFont
        wrapMode: Text.WordWrap
    }

    Item {
        visible: !card.extrasOnly
        Layout.preferredHeight: Kirigami.Units.smallSpacing
    }

    // ---- rate window sections ----
    Repeater {
        model: card.extrasOnly ? [] : card.sections()

        ColumnLayout {
            id: section
            required property var modelData
            Layout.fillWidth: true
            spacing: Math.round(Kirigami.Units.smallSpacing * 0.8)

            PlasmaComponents3.Label {
                text: section.modelData.title
                font.weight: Font.DemiBold
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.05
            }

            UsageBar {
                Layout.fillWidth: true
                percent: Catalog.windowBarFill(section.modelData.win, Plasmoid.configuration.usageBarsShowUsed)
                fillColor: card.brandColor
            }

            RowLayout {
                Layout.fillWidth: true

                PlasmaComponents3.Label {
                    text: Plasmoid.configuration.usageBarsShowUsed
                          ? Catalog.windowUsedText(section.modelData.win) + i18n("% used")
                          : Catalog.windowRemainingText(section.modelData.win) + i18n("% left")
                    opacity: 0.75
                    font: Kirigami.Theme.smallFont
                }

                Item { Layout.fillWidth: true }

                PlasmaComponents3.Label {
                    text: Catalog.resetText(section.modelData.win, plasmoidRoot.nowMs)
                    opacity: 0.6
                    font: Kirigami.Theme.smallFont
                }
            }

            TruncatedLabel {
                visible: text !== ""
                text: Catalog.paceLine(section.modelData.pace, section.modelData.win,
                                       section.modelData.minutes, plasmoidRoot.nowMs, providerId)
                opacity: 0.55
                font: Kirigami.Theme.smallFont
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
        }
    }

    TruncatedLabel {
        Layout.fillWidth: true
        visible: !card.extrasOnly && text !== ""
        text: card.providerCostLine()
        opacity: 0.75
        font: Kirigami.Theme.smallFont
        elide: Text.ElideRight
    }

    // Prepaid balances in usage.providerCost (CLIRenderer's cost lines)
    Repeater {
        model: {
            plasmoidRoot.rev
            return card.extrasOnly || !card.usage ? []
                : Catalog.costBalances(card.providerId, card.usage.providerCost)
        }

        TruncatedLabel {
            required property var modelData
            Layout.fillWidth: true
            text: i18n("%1: %2", modelData.label,
                       Catalog.amountText(modelData.amount, modelData.currencyCode))
            opacity: 0.75
            font: Kirigami.Theme.smallFont
            elide: Text.ElideRight
        }
    }

    // ---- provider detail sections (usage.details) ----
    Repeater {
        model: card.extrasOnly ? [] : card.detailSections()

        ColumnLayout {
            id: detailSection
            required property var modelData
            Layout.fillWidth: true
            spacing: Math.round(Kirigami.Units.smallSpacing * 0.8)

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
            }

            PlasmaComponents3.Label {
                visible: text !== ""
                text: detailSection.modelData.title
                font.weight: Font.DemiBold
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.05
            }

            Repeater {
                model: detailSection.modelData.rows

                ColumnLayout {
                    id: detailRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Math.round(Kirigami.Units.smallSpacing / 2)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        TruncatedLabel {
                            text: detailRow.modelData.label
                            opacity: 0.75
                            font: Kirigami.Theme.smallFont
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        TruncatedLabel {
                            text: detailRow.modelData.value
                            font: Kirigami.Theme.smallFont
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                            Layout.maximumWidth: Math.round(card.width * 0.6)
                        }
                    }

                    UsageBar {
                        visible: detailRow.modelData.percent >= 0
                        Layout.fillWidth: true
                        percent: Math.max(0, detailRow.modelData.percent)
                        fillColor: card.brandColor
                    }
                }
            }

            Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
        }
    }

    // ---- credits (Codex) ----
    ColumnLayout {
        Layout.fillWidth: true
        visible: !card.extrasOnly
                 && (card.creditsRemaining() !== null
                     || !!(card.usage && card.usage.codexResetCredits
                           && card.usage.codexResetCredits.availableCount > 0))
        spacing: Math.round(Kirigami.Units.smallSpacing * 0.8)

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
        }

        PlasmaComponents3.Label {
            text: i18n("Credits")
            font.weight: Font.DemiBold
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.05
        }

        PlasmaComponents3.Label {
            visible: card.creditsRemaining() !== null
            text: card.creditsRemaining() !== null
                  ? i18n("Credits: %1 left", card.creditsRemaining()) : ""
            opacity: 0.75
            font: Kirigami.Theme.smallFont
        }

        PlasmaComponents3.Label {
            visible: !!(card.usage && card.usage.codexResetCredits
                        && card.usage.codexResetCredits.availableCount > 0)
            text: card.usage && card.usage.codexResetCredits
                  ? i18n("Limit Reset Credits: %1 available", card.usage.codexResetCredits.availableCount)
                  : ""
            opacity: 0.75
            font: Kirigami.Theme.smallFont
        }

        PlasmaComponents3.Label {
            visible: card.nextResetCredit() !== null
            text: {
                var t = card.nextResetCredit()
                if (t === null)
                    return ""
                var s = Math.floor((t - plasmoidRoot.nowMs) / 1000)
                return s > 0
                    ? i18n("Next reset credit expires in %1", Catalog.duration(s))
                    : i18n("Next reset credit expired")
            }
            opacity: 0.55
            font: Kirigami.Theme.smallFont
        }

        Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
    }

    // ---- cost (local logs) ----
    ColumnLayout {
        Layout.fillWidth: true
        visible: Plasmoid.configuration.showCost
                 && !!(card.d && card.d.cost !== undefined && card.d.cost !== null)
        spacing: Math.round(Kirigami.Units.smallSpacing * 0.8)

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
        }

        PlasmaComponents3.Label {
            text: i18n("Cost")
            font.weight: Font.DemiBold
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.05
        }

        PlasmaComponents3.Label {
            visible: card.todayCost() !== null
            text: {
                var t = card.todayCost()
                if (t === null)
                    return ""
                return i18n("Today: %1 · %2 tokens",
                            Catalog.money(t.totalCost), Catalog.compactTokens(t.totalTokens))
            }
            opacity: 0.75
            font: Kirigami.Theme.smallFont
        }

        PlasmaComponents3.Label {
            visible: !!(card.d && card.d.cost && card.d.cost.last30DaysCostUSD !== undefined)
            text: card.d && card.d.cost
                  ? i18n("Last 30 days: %1 · %2 tokens",
                         Catalog.money(card.d.cost.last30DaysCostUSD),
                         Catalog.compactTokens(card.d.cost.last30DaysTokens))
                  : ""
            opacity: 0.75
            font: Kirigami.Theme.smallFont
        }

        Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
    }

    // ---- status + account ----
    RowLayout {
        Layout.fillWidth: true
        visible: Plasmoid.configuration.showStatus
                 && card.entry && card.entry.status !== undefined && card.entry.status !== null
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            width: 8
            height: 8
            radius: 4
            color: card.entry && card.entry.status
                   ? Catalog.statusColor(card.entry.status.indicator) : "transparent"
        }

        TruncatedLabel {
            text: card.entry && card.entry.status && card.entry.status.description
                  ? card.entry.status.description : ""
            opacity: 0.6
            font: Kirigami.Theme.smallFont
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }

    TruncatedLabel {
        visible: !card.extrasOnly && !!(card.usage && card.usage.identity
                                        && card.usage.identity.accountEmail !== undefined)
        text: card.usage && card.usage.identity && card.usage.identity.accountEmail
              ? i18n("Account: %1", card.usage.identity.accountEmail) : ""
        opacity: 0.55
        font: Kirigami.Theme.smallFont
        Layout.fillWidth: true
        elide: Text.ElideRight
    }
}
