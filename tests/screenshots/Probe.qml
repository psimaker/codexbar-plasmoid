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

    onTriggered: {
        var win = target.Window.window
        if (!target.visible || !win || !win.visible || subject.width <= 0 || subject.height <= 0)
            return
        var result = {
            kind: kind, time: Date.now(), scale: target.Screen.devicePixelRatio,
            window: { width: win.width, height: win.height },
            rect: rect(subject), texts: [], clipped: [], actions: {},
            background: Kirigami.Theme.backgroundColor.toString(),
            font: Kirigami.Theme.defaultFont.family,
            pointSize: Kirigami.Theme.defaultFont.pointSize
        }
        if (kind === "popup" || kind === "panel") {
            var root = target.plasmoidRoot
            result.configMode = root.configMode
            result.tab = root.currentTab
            result.providers = root.enabledProviders
            result.data = root.enabledProviders.map(function (id) {
                var d = root.usageData[id]
                return { id: id, ready: !!(d && d.entry && d.entry.usage && !d.loading && !d.error),
                         costReady: !!(d && d.cost && !d.costLoading) }
            })
            if (kind === "panel") {
                result.icons = target.iconModel
                result.mode = target.displayMode
                result.vertical = target.vertical
            } else {
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
            else
                result.paths = [target.cfg_cliPath, target.cfg_cliEnvironmentFile, target.cfg_claudeAdapterPath]
            inspect(win.contentItem, result)
        }
        var message = JSON.stringify(result)
        if (message !== previous) {
            console.log("SCREENSHOT_STATE " + message)
            previous = message
        }
    }
}
