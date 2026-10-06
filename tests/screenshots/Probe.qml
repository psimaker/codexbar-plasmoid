import QtQuick
import QtQuick.Window
import org.kde.kirigami as Kirigami

// Observer installed ONLY in the renderer's disposable package copy. No
// drawing, synthetic UI or state changes: clicks still go through X11.
Timer {
    required property var target
    required property var subject
    required property string kind
    property var viewport: null
    property var delegates: null
    property string previous: ""
    interval: 250
    running: true
    repeat: true

    function rect(item) {
        var p = item.mapToItem(null, 0, 0)
        return { x: p.x, y: p.y, width: item.width, height: item.height }
    }

    function clipped(item) {
        for (var p = item.parent; p; p = p.parent) {
            if (!p.clip)
                continue
            var r = item.mapToItem(p, 0, 0)
            if (r.x < -1 || r.y < -1 || r.x + item.width > p.width + 1
                    || r.y + item.height > p.height + 1)
                return true
        }
        return false
    }

    function inspect(item, result) {
        if (!item || !item.visible || item.opacity === 0)
            return
        if (item.width > 0 && item.height > 0) {
            var r = rect(item)
            var center = [r.x + r.width / 2, r.y + r.height / 2]
            if (item.tabId !== undefined)
                result.actions["tab:" + item.tabId] = center
            if (item.label !== undefined && item.activated !== undefined)
                result.actions["menu:" + item.label] = center
            if (typeof item.text === "string" && item.text !== "") {
                result.texts.push(item.text)
                if (result.textRects !== undefined)
                    result.textRects.push(r)
                if (item.clicked !== undefined && !clipped(item))
                    result.buttons[item.text] = item.enabled
                if (!clipped(item) && result.actions["text:" + item.text] === undefined)
                    result.actions["text:" + item.text] = center
                if (item.truncated === true || clipped(item))
                    result.clipped.push(item.text)
            }
        }
        var children = item.children || []
        for (var i = 0; i < children.length; i++)
            inspect(children[i], result)
    }

    function toolbarBounds(item, result) {
        if (!item || !item.visible || item.opacity === 0)
            return
        if (item.clicked !== undefined && ["FormFactors", "Location", "Configure Containment"].indexOf(item.text) >= 0)
            result.push(rect(item))
        var children = item.children || []
        for (var i = 0; i < children.length; i++)
            toolbarBounds(children[i], result)
    }

    function panelItems() {
        var items = []
        for (var i = 0; i < delegates.count; i++) {
            var item = delegates.itemAt(i)
            if (!item || !item.visible || item.opacity === 0)
                continue
            var entry = { id: item.providerId, rect: rect(item), clipped: clipped(item) }
            // The first visible child is the native logo or CritterIcon.
            for (var j = 0; j < item.children.length; j++) {
                var child = item.children[j]
                if (!child.visible || child.width <= 0 || child.height <= 0)
                    continue
                entry.icon = rect(child)
                if (target.showsLogosFor(item.providerId))
                    entry.color = child.children[0].color.toString()
                break
            }
            // inspect() collects the actual label bounds, not the whole row.
            var labels = { texts: [], textRects: [], actions: {}, buttons: {}, clipped: [] }
            inspect(item, labels)
            entry.texts = labels.texts
            entry.textRects = labels.textRects
            entry.clipped = entry.clipped || labels.clipped.length > 0
            items.push(entry)
        }
        return items
    }

    onTriggered: {
        var win = target.Window.window
        if (!target.visible || !win || !win.visible || subject.width <= 0 || subject.height <= 0)
            return
        var result = {
            kind: kind, time: Date.now(), scale: target.Screen.devicePixelRatio,
            window: { width: win.width, height: win.height },
            rect: rect(subject), texts: [], clipped: [], actions: {}, buttons: {},
            background: Kirigami.Theme.backgroundColor.toString(),
            font: Kirigami.Theme.defaultFont.family,
            pointSize: Kirigami.Theme.defaultFont.pointSize
        }
        if (kind === "popup" || kind === "panel" || kind === "setup") {
            var root = target.plasmoidRoot
            result.configMode = root.configMode
            result.cliState = root.cliState.code
            result.installRunning = root.cliInstallRunning
            result.installExitCode = root.cliInstallExitCode
            result.tab = root.currentTab
            result.providers = root.enabledProviders
            result.data = root.enabledProviders.map(function (id) {
                var d = root.usageData[id]
                return { id: id, ready: !!(d && d.entry && d.entry.usage && !d.loading && !d.error),
                         costReady: !!(d && d.cost && !d.costLoading) }
            })
            if (kind === "panel") {
                result.icons = target.iconModel
                result.mergedProviders = target.mergedProviders
                result.items = panelItems()
                result.toolbar = []
                toolbarBounds(win.contentItem, result.toolbar)
                result.mode = target.displayMode
                result.vertical = target.vertical
                result.iconSide = target.iconSide
                result.percentVisible = target.showPercentFor(target.iconModel[0])
            } else if (kind === "popup") {
                result.overflow = viewport.contentHeight > viewport.height + 1
            }
            inspect(subject, result)
        } else {
            // Include the real configuration sidebar and footer in the shot.
            result.rect = { x: 0, y: 0, width: win.width, height: win.height }
            result.configMode = kind === "providers" ? target.configList !== null : true
            result.enabledOnly = kind === "providers" ? target.showEnabledOnly : false
            if (kind === "providers")
                result.providers = target.enabledList()
            else {
                result.paths = [target.cfg_cliPath, target.cfg_cliEnvironmentFile, target.cfg_claudeAdapterPath]
                result.notifications = [target.cfg_notifyQuota, target.cfg_notifyStatus, target.cfg_notifyThreshold]
            }
            inspect(win.contentItem, result)
        }
        var message = JSON.stringify(result)
        if (message !== previous) {
            console.log("SCREENSHOT_STATE " + message)
            previous = message
        }
    }
}
