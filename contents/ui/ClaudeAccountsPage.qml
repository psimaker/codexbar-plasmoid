import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Optional stacked Claude account view. Until an adapter list has been
// validated, retain the ordinary Claude provider card as a safe fallback.
ColumnLayout {
    id: page

    required property var plasmoidRoot

    readonly property var d: {
        plasmoidRoot.rev
        return Object.assign({}, plasmoidRoot.claudeAccountData)
    }
    readonly property var accounts: d.accounts || []
    readonly property bool showAccounts: d.valid && accounts.length > 0

    spacing: Kirigami.Units.smallSpacing

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        visible: page.d.loading
        text: page.showAccounts ? i18n("Refreshing Claude accounts…")
                                : i18n("Loading Claude accounts…")
        opacity: 0.6
        font: Kirigami.Theme.smallFont
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        visible: page.d.error && page.d.error.length > 0
        text: page.showAccounts
            ? i18n("Showing the last successful account update: %1", page.d.error)
            : page.d.error
        color: Kirigami.Theme.negativeTextColor
        opacity: 0.9
        font: Kirigami.Theme.smallFont
        wrapMode: Text.WordWrap
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        visible: page.d.switchError && page.d.switchError.length > 0
        text: i18n("Account switch failed: %1", page.d.switchError)
        color: Kirigami.Theme.negativeTextColor
        opacity: 0.9
        font: Kirigami.Theme.smallFont
        wrapMode: Text.WordWrap
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        visible: page.d.valid && page.accounts.length === 0
        text: i18n("The Claude account adapter reported no configured accounts. Showing normal Claude usage.")
        opacity: 0.65
        font: Kirigami.Theme.smallFont
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: page.showAccounts ? page.accounts : []

        ColumnLayout {
            id: accountRow
            required property var modelData
            required property int index
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                Layout.fillWidth: true
                visible: accountRow.index > 0
                implicitHeight: 1
                color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
            }

            ClaudeAccountCard {
                Layout.fillWidth: true
                plasmoidRoot: page.plasmoidRoot
                account: accountRow.modelData
            }
        }
    }

    ProviderCard {
        visible: page.showAccounts
        Layout.fillWidth: true
        plasmoidRoot: page.plasmoidRoot
        providerId: "claude"
        extrasOnly: true
    }

    ProviderCard {
        visible: !page.showAccounts
        Layout.fillWidth: true
        plasmoidRoot: page.plasmoidRoot
        providerId: "claude"
    }
}
