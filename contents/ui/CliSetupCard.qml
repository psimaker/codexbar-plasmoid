import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "code/cliStatus.js" as CliStatus

Rectangle {
    id: card

    required property var plasmoidRoot

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2
    radius: Kirigami.Units.cornerRadius
    color: Qt.alpha(Kirigami.Theme.neutralTextColor, 0.08)
    border.color: Qt.alpha(Kirigami.Theme.neutralTextColor, 0.35)
    border.width: 1

    readonly property string explanation: {
        var state = plasmoidRoot.cliState
        if (state.code === CliStatus.MISSING)
            return i18n("CLI not found. Install CodexBar CLI %1 or newer, or configure its executable path.", CliStatus.MINIMUM_VERSION)
        if (state.code === CliStatus.TIMEOUT)
            return i18n("CLI timed out. Check the configured executable and try again.")
        if (state.code === CliStatus.INCOMPATIBLE && state.detectedVersion !== "")
            return i18n("CLI needs to be updated. Version %1 is installed; version %2 or newer is required.", state.detectedVersion, CliStatus.MINIMUM_VERSION)
        if (state.code === CliStatus.INCOMPATIBLE)
            return i18n("CLI crashed or is incompatible. Install CodexBar CLI %1 or newer, then try again.", CliStatus.MINIMUM_VERSION)
        return i18n("CLI returned unexpected output. Check the installation and try again.")
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "dialog-warning-symbolic"
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: i18n("CodexBar CLI required")
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: card.explanation
            wrapMode: Text.WordWrap
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: i18n("To set a custom CLI path, right-click the widget and choose Configure CodexBar…")
            wrapMode: Text.WordWrap
            opacity: 0.75
            font: Kirigami.Theme.smallFont
        }

        PlasmaComponents3.Button {
            Layout.fillWidth: true
            text: i18n("Open installation guide")
            icon.name: "documentation-symbolic"
            Accessible.name: text
            onClicked: Qt.openUrlExternally("https://github.com/psimaker/codexbar-plasmoid#install-the-codexbar-cli")
        }

        PlasmaComponents3.Button {
            Layout.fillWidth: true
            text: i18n("Open CodexBar CLI documentation")
            icon.name: "internet-web-browser-symbolic"
            Accessible.name: text
            onClicked: Qt.openUrlExternally("https://github.com/steipete/CodexBar/blob/main/docs/cli.md")
        }

        PlasmaComponents3.Button {
            Layout.fillWidth: true
            text: i18n("Retry")
            icon.name: "view-refresh-symbolic"
            Accessible.name: text
            onClicked: card.plasmoidRoot.retryCli()
        }
    }
}
