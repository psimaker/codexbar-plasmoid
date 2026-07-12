import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Hoverable menu row like the bottom entries of the CodexBar menu.
Rectangle {
    id: rowRoot

    property string iconName: ""
    property string label: ""
    property string detail: ""
    property bool interactive: true

    signal activated()

    Layout.fillWidth: true
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 1.55)
    radius: Kirigami.Units.cornerRadius
    color: mouse.containsMouse && interactive
           ? Qt.alpha(Kirigami.Theme.textColor, 0.08)
           : "transparent"
    opacity: interactive ? 1.0 : 0.45

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing * 2

        Kirigami.Icon {
            visible: rowRoot.iconName !== ""
            source: rowRoot.iconName
            color: Kirigami.Theme.textColor
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
        }

        PlasmaComponents3.Label {
            text: rowRoot.label
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        PlasmaComponents3.Label {
            visible: rowRoot.detail !== ""
            text: rowRoot.detail
            opacity: 0.6
            font: Kirigami.Theme.smallFont
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: rowRoot.interactive
        onClicked: rowRoot.activated()
    }
}
