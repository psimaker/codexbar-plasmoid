import QtQuick
import org.kde.kirigami as Kirigami

// Thin rounded progress bar; fill uses the provider branding color,
// track matches the original's tertiary label @ 22% alpha.
Rectangle {
    id: track

    property real percent: 0          // 0..100 (fill amount)
    property color fillColor: Kirigami.Theme.highlightColor

    implicitHeight: 5
    radius: height / 2
    color: Qt.alpha(Kirigami.Theme.textColor, 0.14)

    Rectangle {
        visible: track.percent > 0
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        radius: parent.radius
        color: track.fillColor
        width: Math.max(parent.height * 1.4,
                        parent.width * Math.min(100, Math.max(0, track.percent)) / 100)
    }
}
