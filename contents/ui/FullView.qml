import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "code/catalog.js" as Catalog

// The popup: provider switcher tabs on top, the selected card below,
// then the action rows and the footer menu — like CodexBar's menu.
// Content scrolls when it exceeds the height cap.
Item {
    id: fullRoot

    required property var plasmoidRoot

    readonly property var tabs: {
        var t = []
        if (plasmoidRoot.enabledProviders.length > 1)
            t.push("overview")
        return t.concat(plasmoidRoot.enabledProviders)
    }
    readonly property string currentTab: plasmoidRoot.currentTab
    readonly property bool onProviderTab: Catalog.PROVIDERS[currentTab] !== undefined

    // cap the popup height to the usable screen area (fallback: 42 grid units)
    readonly property real popupMaxHeight: {
        var cap = Kirigami.Units.gridUnit * 42
        var rect = Plasmoid.availableScreenRect
        if (rect && rect.height > 0)
            cap = Math.min(cap, rect.height - Kirigami.Units.gridUnit * 3)
        return Math.max(cap, Kirigami.Units.gridUnit * 12)
    }

    implicitWidth: Kirigami.Units.gridUnit * 19
    implicitHeight: Math.min(mainColumn.implicitHeight + Kirigami.Units.largeSpacing * 2,
                             popupMaxHeight)

    // the panel popup sizes itself from these hints, not from implicit size
    Layout.minimumWidth: Kirigami.Units.gridUnit * 19
    Layout.preferredWidth: Kirigami.Units.gridUnit * 19
    Layout.maximumWidth: Kirigami.Units.gridUnit * 19
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight
    Layout.maximumHeight: implicitHeight

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.topMargin: Kirigami.Units.largeSpacing
        anchors.bottomMargin: Kirigami.Units.largeSpacing
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        clip: true
        contentWidth: width
        contentHeight: mainColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar {
            visible: flick.contentHeight > flick.height
        }

        ColumnLayout {
            id: mainColumn
            width: flick.width
            spacing: Kirigami.Units.smallSpacing

            // ---- provider switcher ----
            RowLayout {
                id: tabStrip
                Layout.fillWidth: true
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                visible: fullRoot.currentTab !== "about" && fullRoot.tabs.length > 1
                spacing: 0

                Repeater {
                    model: fullRoot.tabs

                    Item {
                        id: tab
                        required property string modelData
                        readonly property string tabId: modelData
                        readonly property bool isOverview: tabId === "overview"
                        readonly property bool selected: fullRoot.currentTab === tabId
                        readonly property var meta: Catalog.meta(tabId)
                        readonly property real remaining:
                            isOverview ? -1 : fullRoot.plasmoidRoot.remainingPercent(tabId, "session")

                        Layout.fillWidth: true
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 2.9

                        Rectangle {
                            id: plate
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 2
                            height: parent.height - 8
                            radius: Kirigami.Units.cornerRadius + 2
                            color: tab.selected
                                   ? Kirigami.Theme.highlightColor
                                   : (tabMouse.containsMouse
                                      ? Qt.alpha(Kirigami.Theme.textColor, 0.06)
                                      : "transparent")

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Math.round(Kirigami.Units.smallSpacing / 2)

                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium

                                    // 2×2 grid of rounded squares, like the original
                                    // Overview tab icon (crisp in light and dark mode)
                                    Grid {
                                        visible: tab.isOverview
                                        anchors.centerIn: parent
                                        rows: 2
                                        columns: 2
                                        spacing: Math.max(2, Math.round(parent.width * 0.14))

                                        Repeater {
                                            model: 4
                                            Rectangle {
                                                width: Math.round(Kirigami.Units.iconSizes.smallMedium * 0.36)
                                                height: width
                                                radius: Math.max(2, width * 0.3)
                                                color: tab.selected
                                                       ? Kirigami.Theme.highlightedTextColor
                                                       : Qt.alpha(Kirigami.Theme.textColor, 0.7)
                                            }
                                        }
                                    }

                                    ProviderIconImage {
                                        visible: !tab.isOverview
                                        anchors.fill: parent
                                        iconFile: tab.meta.icon
                                        tint: tab.selected
                                              ? Kirigami.Theme.highlightedTextColor
                                              : Qt.alpha(Kirigami.Theme.textColor, 0.7)
                                    }
                                }

                                PlasmaComponents3.Label {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.maximumWidth: tab.width - 6
                                    text: tab.isOverview ? i18n("Overview") : tab.meta.name
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95
                                    elide: Text.ElideRight
                                    color: tab.selected
                                           ? Kirigami.Theme.highlightedTextColor
                                           : Qt.alpha(Kirigami.Theme.textColor, 0.75)
                                }
                            }
                        }

                        // quota indicator under the tab (hidden while selected, like the original)
                        UsageBar {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                            anchors.rightMargin: Kirigami.Units.smallSpacing * 2
                            height: 3
                            visible: !tab.selected && !tab.isOverview
                            percent: tab.remaining >= 0 ? tab.remaining : 0
                            fillColor: tab.meta.color
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: fullRoot.plasmoidRoot.currentTab = tab.tabId
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: fullRoot.currentTab !== "about" && fullRoot.tabs.length > 1
                implicitHeight: 1
                color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
            }

            Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }

            // ---- content ----
            OverviewPage {
                visible: fullRoot.currentTab === "overview"
                Layout.fillWidth: true
                plasmoidRoot: fullRoot.plasmoidRoot
                onProviderClicked: function (pid) { fullRoot.plasmoidRoot.currentTab = pid }
            }

            Repeater {
                model: fullRoot.plasmoidRoot.enabledProviders

                ProviderCard {
                    required property string modelData
                    visible: fullRoot.currentTab === modelData
                    Layout.fillWidth: true
                    plasmoidRoot: fullRoot.plasmoidRoot
                    providerId: modelData
                }
            }

            AboutPage {
                visible: fullRoot.currentTab === "about"
                Layout.fillWidth: true
                plasmoidRoot: fullRoot.plasmoidRoot
                onBackRequested: fullRoot.plasmoidRoot.currentTab = fullRoot.plasmoidRoot.defaultTab()
            }

            Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }

            // ---- actions ----
            Rectangle {
                Layout.fillWidth: true
                visible: fullRoot.currentTab !== "about"
                implicitHeight: 1
                color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
            }

            MenuRow {
                visible: fullRoot.currentTab !== "about"
                iconName: "view-refresh-symbolic"
                label: i18n("Refresh")
                onActivated: fullRoot.plasmoidRoot.refreshAll()
            }

            MenuRow {
                visible: fullRoot.currentTab !== "about" && fullRoot.onProviderTab
                iconName: "view-statistics-symbolic"
                label: i18n("Usage Dashboard")
                interactive: Catalog.meta(fullRoot.currentTab).dashboard !== ""
                onActivated: Qt.openUrlExternally(Catalog.meta(fullRoot.currentTab).dashboard)
            }

            MenuRow {
                visible: fullRoot.currentTab !== "about" && fullRoot.onProviderTab
                iconName: "system-monitor-symbolic"
                label: i18n("Status Page")
                interactive: {
                    fullRoot.plasmoidRoot.rev
                    var d = fullRoot.plasmoidRoot.usageData[fullRoot.currentTab]
                    var url = d && d.entry && d.entry.status && d.entry.status.url
                            ? d.entry.status.url : Catalog.meta(fullRoot.currentTab).status
                    return url !== "" && url !== undefined
                }
                onActivated: {
                    var d = fullRoot.plasmoidRoot.usageData[fullRoot.currentTab]
                    var url = d && d.entry && d.entry.status && d.entry.status.url
                            ? d.entry.status.url : Catalog.meta(fullRoot.currentTab).status
                    if (url)
                        Qt.openUrlExternally(url)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: fullRoot.currentTab !== "about"
                implicitHeight: 1
                color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
            }

            MenuRow {
                visible: fullRoot.currentTab !== "about"
                label: i18n("Settings…")
                onActivated: Plasmoid.internalAction("configure").trigger()
            }

            MenuRow {
                visible: fullRoot.currentTab !== "about"
                label: i18n("About CodexBar")
                onActivated: fullRoot.plasmoidRoot.currentTab = "about"
            }
        }
    }
}
