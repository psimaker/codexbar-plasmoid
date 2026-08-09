import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "code/catalog.js" as Catalog
import "code/claudeAccounts.js" as ClaudeAccounts

// One display-only Claude account projected from the schema-v1 adapter.
// Credential/profile identifiers never enter this component.
ColumnLayout {
    id: card

    required property var plasmoidRoot
    required property var account

    readonly property color brandColor: Catalog.meta("claude").color
    readonly property string accountError: ClaudeAccounts.statusError(account)
    readonly property bool switching: plasmoidRoot.claudeSwitchInFlight
                                      && plasmoidRoot.claudeSwitchingSlot === account.number
    // The adapter serves last-known windows once a live fetch fails. They are
    // display-only, so they are drawn but never presented as current.
    readonly property bool lastKnownUsage: !!account && account.usageIsLastGood === true
    readonly property bool hasUsage: !!account
                                     && (account.usageStatus === "ok" || lastKnownUsage)

    spacing: Kirigami.Units.smallSpacing

    // Catalog.money renders the widget's usual "$ 1.20". An adapter reporting
    // any other currency gets its code appended rather than a wrong symbol.
    function moneyText(value, currency) {
        if (typeof value !== "number" || !isFinite(value))
            return ""
        return (currency === "" || currency === "USD")
            ? Catalog.money(value) : value.toFixed(2) + " " + currency
    }

    function sections() {
        plasmoidRoot.rev
        var out = []
        if (!hasUsage)
            return out
        if (account.fiveHour)
            out.push({ title: "Session", win: account.fiveHour, minutes: 300 })
        if (account.sevenDay)
            out.push({ title: "Weekly", win: account.sevenDay, minutes: 10080 })
        if (account.scoped) {
            for (var i = 0; i < account.scoped.length; i++) {
                var scoped = account.scoped[i]
                out.push({ title: scoped.name, win: scoped, minutes: 10080 })
            }
        }
        return out
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.Label {
            text: i18n("Claude")
            font.weight: Font.Bold
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25
        }

        Item { Layout.fillWidth: true }

        PlasmaComponents3.Label {
            text: card.account ? card.account.displayLabel : ""
            opacity: 0.65
            font: Kirigami.Theme.smallFont
            Layout.maximumWidth: parent.width * 0.62
            elide: Text.ElideRight
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.Label {
            text: {
                card.plasmoidRoot.rev
                var measuredAt = (card.account && typeof card.account.usageMeasuredAt === "number")
                    ? card.account.usageMeasuredAt
                    : card.plasmoidRoot.claudeAccountData.fetchedAt
                if (!measuredAt)
                    return ""
                var updated = Catalog.updatedText(new Date(measuredAt).toISOString(),
                                                  card.plasmoidRoot.nowMs)
                if (card.lastKnownUsage)
                    return updated + i18n(" · last known")
                return card.plasmoidRoot.isClaudeAccountStale(card.account)
                    ? updated + i18n(" · stale") : updated
            }
            opacity: 0.6
            font: Kirigami.Theme.smallFont
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        // Held out of the adapter's automatic rotation. Naming the effect
        // rather than the `disabled` flag keeps this from reading as a broken
        // or unusable account — the slot still works and stays switchable.
        PlasmaComponents3.Label {
            visible: card.account && card.account.disabled === true
            text: i18n("Not in rotation")
            color: Kirigami.Theme.neutralTextColor
            font: Kirigami.Theme.smallFont
        }

        PlasmaComponents3.Label {
            visible: card.account && card.account.active
            text: i18n("Active")
            color: Kirigami.Theme.positiveTextColor
            font: Kirigami.Theme.smallFont
        }

        QQC2.ToolButton {
            visible: card.account && !card.account.active
                     && ClaudeAccounts.canActivate(card.account)
            text: card.switching ? i18n("Switching…") : i18n("Switch account…")
            enabled: card.plasmoidRoot.canSwitchClaudeAccount(card.account)
            onClicked: card.plasmoidRoot.switchClaudeAccount(card.account.number)
        }
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        visible: card.accountError !== ""
        text: card.accountError
        color: card.account && card.account.usageStatus === "api_key"
               ? Kirigami.Theme.textColor : Kirigami.Theme.negativeTextColor
        opacity: 0.85
        font: Kirigami.Theme.smallFont
        wrapMode: Text.WordWrap
    }

    Item {
        visible: card.sections().length > 0
        Layout.preferredHeight: Kirigami.Units.smallSpacing
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        visible: card.lastKnownUsage && card.sections().length > 0
        text: i18n("Last known usage — not current")
        opacity: 0.7
        font: Kirigami.Theme.smallFont
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: card.sections()

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
                percent: Catalog.windowBarPercent(section.modelData.win)
                fillColor: card.brandColor
            }

            RowLayout {
                Layout.fillWidth: true

                PlasmaComponents3.Label {
                    text: Catalog.windowUsedText(section.modelData.win) + i18n("% used")
                    opacity: 0.75
                    font: Kirigami.Theme.smallFont
                }

                Item { Layout.fillWidth: true }

                PlasmaComponents3.Label {
                    text: Catalog.resetText(section.modelData.win, card.plasmoidRoot.nowMs)
                    opacity: 0.6
                    font: Kirigami.Theme.smallFont
                }
            }

            PlasmaComponents3.Label {
                visible: text !== ""
                // Prefer the adapter's own pace verdict; only fall back to the
                // local reconstruction when it reports none. Either way, pace
                // weighs used percent against elapsed window time, so a
                // last-known measurement would be scored against the wrong
                // clock and read as behind pace.
                text: {
                    if (card.lastKnownUsage)
                        return ""
                    var reported = ClaudeAccounts.paceText(section.modelData.win)
                    return reported !== "" ? reported
                                           : Catalog.paceLine(null, section.modelData.win,
                                                              section.modelData.minutes,
                                                              card.plasmoidRoot.nowMs, "claude")
                }
                opacity: 0.55
                font: Kirigami.Theme.smallFont
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
        }
    }

    // Pay-as-you-go spend, which only the adapter can report per account: the
    // CodexBar CLI sees the cost of whichever account is currently active.
    ColumnLayout {
        id: spendSection
        readonly property var spend: card.hasUsage && card.account.spend ? card.account.spend : null
        visible: spend !== null
        Layout.fillWidth: true
        spacing: Math.round(Kirigami.Units.smallSpacing * 0.8)

        PlasmaComponents3.Label {
            text: i18n("Spend")
            font.weight: Font.DemiBold
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.05
        }

        UsageBar {
            Layout.fillWidth: true
            percent: Catalog.windowBarPercent(spendSection.spend)
            fillColor: card.brandColor
        }

        RowLayout {
            Layout.fillWidth: true

            PlasmaComponents3.Label {
                text: spendSection.spend
                      ? i18n("%1 of %2",
                             card.moneyText(spendSection.spend.used, spendSection.spend.currency),
                             card.moneyText(spendSection.spend.limit, spendSection.spend.currency))
                      : ""
                opacity: 0.75
                font: Kirigami.Theme.smallFont
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            PlasmaComponents3.Label {
                text: Catalog.resetText(spendSection.spend, card.plasmoidRoot.nowMs)
                opacity: 0.6
                font: Kirigami.Theme.smallFont
            }
        }

        Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
    }
}
