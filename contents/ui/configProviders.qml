import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid
import "code/catalog.js" as Catalog
import "code/providerSources.js" as ProviderSources
import "code/providerOverrides.js" as ProviderOverrides

KCM.SimpleKCM {
    id: page

    property string cfg_enabledProviders
    property string cfg_configProviders
    property string cfg_providerSources
    property string cfg_providerOverrides
    // Globals the override dialog's unticked rows follow; never assigned here.
    property string cfg_panelDisplayMode: "meters"
    property bool cfg_showPercentInPanel: false
    property string cfg_panelPercentSource: "session"
    property string cfg_percentStyle: "remaining"
    property bool cfg_showResetCountdown: false
    property bool cfg_hideCritters: false
    property string cfg_middleClickAction: "none"
    property string cfg_doubleClickAction: "none"
    property string cfg_launchCommand
    // View filter only: not a setting, so toggling it is no pending change.
    property bool showEnabledOnly: false

    // Providers with at least one override, in list order (enabled or not).
    readonly property var overriddenIds: ProviderOverrides.overriddenProviders(
        cfg_providerOverrides, providerIds())

    readonly property var sourceLabels: [
        i18n("Auto"), i18n("Web"), i18n("CLI"), i18n("OAuth"), i18n("API")
    ]

    // CodexBar's config.json as the widget last read it (#25), or null while
    // the widget keeps its own list (CodexBar CLI older than 0.66).
    readonly property var configList: {
        var list = null
        try {
            list = JSON.parse(cfg_configProviders || "null")
        } catch (e) {
            list = null
        }
        return Array.isArray(list) && list.length > 0 ? list : null
    }

    function configEntry(id) {
        var list = configList || []
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id)
                return list[i]
        }
        return null
    }

    function providerIds() {
        return configList ? configList.map(function (p) { return p.id }) : Catalog.orderedIds()
    }

    function providerName(id) {
        var entry = configEntry(id)
        return Catalog.PROVIDERS[id] === undefined && entry ? entry.name : Catalog.meta(id).name
    }

    // Source choices for one provider. With config.json the first choice is
    // the source stored there; the others override it for the widget's probes.
    function sourceModel(id) {
        var labels = page.sourceLabels.slice()
        var entry = configEntry(id)
        if (entry) {
            var index = ProviderSources.SOURCES.indexOf(entry.source)
            labels[0] = i18n("Config: %1", index >= 0 ? page.sourceLabels[index] : entry.source)
        }
        return labels
    }

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

    // Ask before dropping overrides: one provider's, or everyone's for "".
    function confirmReset(id) {
        resetDialog.providerId = id
        resetDialog.open()
    }

    // Staged like every other edit; the page Apply/OK commits it.
    function applyConfirmedReset() {
        page.cfg_providerOverrides = resetDialog.providerId === ""
            ? ProviderOverrides.serialize({})
            : ProviderOverrides.resetProvider(page.cfg_providerOverrides, resetDialog.providerId)
        resetDialog.close()
    }

    function overriddenProviderLines() {
        var enabled = page.enabledList()
        return page.overriddenIds.map(function (id) {
            var name = page.providerName(id)
            return enabled.indexOf(id) >= 0
                ? "• " + name
                : "• " + i18n("%1 (not enabled)", name)
        }).join("\n")
    }

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        // Read live, not as a cfg_ key: the widget sets it after Apply while
        // this page may still be open, and Apply must not write it back.
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: Plasmoid.configuration.configWriteError !== ""
            type: Kirigami.MessageType.Error
            text: i18n("Could not save the provider selection to CodexBar's config.json: %1",
                       Plasmoid.configuration.configWriteError)
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: page.configList
                ? i18n("Providers and whether they are enabled come from CodexBar's config.json, which the CodexBar CLI and app share; Apply writes your changes there with codexbar config enable/disable. Each enabled provider costs a probe per refresh. The source column shows the source stored in config.json; any other choice overrides it for this widget only (--source). The gear button opens per-provider overrides for the panel settings; anything left unticked there follows the General page.")
                : i18n("Providers are probed with the codexbar CLI. Only enable providers you actually use — each one costs a probe per refresh. The source column picks the CodexBar data source (--source) for a provider; Auto lets the CLI decide. The gear button opens per-provider overrides for the panel settings; anything left unticked there follows the General page.")
            wrapMode: Text.WordWrap
            opacity: 0.7
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: page.overriddenIds.length > 0
            type: Kirigami.MessageType.Information
            text: i18np("Custom panel settings are active for %1 provider.",
                        "Custom panel settings are active for %1 providers.",
                        page.overriddenIds.length)
            actions: [
                Kirigami.Action {
                    text: i18n("Reset All…")
                    icon.name: "edit-reset"
                    onTriggered: page.confirmReset("")
                }
            ]
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.SearchField {
                id: search
                Layout.fillWidth: true
            }

            QQC2.CheckBox {
                text: i18n("Show enabled only")
                checked: page.showEnabledOnly
                onToggled: page.showEnabledOnly = checked
            }
        }

        Repeater {
            model: page.providerIds().filter(function (id) {
                if (page.showEnabledOnly && page.enabledList().indexOf(id) < 0)
                    return false
                var q = search.text.toLowerCase()
                if (q.length === 0)
                    return true
                return id.indexOf(q) >= 0 || page.providerName(id).toLowerCase().indexOf(q) >= 0
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

                ProviderIconImage {
                    iconFile: Catalog.meta(row.modelData).icon
                    displayContext: ProviderIconImage.ContrastingContext
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small

                    Rectangle {
                        anchors.fill: parent
                        z: -1
                        radius: 4
                        color: Catalog.logoBackgroundColor(row.modelData)
                    }
                }

                QQC2.Label {
                    text: page.providerName(row.modelData)
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                QQC2.Label {
                    text: row.modelData
                    opacity: 0.5
                    font: Kirigami.Theme.smallFont
                }

                QQC2.ComboBox {
                    id: sourceCombo
                    enabled: page.enabledList().indexOf(row.modelData) >= 0
                    model: page.sourceModel(row.modelData)
                    Accessible.name: i18n("Data source for %1", page.providerName(row.modelData))
                    currentIndex: {
                        page.cfg_providerSources
                        return Math.max(0, ProviderSources.SOURCES.indexOf(
                            ProviderSources.sourceFor(page.cfg_providerSources, row.modelData)))
                    }
                    onActivated: page.cfg_providerSources = ProviderSources.withSource(
                        page.cfg_providerSources, row.modelData,
                        ProviderSources.SOURCES[currentIndex])
                }

                QQC2.ToolButton {
                    enabled: page.enabledList().indexOf(row.modelData) >= 0
                    icon.name: "settings-configure"
                    highlighted: ProviderOverrides.hasOverride(page.cfg_providerOverrides, row.modelData)
                    Accessible.name: i18n("Provider settings for %1", page.providerName(row.modelData))
                    QQC2.ToolTip.text: i18n("Per-provider panel settings for %1", page.providerName(row.modelData))
                    QQC2.ToolTip.visible: hovered
                    onClicked: settingsDialog.openFor(row.modelData, page.providerName(row.modelData))
                }

                // A disabled button gets no hover events, so the wrapper's
                // HoverHandler drives the tooltip in both states.
                Item {
                    implicitWidth: globeButton.implicitWidth
                    implicitHeight: globeButton.implicitHeight

                    HoverHandler { id: globeHover }

                    QQC2.ToolButton {
                        id: globeButton
                        anchors.fill: parent
                        // Works for disabled providers too, whose gear is greyed out.
                        enabled: page.overriddenIds.indexOf(row.modelData) >= 0
                        icon.name: "globe"
                        Accessible.name: i18n("Reset %1 to global defaults", page.providerName(row.modelData))
                        QQC2.ToolTip.text: enabled
                            ? i18n("Reset %1 to global defaults", page.providerName(row.modelData))
                            : i18n("%1 has no custom panel settings to reset", page.providerName(row.modelData))
                        QQC2.ToolTip.visible: globeHover.hovered
                        onClicked: page.confirmReset(row.modelData)
                    }
                }
            }
        }

        // Searching while filtered hides disabled matches; point that out.
        QQC2.Label {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            visible: page.showEnabledOnly && search.text.length > 0
            text: i18n("Can't find what you're looking for? Only enabled providers are shown. <a href=\"#\">Show all providers</a>")
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.7
            font: Kirigami.Theme.smallFont
            onLinkActivated: page.showEnabledOnly = false

            HoverHandler {
                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }
    }

    ProviderOverridesDialog {
        id: settingsDialog
        // Center on the window rather than on the scrolled provider list.
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(page.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 36)
        overrides: page.cfg_providerOverrides
        globals: ({
            panelDisplayMode: page.cfg_panelDisplayMode,
            showPercentInPanel: page.cfg_showPercentInPanel,
            panelPercentSource: page.cfg_panelPercentSource,
            percentStyle: page.cfg_percentStyle,
            showResetCountdown: page.cfg_showResetCountdown,
            hideCritters: page.cfg_hideCritters,
            middleClickAction: page.cfg_middleClickAction,
            doubleClickAction: page.cfg_doubleClickAction,
            launchCommand: page.cfg_launchCommand
        })
        // Staged like every other edit; the page Apply/OK commits it.
        onStaged: function (overrides) { page.cfg_providerOverrides = overrides }
    }

    QQC2.Dialog {
        id: resetDialog
        // Provider to reset, or "" for every provider.
        property string providerId: ""
        readonly property bool resetsAll: providerId === ""
        modal: true
        // Center on the window rather than on the scrolled provider list.
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(page.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 24)
        title: resetsAll
            ? i18n("Reset all provider overrides?")
            : i18n("Reset %1 to global defaults?", page.providerName(providerId))

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                Layout.fillWidth: true
                text: resetDialog.resetsAll
                    ? i18np("This provider will go back to using the General settings:",
                            "These providers will go back to using the General settings:",
                            page.overriddenIds.length)
                    : i18n("%1's custom panel settings will be removed and it will follow the General settings again.",
                           page.providerName(resetDialog.providerId))
                wrapMode: Text.WordWrap
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                visible: resetDialog.resetsAll
                text: page.overriddenProviderLines()
                wrapMode: Text.WordWrap
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: i18n("Nothing changes until you click Apply or OK.")
                wrapMode: Text.WordWrap
                opacity: 0.7
                font: Kirigami.Theme.smallFont
            }
        }

        footer: QQC2.DialogButtonBox {
            QQC2.Button {
                text: resetDialog.resetsAll ? i18n("Reset All") : i18n("Reset")
                icon.name: "edit-reset"
                QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.AcceptRole
                onClicked: page.applyConfirmedReset()
            }
            QQC2.Button {
                id: resetCancel
                text: i18n("Cancel")
                icon.name: "dialog-cancel"
                QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.RejectRole
                onClicked: resetDialog.close()
            }
        }

        // Default to the safe choice.
        onOpened: resetCancel.forceActiveFocus()
    }
}
