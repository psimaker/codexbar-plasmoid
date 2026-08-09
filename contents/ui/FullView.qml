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
    readonly property real popupBaseWidth: Kirigami.Units.gridUnit * 19
    readonly property int initiallyVisibleTabs: 4

    FontMetrics {
        id: tabFontMetrics
        font: Kirigami.Theme.smallFont
    }

    function naturalTabWidth(tabId) {
        var label = tabId === "overview" ? i18n("Overview") : Catalog.meta(tabId).name
        return Math.max(Kirigami.Units.gridUnit * 3.5,
                        Math.ceil(tabFontMetrics.advanceWidth(label)
                                  + Kirigami.Units.smallSpacing * 4))
    }

    // cap the popup height to the usable screen area (fallback: 42 grid units)
    readonly property real popupMaxHeight: {
        var cap = Kirigami.Units.gridUnit * 42
        var rect = Plasmoid.availableScreenRect
        if (rect && rect.height > 0)
            cap = Math.min(cap, rect.height - Kirigami.Units.gridUnit * 3)
        return Math.max(cap, Kirigami.Units.gridUnit * 12)
    }
    readonly property real popupMaxWidth: {
        var cap = Kirigami.Units.gridUnit * 42
        var rect = Plasmoid.availableScreenRect
        if (rect && rect.width > 0)
            cap = Math.min(cap, rect.width - Kirigami.Units.gridUnit * 3)
        return Math.max(cap, popupBaseWidth)
    }
    readonly property real initialTabStripWidth: {
        var width = 0
        var count = Math.min(tabs.length, initiallyVisibleTabs)
        for (var i = 0; i < count; ++i)
            width += naturalTabWidth(tabs[i])
        return width
    }
    readonly property real overflowControlsWidth: tabs.length > initiallyVisibleTabs
                                                   ? Kirigami.Units.iconSizes.smallMedium * 2 : 0
    readonly property real desiredPopupWidth: initialTabStripWidth
                                               + overflowControlsWidth
                                               + Kirigami.Units.largeSpacing * 2

    implicitWidth: Math.min(Math.max(popupBaseWidth, desiredPopupWidth), popupMaxWidth)
    implicitHeight: Math.min(mainColumn.implicitHeight + Kirigami.Units.largeSpacing * 2,
                             popupMaxHeight)

    // the panel popup sizes itself from these hints, not from implicit size
    Layout.minimumWidth: implicitWidth
    Layout.preferredWidth: implicitWidth
    Layout.maximumWidth: implicitWidth
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
            id: verticalScrollBar
            visible: flick.contentHeight > flick.height
        }

        ColumnLayout {
            id: mainColumn
            width: flick.width - (verticalScrollBar.visible
                                  ? verticalScrollBar.width + Kirigami.Units.smallSpacing
                                  : 0)
            spacing: Kirigami.Units.smallSpacing

            // ---- provider switcher ----
            Item {
                id: tabStrip
                readonly property bool overflowing: tabList.contentWidth > tabList.width + 1
                Layout.fillWidth: true
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2.9
                visible: fullRoot.currentTab !== "about" && fullRoot.tabs.length > 1
                clip: true

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    PlasmaComponents3.ToolButton {
                        visible: tabStrip.overflowing
                        enabled: !tabList.atXBeginning
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.fillHeight: true
                        icon.name: "go-previous-symbolic"
                        onClicked: tabList.scrollByPage(-1)
                    }

                    Flickable {
                        id: tabList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: tabRow.implicitWidth
                        contentHeight: height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.AutoFlickIfNeeded
                        readonly property int currentIndex:
                            Math.max(0, fullRoot.tabs.indexOf(fullRoot.currentTab))

                        function scrollByPage(direction) {
                            var limit = Math.max(0, contentWidth - width)
                            var step = Math.max(width * 0.7, Kirigami.Units.gridUnit * 4)
                            contentX = Math.max(0, Math.min(limit, contentX + direction * step))
                        }

                        function revealIndex(index) {
                            if (index < 0 || index >= fullRoot.tabs.length || width <= 0)
                                return

                            var left = 0
                            for (var i = 0; i < index; ++i)
                                left += fullRoot.naturalTabWidth(fullRoot.tabs[i])

                            var right = left + fullRoot.naturalTabWidth(fullRoot.tabs[index])
                            var margin = Kirigami.Units.smallSpacing
                            var limit = Math.max(0, contentWidth - width)

                            if (left < contentX + margin)
                                contentX = Math.max(0, left - margin)
                            else if (right > contentX + width - margin)
                                contentX = Math.min(limit, right - width + margin)
                        }

                        onCurrentIndexChanged: Qt.callLater(function () {
                            if (currentIndex >= 0)
                                revealIndex(currentIndex)
                        })
                        onWidthChanged: Qt.callLater(function () { revealIndex(currentIndex) })

                        Kirigami.WheelHandler {
                            target: tabList
                        }

                        Row {
                            id: tabRow
                            height: parent.height
                            spacing: 0

                            Repeater {
                                model: fullRoot.tabs

                                delegate: Item {
                                    id: tab
                                    required property string modelData
                                    readonly property string tabId: modelData
                                    readonly property bool isOverview: tabId === "overview"
                                    readonly property bool selected: fullRoot.currentTab === tabId
                                    readonly property var meta: Catalog.meta(tabId)
                                    readonly property real remaining:
                                        isOverview ? -1 : fullRoot.plasmoidRoot.remainingPercent(tabId, "session")

                                    width: fullRoot.naturalTabWidth(tabId)
                                    height: tabList.height

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
                                                    displayContext: tab.selected
                                                                    ? ProviderIconImage.SelectedContext
                                                                    : ProviderIconImage.NormalContext
                                                }
                                            }

                                            PlasmaComponents3.Label {
                                                id: tabLabel
                                                Layout.alignment: Qt.AlignHCenter
                                                Layout.maximumWidth: tab.width - Kirigami.Units.smallSpacing * 2
                                                text: tab.isOverview ? i18n("Overview") : tab.meta.name
                                                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95
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
                    }

                    PlasmaComponents3.ToolButton {
                        visible: tabStrip.overflowing
                        enabled: !tabList.atXEnd
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.fillHeight: true
                        icon.name: "go-next-symbolic"
                        onClicked: tabList.scrollByPage(1)
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
                             && !(modelData === "claude"
                                  && fullRoot.plasmoidRoot.claudeAccountsEnabled)
                    Layout.fillWidth: true
                    plasmoidRoot: fullRoot.plasmoidRoot
                    providerId: modelData
                }
            }

            ClaudeAccountsPage {
                visible: fullRoot.currentTab === "claude"
                         && fullRoot.plasmoidRoot.claudeAccountsEnabled
                Layout.fillWidth: true
                plasmoidRoot: fullRoot.plasmoidRoot
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
                onActivated: fullRoot.plasmoidRoot.refreshAll(true)
            }

            MenuRow {
                visible: fullRoot.onProviderTab
                         && Plasmoid.configuration.showCost
                         && Catalog.COST_PROVIDERS.indexOf(fullRoot.currentTab) >= 0
                iconName: "view-refresh-symbolic"
                label: fullRoot.plasmoidRoot.costRefreshInFlight === fullRoot.currentTab
                       ? i18n("Refreshing cost history…")
                       : i18n("Refresh cost history")
                interactive: fullRoot.plasmoidRoot.canRefreshCost(fullRoot.currentTab)
                onActivated: fullRoot.plasmoidRoot.refreshCost(fullRoot.currentTab, true)
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
