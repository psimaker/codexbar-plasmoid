import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "code/catalog.js" as Catalog

KCM.SimpleKCM {
    id: page

    property string cfg_enabledProviders

    function enabledList() {
        return (cfg_enabledProviders || "").split(",")
            .map(function (s) { return s.trim() })
            .filter(function (s) { return s.length > 0 })
    }

    function setEnabled(id, on) {
        var list = enabledList()
        var idx = list.indexOf(id)
        if (on && idx < 0)
            list.push(id)
        if (!on && idx >= 0)
            list.splice(idx, 1)
        cfg_enabledProviders = list.join(",")
    }

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Providers are probed with the codexbar CLI. Only enable providers you actually use — each one costs a probe per refresh.")
            wrapMode: Text.WordWrap
            opacity: 0.7
        }

        Kirigami.SearchField {
            id: search
            Layout.fillWidth: true
        }

        Repeater {
            model: Catalog.orderedIds().filter(function (id) {
                var q = search.text.toLowerCase()
                if (q.length === 0)
                    return true
                return id.indexOf(q) >= 0 || Catalog.meta(id).name.toLowerCase().indexOf(q) >= 0
            })

            RowLayout {
                id: row
                required property string modelData
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing * 2

                QQC2.CheckBox {
                    checked: page.enabledList().indexOf(row.modelData) >= 0
                    onToggled: page.setEnabled(row.modelData, checked)
                }

                Image {
                    source: Qt.resolvedUrl("../icons/" + Catalog.meta(row.modelData).icon)
                    sourceSize: Qt.size(32, 32)
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    fillMode: Image.PreserveAspectFit

                    Rectangle {
                        anchors.fill: parent
                        z: -1
                        radius: 4
                        color: Catalog.meta(row.modelData).color
                    }
                }

                QQC2.Label {
                    text: Catalog.meta(row.modelData).name
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                QQC2.Label {
                    text: row.modelData
                    opacity: 0.5
                    font: Kirigami.Theme.smallFont
                }
            }
        }
    }
}
