import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Panel representation. Default: ONE merged critter icon showing the
// worst-case (lowest remaining) usage across all enabled providers.
// Optional: one icon per provider, like the separate macOS menu bar items.
// Icons flow along the panel axis (horizontal or vertical).
MouseArea {
    id: compactRoot

    required property var plasmoidRoot

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool separate: Plasmoid.configuration.separateIcons
    readonly property var iconModel: separate && plasmoidRoot.enabledProviders.length > 0
                                     ? plasmoidRoot.enabledProviders
                                     : ["__merged__"]

    readonly property real iconSide: vertical
        ? Math.min(Math.round(width * 0.75), Kirigami.Units.iconSizes.medium)
        : Math.min(Math.round(height * 0.75), Kirigami.Units.iconSizes.medium)

    implicitWidth: grid.implicitWidth + (vertical ? 0 : Kirigami.Units.smallSpacing * 2)
    implicitHeight: grid.implicitHeight + (vertical ? Kirigami.Units.smallSpacing * 2 : 0)

    Layout.minimumWidth: vertical ? 0 : implicitWidth
    Layout.preferredWidth: vertical ? -1 : implicitWidth
    Layout.fillWidth: vertical
    Layout.minimumHeight: vertical ? implicitHeight : 0
    Layout.preferredHeight: vertical ? implicitHeight : -1
    Layout.fillHeight: !vertical

    hoverEnabled: true

    function remainingFor(pid, source) {
        if (pid !== "__merged__")
            return plasmoidRoot.remainingPercent(pid, source)
        var min = -1
        for (var i = 0; i < plasmoidRoot.enabledProviders.length; i++) {
            var v = plasmoidRoot.remainingPercent(plasmoidRoot.enabledProviders[i], source)
            if (v >= 0 && (min < 0 || v < min))
                min = v
        }
        return min
    }

    function staleFor(pid) {
        if (pid !== "__merged__")
            return plasmoidRoot.isStale(pid)
        for (var i = 0; i < plasmoidRoot.enabledProviders.length; i++) {
            if (!plasmoidRoot.isStale(plasmoidRoot.enabledProviders[i]))
                return false
        }
        return true
    }

    onClicked: function (mouse) {
        // in per-provider mode, clicking a specific icon opens its tab
        if (separate && plasmoidRoot.enabledProviders.length > 1) {
            var item = vertical
                ? grid.childAt(grid.width / 2, mouse.y - grid.y)
                : grid.childAt(mouse.x - grid.x, grid.height / 2)
            if (item && item.providerId !== undefined && item.providerId !== "__merged__")
                plasmoidRoot.currentTab = item.providerId
        }
        plasmoidRoot.expanded = !plasmoidRoot.expanded
    }

    GridLayout {
        id: grid
        anchors.centerIn: parent
        flow: compactRoot.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: compactRoot.vertical ? -1 : 1
        columns: compactRoot.vertical ? 1 : -1
        rowSpacing: Kirigami.Units.smallSpacing * 2
        columnSpacing: Kirigami.Units.smallSpacing * 2

        Repeater {
            model: compactRoot.iconModel

            RowLayout {
                id: providerItem
                required property string modelData
                readonly property string providerId: modelData
                spacing: Math.round(Kirigami.Units.smallSpacing / 2)

                CritterIcon {
                    // merged icon: plain meter bars like the original CodexBar status item
                    providerId: providerItem.providerId === "__merged__" ? "" : providerItem.providerId
                    Layout.preferredWidth: compactRoot.iconSide
                    Layout.preferredHeight: compactRoot.iconSide
                    Layout.alignment: Qt.AlignVCenter
                    remainingPrimary: compactRoot.remainingFor(providerItem.providerId, "session")
                    remainingSecondary: compactRoot.remainingFor(providerItem.providerId, "weekly")
                    stale: compactRoot.staleFor(providerItem.providerId)
                    hideCritters: Plasmoid.configuration.hideCritters
                }

                PlasmaComponents3.Label {
                    visible: Plasmoid.configuration.showPercentInPanel
                    Layout.alignment: Qt.AlignVCenter
                    font.pixelSize: Math.max(9, Math.round(compactRoot.iconSide * 0.62))
                    text: {
                        var v = compactRoot.remainingFor(
                                    providerItem.providerId, Plasmoid.configuration.panelPercentSource)
                        if (v < 0)
                            return "–"
                        if (Plasmoid.configuration.percentStyle === "used")
                            v = 100 - v
                        return Math.round(v) + "%"
                    }
                }
            }
        }
    }
}
