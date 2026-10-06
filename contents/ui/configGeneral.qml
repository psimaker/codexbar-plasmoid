import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property alias cfg_refreshIntervalMinutes: refreshSpin.value
    property alias cfg_showPercentInPanel: showPercent.checked
    property alias cfg_showResetCountdown: showResetCountdown.checked
    property alias cfg_separateIcons: separateIcons.checked
    property string cfg_panelDisplayMode
    property alias cfg_hideCritters: hideCritters.checked
    property bool cfg_usageBarsShowUsed
    property string cfg_middleClickAction
    property string cfg_doubleClickAction
    property alias cfg_launchCommand: launchCommand.text
    property alias cfg_showCost: showCost.checked
    property alias cfg_showStatus: showStatus.checked
    property alias cfg_notifyQuota: notifyQuota.checked
    property alias cfg_notifyThreshold: notifyThreshold.value
    property alias cfg_notifyStatus: notifyStatus.checked
    property alias cfg_cliPath: cliPath.text
    property alias cfg_cliEnvironmentFile: cliEnvironmentFile.text
    property alias cfg_enableClaudeAccounts: enableClaudeAccounts.checked
    property alias cfg_claudeAdapterPath: claudeAdapterPath.text
    property string cfg_panelPercentSource
    property string cfg_percentStyle

    readonly property var sourceValues: ["session", "weekly", "lowest"]
    readonly property var styleValues: ["remaining", "used"]
    readonly property var displayModeValues: ["meters", "logos", "logos-and-meters"]
    // Kirigami.FormLayout sizes itself to its widest item; wrapping hints and
    // path fields stay within this width instead of stretching the page.
    readonly property real hintWidth: Kirigami.Units.gridUnit * 26
    readonly property var clickActionValues: ["none", "refresh", "dashboard", "status", "command"]
    readonly property var clickActionLabels: [i18n("Nothing"), i18n("Refresh"),
        i18n("Open usage dashboard"), i18n("Open status page"), i18n("Run command")]

    onCfg_panelPercentSourceChanged: sourceCombo.sync()
    onCfg_percentStyleChanged: styleCombo.sync()
    onCfg_panelDisplayModeChanged: displayModeCombo.sync()
    onCfg_usageBarsShowUsedChanged: usageBarsFillCombo.sync()
    onCfg_middleClickActionChanged: middleClickCombo.sync()
    onCfg_doubleClickActionChanged: doubleClickCombo.sync()

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

        QQC2.ComboBox {
            id: displayModeCombo
            Kirigami.FormData.label: i18n("Panel display:")
            model: [i18n("Meters / critters"),
                    i18n("Provider logos"),
                    i18n("Provider logos + meters")]
            function sync() {
                var mode = page.cfg_panelDisplayMode
                if (page.displayModeValues.indexOf(mode) < 0)
                    mode = "meters"
                currentIndex = page.displayModeValues.indexOf(mode)
            }
            Component.onCompleted: sync()
            onActivated: page.cfg_panelDisplayMode = page.displayModeValues[currentIndex]
        }

        QQC2.CheckBox {
            id: separateIcons
            text: i18n("One meter per provider (default: one merged meter)")
            enabled: displayModeCombo.currentIndex === 0
        }

        QQC2.CheckBox {
            id: showPercent
            text: i18n("Show percentage next to the icon")
        }

        QQC2.CheckBox {
            id: showResetCountdown
            text: i18n("Show time until reset")
            enabled: showPercent.checked
        }

        Item { Kirigami.FormData.isSection: true }

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

        QQC2.ComboBox {
            id: usageBarsFillCombo
            Kirigami.FormData.label: i18n("Usage bars fill:")
            model: [i18n("As remaining"), i18n("As used")]
            function sync() {
                currentIndex = page.cfg_usageBarsShowUsed ? 1 : 0
            }
            Component.onCompleted: sync()
            onActivated: page.cfg_usageBarsShowUsed = currentIndex === 1
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.ComboBox {
            id: middleClickCombo
            Kirigami.FormData.label: i18n("Middle click:")
            model: page.clickActionLabels
            function sync() {
                currentIndex = Math.max(0, page.clickActionValues.indexOf(page.cfg_middleClickAction))
            }
            Component.onCompleted: sync()
            onActivated: page.cfg_middleClickAction = page.clickActionValues[currentIndex]
        }

        QQC2.ComboBox {
            id: doubleClickCombo
            Kirigami.FormData.label: i18n("Double click:")
            model: page.clickActionLabels
            function sync() {
                currentIndex = Math.max(0, page.clickActionValues.indexOf(page.cfg_doubleClickAction))
            }
            Component.onCompleted: sync()
            onActivated: page.cfg_doubleClickAction = page.clickActionValues[currentIndex]
        }

        QQC2.TextField {
            id: launchCommand
            Kirigami.FormData.label: i18n("Command:")
            placeholderText: i18n("e.g. konsole -e codex")
            Layout.fillWidth: true
            Layout.maximumWidth: page.hintWidth
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: page.hintWidth
            text: i18n("Used by \"Run command\". A provider's own icon follows its settings on the Providers page; on the merged meter, the dashboard and status page open for the provider it currently shows.")
            wrapMode: Text.WordWrap
            opacity: 0.7
            font: Kirigami.Theme.smallFont
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: showCost
            Kirigami.FormData.label: i18n("Menu:")
            text: i18n("Show cost section (local token logs)")
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: page.hintWidth
            text: i18n("Cost scans can use significant disk and memory resources. Automatic scans run at most once per hour; use the separate menu action for an immediate scan.")
            wrapMode: Text.WordWrap
            opacity: 0.7
            font: Kirigami.Theme.smallFont
        }

        QQC2.CheckBox {
            id: showStatus
            text: i18n("Show provider status")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: notifyQuota
            Kirigami.FormData.label: i18n("Notifications:")
            text: i18n("When a quota runs low or resets")
        }

        RowLayout {
            enabled: notifyQuota.checked
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: i18n("Low below")
            }

            QQC2.SpinBox {
                id: notifyThreshold
                from: 1
                to: 99
                Accessible.name: i18n("Low quota threshold in percent left")
            }

            QQC2.Label {
                text: i18n("% left")
            }
        }

        QQC2.CheckBox {
            id: notifyStatus
            text: i18n("When a provider's status changes")
            enabled: showStatus.checked
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: page.hintWidth
            text: i18n("Only changes seen while the widget runs are announced, never what it finds on start. Status changes need \"Show provider status\".")
            wrapMode: Text.WordWrap
            opacity: 0.7
            font: Kirigami.Theme.smallFont
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.TextField {
            id: cliPath
            Kirigami.FormData.label: i18n("codexbar CLI path:")
            placeholderText: i18n("auto (codexbar in PATH)")
            Layout.fillWidth: true
            Layout.maximumWidth: page.hintWidth
        }

        QQC2.TextField {
            id: cliEnvironmentFile
            Kirigami.FormData.label: i18n("CLI environment file:")
            placeholderText: i18n("optional, e.g. ~/.config/codexbar/widget.env")
            Layout.fillWidth: true
            Layout.maximumWidth: page.hintWidth
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: page.hintWidth
            text: i18n("KEY=VALUE lines exported only to the codexbar process, for provider API keys such as OPENCODE_API_KEY. Quote values that contain spaces. Keep the file readable by you alone (chmod 600). Plasma does not pass your shell environment to widgets.")
            wrapMode: Text.WordWrap
            opacity: 0.7
            font: Kirigami.Theme.smallFont
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: enableClaudeAccounts
            Kirigami.FormData.label: i18n("Claude accounts:")
            text: i18n("Show all accounts from a schema-v1 adapter")
        }

        QQC2.TextField {
            id: claudeAdapterPath
            Kirigami.FormData.label: i18n("Adapter executable path:")
            enabled: enableClaudeAccounts.checked
            placeholderText: i18n("auto (cswap in PATH)")
            Layout.fillWidth: true
            Layout.maximumWidth: page.hintWidth
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: page.hintWidth
            enabled: enableClaudeAccounts.checked
            text: i18n("The widget only runs --list --json and an explicitly selected --switch-to <slot> --json operation.")
            wrapMode: Text.WordWrap
            opacity: 0.7
        }
    }
}
