import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: about

    required property var plasmoidRoot

    signal backRequested()

    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing * 2

        CritterIcon {
            providerId: "codex"
            remainingPrimary: 80
            remainingSecondary: 60
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Kirigami.Units.iconSizes.large
        }

        ColumnLayout {
            spacing: 0

            PlasmaComponents3.Label {
                text: "CodexBar"
                font.weight: Font.Bold
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
            }

            PlasmaComponents3.Label {
                text: i18n("Plasma port, v0.1.0 — data via codexbar CLI")
                opacity: 0.6
                font: Kirigami.Theme.smallFont
            }
        }
    }

    Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        text: i18n("Keeps AI coding-provider limits visible in your panel. A KDE Plasma re-creation of Peter Steinberger's CodexBar for macOS, driven by the official CodexBar CLI.")
        wrapMode: Text.WordWrap
        opacity: 0.75
        font: Kirigami.Theme.smallFont
    }

    Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }

    MenuRow {
        iconName: "internet-services-symbolic"
        label: i18n("CodexBar on GitHub")
        onActivated: Qt.openUrlExternally("https://github.com/steipete/CodexBar")
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
    }

    MenuRow {
        iconName: "go-previous-symbolic"
        label: i18n("Back")
        onActivated: about.backRequested()
    }
}
