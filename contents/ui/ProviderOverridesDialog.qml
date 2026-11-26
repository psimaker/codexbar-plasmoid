import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "code/catalog.js" as Catalog
import "code/providerOverrides.js" as ProviderOverrides

// Per-provider panel overrides for one provider. The dialog never writes
// configuration itself: OK emits staged() with the new providerOverrides
// string and the settings page assigns it to its cfg_ property, so the page's
// Apply/OK stays the single commit. Cancel drops every change made here.
QQC2.Dialog {
    id: dialog

    // Current providerOverrides string (bind to the page's cfg_ property).
    property string overrides: "{}"
    // Global values the unticked rows follow:
    // { panelDisplayMode, showPercentInPanel, panelPercentSource, percentStyle,
    //   showResetCountdown, hideCritters, middleClickAction, doubleClickAction,
    //   launchCommand }
    property var globals: ({})

    // Provider id being edited, and its display name.
    property string providerId: ""
    property string providerName: ""
    // Working state while open: key -> { custom: bool, value: var }.
    property var rows: ({})

    signal staged(string overrides)

    // Sample quota values for the footer preview.
    readonly property int previewSampleSession: 72
    readonly property int previewSampleWeekly: 45
    readonly property real previewSampleBalance: 14.46
    // Same icon size the panel uses, so the preview renders 1:1.
    readonly property real previewIconSide: Kirigami.Units.iconSizes.medium

    modal: true
    title: providerId === ""
        ? i18n("Provider settings")
        : i18n("Settings for %1", providerName !== "" ? providerName : Catalog.meta(providerId).name)

    // Fill the working state (overrides where set, globals elsewhere) and open.
    function openFor(id, name) {
        dialog.providerId = id
        dialog.providerName = typeof name === "string" ? name : ""
        dialog.loadRows()
        dialog.open()
    }

    function loadRows() {
        var current = ProviderOverrides.settingsFor(dialog.overrides, dialog.providerId)
        var state = {}
        var keys = ProviderOverrides.SETTING_KEYS
        for (var i = 0; i < keys.length; i++) {
            if (current[keys[i]] !== undefined)
                state[keys[i]] = { custom: true, value: current[keys[i]] }
            else
                state[keys[i]] = { custom: false, value: dialog.globalValue(keys[i]) }
        }
        dialog.rows = state
    }

    // Ticked rows replace this provider's overrides; unticked rows revert
    // to "use global".
    function stage() {
        dialog.staged(ProviderOverrides.withSettings(
            ProviderOverrides.resetProvider(dialog.overrides, dialog.providerId),
            dialog.providerId, dialog.tickedValues()))
        dialog.close()
    }

    // Untick every row; OK then stages the provider without overrides.
    function resetToGlobal() {
        var state = {}
        var keys = ProviderOverrides.SETTING_KEYS
        for (var i = 0; i < keys.length; i++)
            state[keys[i]] = { custom: false, value: dialog.globalValue(keys[i]) }
        dialog.rows = state
    }

    function tickedValues() {
        var values = {}
        var keys = ProviderOverrides.SETTING_KEYS
        for (var i = 0; i < keys.length; i++) {
            // Rows whose prerequisite is off can't be edited; don't store them.
            if (dialog.rowCustom(keys[i]) && dialog.requiresMet(keys[i])) {
                var value = dialog.rowValue(keys[i])
                values[keys[i]] = typeof value === "string" ? value.trim() : value
            }
        }
        return values
    }

    function globalValue(key) {
        // The label's value has no General setting; it follows the provider.
        if (key === "panelValue")
            return Catalog.balanceReplacesPercent(dialog.providerId) ? "balance" : "percent"
        return dialog.globals[key]
    }

    function displayModeLabel(mode) {
        if (mode === "logos")
            return i18n("Provider logos")
        if (mode === "logos-and-meters")
            return i18n("Provider logos + meters")
        return i18n("Meters / critters")
    }

    function percentSourceLabel(source) {
        if (source === "weekly")
            return i18n("Weekly")
        if (source === "lowest")
            return i18n("Lowest remaining")
        return i18n("Session (5-hour)")
    }

    function panelValueLabel(value) {
        return value === "balance" ? i18n("Balance") : i18n("Percentage")
    }

    function percentStyleLabel(style) {
        return style === "used" ? i18n("Used") : i18n("Remaining")
    }

    function sectionTitle(section) {
        if (section === "appearance")
            return i18n("Appearance")
        if (section === "percentage")
            return i18n("Percentage")
        if (section === "critters")
            return i18n("Critters")
        if (section === "clicks")
            return i18n("Clicks")
        return section
    }

    function clickActionLabel(action) {
        if (action === "refresh")
            return i18n("Refresh")
        if (action === "dashboard")
            return i18n("Open usage dashboard")
        if (action === "status")
            return i18n("Open status page")
        if (action === "command")
            return i18n("Run command")
        return i18n("Nothing")
    }

    function settingLabel(key) {
        if (key === "panelDisplayMode")
            return i18n("Panel display:")
        if (key === "showPercentInPanel")
            return i18n("Show percentage:")
        if (key === "panelValue")
            return i18n("Label shows:")
        if (key === "panelPercentSource")
            return i18n("Percentage window:")
        if (key === "percentStyle")
            return i18n("Percentage shows:")
        if (key === "showResetCountdown")
            return i18n("Time until reset:")
        if (key === "hideCritters")
            return i18n("Critters:")
        if (key === "middleClickAction")
            return i18n("Middle click:")
        if (key === "doubleClickAction")
            return i18n("Double click:")
        if (key === "launchCommand")
            return i18n("Command:")
        return key
    }

    function boolEditorLabel(key) {
        if (key === "hideCritters")
            return i18n("Plain meter bars")
        return i18n("Show")
    }

    function optionValues(key) {
        var def = ProviderOverrides.defFor(key)
        if (def === null || def.values === undefined)
            return []
        return def.values
    }

    function optionLabels(key) {
        var values = dialog.optionValues(key)
        if (key === "panelDisplayMode")
            return values.map(dialog.displayModeLabel)
        if (key === "panelValue")
            return values.map(dialog.panelValueLabel)
        if (key === "panelPercentSource")
            return values.map(dialog.percentSourceLabel)
        if (key === "percentStyle")
            return values.map(dialog.percentStyleLabel)
        if (key === "middleClickAction" || key === "doubleClickAction")
            return values.map(dialog.clickActionLabel)
        return values
    }

    function globalHint(key) {
        var g = dialog.globals
        if (key === "panelDisplayMode")
            return i18n("Global: %1", dialog.displayModeLabel(g.panelDisplayMode))
        if (key === "showPercentInPanel")
            return g.showPercentInPanel ? i18n("Global: shown") : i18n("Global: hidden")
        if (key === "panelValue")
            return Catalog.balanceReplacesPercent(dialog.providerId)
                ? i18n("Global: balance") : i18n("Global: percentage, else balance")
        if (key === "panelPercentSource")
            return i18n("Global: %1", dialog.percentSourceLabel(g.panelPercentSource))
        if (key === "percentStyle")
            return i18n("Global: %1", dialog.percentStyleLabel(g.percentStyle))
        if (key === "showResetCountdown")
            return g.showResetCountdown ? i18n("Global: shown") : i18n("Global: hidden")
        if (key === "hideCritters")
            return g.hideCritters ? i18n("Global: plain bars") : i18n("Global: critters")
        if (key === "middleClickAction" || key === "doubleClickAction")
            return i18n("Global: %1", dialog.clickActionLabel(g[key]))
        if (key === "launchCommand")
            return g.launchCommand ? i18n("Global: %1", g.launchCommand) : i18n("Global: none")
        return ""
    }

    function row(key) {
        if (dialog.rows[key] !== undefined)
            return dialog.rows[key]
        return { custom: false, value: dialog.globalValue(key) }
    }

    function rowCustom(key) {
        return dialog.row(key).custom === true
    }

    function rowValue(key) {
        return dialog.row(key).value
    }

    function hasCustom() {
        var keys = ProviderOverrides.SETTING_KEYS
        for (var i = 0; i < keys.length; i++) {
            if (dialog.rowCustom(keys[i]))
                return true
        }
        return false
    }

    function setRowCustom(key, custom) {
        var current = dialog.row(key)
        if ((current.custom === true) === (custom === true))
            return
        var state = Object.assign({}, dialog.rows)
        state[key] = { custom: custom === true, value: current.value }
        dialog.rows = state
    }

    function setRowValue(key, value) {
        var current = dialog.row(key)
        if (current.value === value)
            return
        var state = Object.assign({}, dialog.rows)
        state[key] = { custom: current.custom === true, value: value }
        dialog.rows = state
    }

    // A row whose registry entry names `requires` is only editable when the
    // required setting is effectively enabled (override or global).
    function requiresMet(key) {
        var def = ProviderOverrides.defFor(key)
        if (def === null || def.requires === undefined)
            return true
        var required = dialog.row(def.requires)
        var effective = required.custom === true ? required.value : dialog.globalValue(def.requires)
        return effective === true
    }

    // Live footer preview. It resolves the *uncommitted* working state through
    // the same effective* helpers the panel uses, so what you see is what the
    // widget would render.
    function previewOverrides() {
        var map = {}
        map[dialog.providerId] = dialog.tickedValues()
        return ProviderOverrides.serialize(map)
    }

    function previewDisplayMode() {
        return ProviderOverrides.effectiveDisplayMode(
            dialog.previewOverrides(), dialog.providerId, dialog.globals.panelDisplayMode)
    }

    function previewShowsLogos() {
        var mode = dialog.previewDisplayMode()
        return mode === "logos" || mode === "logos-and-meters"
    }

    function previewShowsMeters() {
        var mode = dialog.previewDisplayMode()
        return mode === "meters" || mode === "logos-and-meters"
    }

    function previewShowPercent() {
        return ProviderOverrides.effectiveShowPercent(
            dialog.previewOverrides(), dialog.providerId, dialog.globals.showPercentInPanel)
    }

    function previewPercentText() {
        var raw = dialog.previewOverrides()
        if (ProviderOverrides.effectivePanelValue(raw, dialog.providerId,
                                                  dialog.globalValue("panelValue")) === "balance")
            return Catalog.amountText(dialog.previewSampleBalance, "USD")
        var source = ProviderOverrides.effectivePercentSource(
            raw, dialog.providerId, dialog.globals.panelPercentSource)
        var v = source === "weekly" ? dialog.previewSampleWeekly
            : source === "lowest" ? Math.min(dialog.previewSampleSession, dialog.previewSampleWeekly)
            : dialog.previewSampleSession
        if (ProviderOverrides.effectivePercentStyle(raw, dialog.providerId, dialog.globals.percentStyle) === "used")
            v = 100 - v
        if (ProviderOverrides.effectiveShowResetCountdown(raw, dialog.providerId, dialog.globals.showResetCountdown))
            return Math.round(v) + "% · 3h 50m"
        return Math.round(v) + "%"
    }

    function previewHideCritters() {
        return ProviderOverrides.effectiveHideCritters(
            dialog.previewOverrides(), dialog.providerId, dialog.globals.hideCritters)
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Only ticked rows override the General settings, and only for this provider.")
            wrapMode: Text.WordWrap
            opacity: 0.7
            font: Kirigami.Theme.smallFont
        }

        Repeater {
            model: ProviderOverrides.SECTIONS

            delegate: QQC2.GroupBox {
                required property string modelData
                readonly property string sectionId: modelData
                Layout.fillWidth: true
                title: dialog.sectionTitle(sectionId)

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Kirigami.Units.smallSpacing

                    Repeater {
                        model: ProviderOverrides.keysForSection(sectionId)

                        delegate: RowLayout {
                            required property string modelData
                            readonly property string settingKey: modelData
                            readonly property var settingDef: ProviderOverrides.defFor(settingKey)
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            QQC2.CheckBox {
                                id: customBox
                                // Can't override a row whose prerequisite is off.
                                enabled: dialog.requiresMet(settingKey)
                                checked: dialog.rowCustom(settingKey)
                                onToggled: dialog.setRowCustom(settingKey, checked)
                                Accessible.name: i18n("Override %1", dialog.settingLabel(settingKey))
                            }

                            QQC2.Label {
                                text: dialog.settingLabel(settingKey)
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                                elide: Text.ElideRight
                            }

                            QQC2.CheckBox {
                                visible: settingDef !== null && settingDef.control === "bool"
                                enabled: customBox.checked && dialog.requiresMet(settingKey)
                                text: dialog.boolEditorLabel(settingKey)
                                checked: dialog.rowValue(settingKey) === true
                                onToggled: dialog.setRowValue(settingKey, checked)
                            }

                            QQC2.ComboBox {
                                visible: settingDef !== null && settingDef.control === "enum"
                                enabled: customBox.checked && dialog.requiresMet(settingKey)
                                model: dialog.optionLabels(settingKey)
                                currentIndex: Math.max(0, dialog.optionValues(settingKey).indexOf(dialog.rowValue(settingKey)))
                                onActivated: dialog.setRowValue(settingKey, dialog.optionValues(settingKey)[currentIndex])
                            }

                            QQC2.TextField {
                                visible: settingDef !== null && settingDef.control === "text"
                                enabled: customBox.checked && dialog.requiresMet(settingKey)
                                Layout.fillWidth: true
                                placeholderText: i18n("e.g. konsole -e codex")
                                text: dialog.rowValue(settingKey) || ""
                                onTextEdited: dialog.setRowValue(settingKey, text)
                            }

                            QQC2.Label {
                                Layout.fillWidth: settingDef === null || settingDef.control !== "text"
                                horizontalAlignment: Text.AlignRight
                                text: dialog.globalHint(settingKey)
                                elide: Text.ElideRight
                                opacity: 0.6
                                font: Kirigami.Theme.smallFont
                            }
                        }
                    }
                }
            }
        }
    }

    footer: RowLayout {
        spacing: Kirigami.Units.smallSpacing * 2

        QQC2.Frame {
            // The footer spans the dialog edge to edge while the cards
            // sit inside its padding; match it so the preview card lines
            // up with the section borders above, with room below it.
            Layout.alignment: Qt.AlignBottom
            Layout.leftMargin: dialog.leftPadding
            // The button box brings its own inner bottom padding; the
            // bare card needs extra margin for equal clearance below.
            Layout.bottomMargin: Kirigami.Units.smallSpacing * 2
            visible: dialog.providerId !== ""

            ColumnLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label {
                    text: i18n("Preview")
                    opacity: 0.7
                    font: Kirigami.Theme.smallFont
                }

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing * 2

                    Item {
                        visible: dialog.previewShowsLogos()
                        Layout.preferredWidth: dialog.previewIconSide
                        Layout.preferredHeight: dialog.previewIconSide
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: Kirigami.Units.smallSpacing
                            color: Catalog.logoBackgroundColor(dialog.providerId)
                        }

                        ProviderIconImage {
                            anchors.fill: parent
                            iconFile: Catalog.meta(dialog.providerId).icon
                            displayContext: ProviderIconImage.ContrastingContext
                        }
                    }

                    CritterIcon {
                        visible: dialog.previewShowsMeters()
                        Layout.preferredWidth: dialog.previewIconSide
                        Layout.preferredHeight: dialog.previewIconSide
                        Layout.alignment: Qt.AlignVCenter
                        providerId: dialog.providerId
                        remainingPrimary: dialog.previewSampleSession
                        remainingSecondary: dialog.previewSampleWeekly
                        stale: false
                        hideCritters: dialog.previewHideCritters()
                    }

                    QQC2.Label {
                        visible: dialog.previewShowPercent()
                        Layout.alignment: Qt.AlignVCenter
                        font.pixelSize: Math.max(9, Math.round(dialog.previewIconSide * 0.62))
                        text: dialog.previewPercentText()
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        QQC2.DialogButtonBox {
            Layout.alignment: Qt.AlignRight | Qt.AlignBottom
            Layout.rightMargin: dialog.rightPadding
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            QQC2.Button {
                text: i18n("OK")
                icon.name: "dialog-ok-apply"
                QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.AcceptRole
                onClicked: dialog.stage()
            }
            QQC2.Button {
                text: i18n("Reset to global")
                enabled: dialog.hasCustom()
                icon.name: "document-revert"
                QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.ResetRole
                onClicked: dialog.resetToGlobal()
            }
            QQC2.Button {
                text: i18n("Cancel")
                icon.name: "dialog-cancel"
                QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.RejectRole
                onClicked: dialog.close()
            }
        }
    }
}
