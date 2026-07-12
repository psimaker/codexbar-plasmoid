import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "code/catalog.js" as Catalog

// The "Overview" tab: one compact row per provider.
ColumnLayout {
    id: overview

    required property var plasmoidRoot

    signal providerClicked(string providerId)

    spacing: Kirigami.Units.smallSpacing

    PlasmaComponents3.Label {
        visible: overview.plasmoidRoot.enabledProviders.length === 0
        text: i18n("No overview data available.")
        opacity: 0.5
        Layout.fillWidth: true
    }

    Repeater {
        model: overview.plasmoidRoot.enabledProviders

        Rectangle {
            id: overviewRow
            required property string modelData
            readonly property string providerId: modelData
            readonly property var meta: Catalog.meta(providerId)
            readonly property var d: {
                overview.plasmoidRoot.rev
                var x = overview.plasmoidRoot.usageData[providerId]
                return x ? Object.assign({}, x) : null
            }
            readonly property var usage: d && d.entry && d.entry.usage ? d.entry.usage : null
            readonly property var primaryWin: usage ? Catalog.usableWindow(usage.primary) : null
            readonly property var secondaryWin: usage ? Catalog.usableWindow(usage.secondary) : null

            Layout.fillWidth: true
            implicitHeight: rowContent.implicitHeight + Kirigami.Units.smallSpacing * 2
            radius: Kirigami.Units.cornerRadius
            color: rowMouse.containsMouse ? Qt.alpha(Kirigami.Theme.textColor, 0.07) : "transparent"

            RowLayout {
                id: rowContent
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing * 2

                ProviderIconImage {
                    iconFile: overviewRow.meta.icon
                    tint: Kirigami.Theme.textColor
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(Kirigami.Units.smallSpacing / 2)

                    RowLayout {
                        Layout.fillWidth: true

                        PlasmaComponents3.Label {
                            text: overviewRow.meta.name
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        PlasmaComponents3.Label {
                            visible: text !== ""
                            text: {
                                if (overviewRow.d && overviewRow.d.loading)
                                    return i18n("refreshing…")
                                if (!overviewRow.usage)
                                    return i18n("no data")
                                return ""
                            }
                            opacity: 0.6
                            font: Kirigami.Theme.smallFont
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: Kirigami.Units.smallSpacing * 2
                        rowSpacing: Math.round(Kirigami.Units.smallSpacing / 2)

                        PlasmaComponents3.Label {
                            text: i18n("Session")
                            opacity: 0.6
                            font: Kirigami.Theme.smallFont
                        }

                        UsageBar {
                            Layout.fillWidth: true
                            implicitHeight: 4
                            percent: Catalog.windowBarPercent(overviewRow.primaryWin)
                            fillColor: overviewRow.meta.color
                            opacity: overviewRow.primaryWin ? 1 : 0.35
                        }

                        PlasmaComponents3.Label {
                            text: overviewRow.primaryWin
                                  ? Catalog.windowUsedText(overviewRow.primaryWin) + i18n("% used")
                                  : "–"
                            opacity: 0.6
                            font: Kirigami.Theme.smallFont
                            horizontalAlignment: Text.AlignRight
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                        }

                        PlasmaComponents3.Label {
                            text: i18n("Weekly")
                            opacity: 0.6
                            font: Kirigami.Theme.smallFont
                        }

                        UsageBar {
                            Layout.fillWidth: true
                            implicitHeight: 4
                            percent: Catalog.windowBarPercent(overviewRow.secondaryWin)
                            fillColor: overviewRow.meta.color
                            opacity: overviewRow.secondaryWin ? 0.75 : 0.35
                        }

                        PlasmaComponents3.Label {
                            text: overviewRow.secondaryWin
                                  ? Catalog.windowUsedText(overviewRow.secondaryWin) + i18n("% used")
                                  : "–"
                            opacity: 0.6
                            font: Kirigami.Theme.smallFont
                            horizontalAlignment: Text.AlignRight
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                        }
                    }
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: overview.providerClicked(overviewRow.providerId)
            }
        }
    }
}
