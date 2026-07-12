import QtQuick
import QtQuick.Effects

// The original provider SVGs are white — tint them like the macOS app
// tints its template icons.
Item {
    id: iconRoot

    property string iconFile: ""
    property color tint: "white"

    Image {
        id: img
        anchors.fill: parent
        source: iconRoot.iconFile !== "" ? Qt.resolvedUrl("../icons/" + iconRoot.iconFile) : ""
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectFit
        visible: false
    }

    MultiEffect {
        anchors.fill: img
        source: img
        colorization: 1.0
        colorizationColor: iconRoot.tint
    }
}
