import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property alias cfg_refreshIntervalMinutes: refreshSpin.value
    property alias cfg_showPercentInPanel: showPercent.checked
    property alias cfg_separateIcons: separateIcons.checked
    property alias cfg_hideCritters: hideCritters.checked
    property alias cfg_showCost: showCost.checked
    property alias cfg_showStatus: showStatus.checked
    property alias cfg_cliPath: cliPath.text
    property string cfg_panelPercentSource
    property string cfg_percentStyle

    readonly property var sourceValues: ["session", "weekly", "lowest"]
    readonly property var styleValues: ["remaining", "used"]

    onCfg_panelPercentSourceChanged: sourceCombo.sync()
    onCfg_percentStyleChanged: styleCombo.sync()

    Kirigami.FormLayout {

        QQC2.SpinBox {
            id: refreshSpin
            Kirigami.FormData.label: i18n("Refresh interval:")
            from: 1
            to: 240
            stepSize: 1
            textFromValue: function (value) { return i18np("%1 minute", "%1 minutes", value) }
            valueFromText: function (text) { return parseInt(text) || 5 }

            // SpinBox does not size itself for custom textFromValue strings —
            // reserve room for the widest possible label plus the +/- buttons
            TextMetrics {
                id: spinMetrics
                font: refreshSpin.font
                text: i18np("%1 minute", "%1 minutes", 240)
            }
            Layout.minimumWidth: Math.round(spinMetrics.width + Kirigami.Units.gridUnit * 5)
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: separateIcons
            Kirigami.FormData.label: i18n("Panel:")
            text: i18n("One icon per provider (default: one merged icon)")
        }

        QQC2.CheckBox {
            id: showPercent
            text: i18n("Show percentage next to the icon")
        }

        QQC2.ComboBox {
            id: sourceCombo
            Kirigami.FormData.label: i18n("Percentage window:")
            enabled: showPercent.checked
            model: [i18n("Session (5-hour)"), i18n("Weekly"), i18n("Lowest remaining")]
            function sync() {
                currentIndex = Math.max(0, page.sourceValues.indexOf(page.cfg_panelPercentSource))
            }
            Component.onCompleted: sync()
            onActivated: page.cfg_panelPercentSource = page.sourceValues[currentIndex]
        }

        QQC2.ComboBox {
            id: styleCombo
            Kirigami.FormData.label: i18n("Percentage shows:")
            enabled: showPercent.checked
            model: [i18n("Remaining"), i18n("Used")]
            function sync() {
                currentIndex = Math.max(0, page.styleValues.indexOf(page.cfg_percentStyle))
            }
            Component.onCompleted: sync()
            onActivated: page.cfg_percentStyle = page.styleValues[currentIndex]
        }

        QQC2.CheckBox {
            id: hideCritters
            text: i18n("Hide critters (plain meter bars)")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: showCost
            Kirigami.FormData.label: i18n("Menu:")
            text: i18n("Show cost section (local token logs)")
        }

        QQC2.CheckBox {
            id: showStatus
            text: i18n("Show provider status")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.TextField {
            id: cliPath
            Kirigami.FormData.label: i18n("codexbar CLI path:")
            placeholderText: i18n("auto (codexbar in PATH)")
            Layout.fillWidth: true
        }
    }
}
