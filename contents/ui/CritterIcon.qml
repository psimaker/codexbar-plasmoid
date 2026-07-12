import QtQuick
import org.kde.kirigami as Kirigami

// Faithful re-implementation of CodexBar's IconRenderer: two stacked meter
// bars on an 18×18pt (36px) grid, fill = remaining percent, with the
// provider "critter" face cut out of the top bar (Codex: eyes, Claude:
// asterisk eyes on a blockier bar).
Canvas {
    id: canvas

    property string providerId: ""
    property real remainingPrimary: -1    // 0..100, -1 = unknown
    property real remainingSecondary: -1
    property bool stale: false
    property bool hideCritters: false
    property color baseColor: Kirigami.Theme.textColor

    onRemainingPrimaryChanged: requestPaint()
    onRemainingSecondaryChanged: requestPaint()
    onStaleChanged: requestPaint()
    onHideCrittersChanged: requestPaint()
    onBaseColorChanged: requestPaint()
    onProviderIdChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function rgba(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")"
    }

    function roundedRectPath(ctx, x, y, w, h, r) {
        r = Math.min(r, h / 2, w / 2)
        ctx.beginPath()
        ctx.moveTo(x + r, y)
        ctx.lineTo(x + w - r, y)
        ctx.arcTo(x + w, y, x + w, y + r, r)
        ctx.lineTo(x + w, y + h - r)
        ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
        ctx.lineTo(x + r, y + h)
        ctx.arcTo(x, y + h, x, y + h - r, r)
        ctx.lineTo(x, y + r)
        ctx.arcTo(x, y, x + r, y, r)
        ctx.closePath()
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)

        var side = Math.min(width, height)
        var u = side / 36
        var ox = (width - side) / 2
        var oy = (height - side) / 2

        var trackFillAlpha = stale ? 0.18 : 0.28
        var trackStrokeAlpha = stale ? 0.28 : 0.44
        var fillAlpha = stale ? 0.55 : 1.0

        var isClaude = providerId === "claude"
        var critter = !hideCritters && (providerId === "codex" || providerId === "claude"
                                        || providerId === "openai" || providerId === "azure-openai")

        function drawBar(bx, by, bw, bh, radius, remaining) {
            var x = ox + bx * u, y = oy + by * u, w = bw * u, h = bh * u, r = radius * u

            // track
            ctx.fillStyle = rgba(baseColor, trackFillAlpha)
            roundedRectPath(ctx, x, y, w, h, r)
            ctx.fill()

            // outline (1pt = 2 grid px), inset so it stays crisp
            var inset = u
            ctx.strokeStyle = rgba(baseColor, trackStrokeAlpha)
            ctx.lineWidth = 2 * u
            roundedRectPath(ctx, x + inset, y + inset, w - inset * 2, h - inset * 2,
                            Math.max(0, r - inset))
            ctx.stroke()

            // left-to-right fill clipped to the capsule
            if (remaining >= 0) {
                var frac = Math.max(0, Math.min(1, remaining / 100))
                if (frac > 0) {
                    ctx.save()
                    roundedRectPath(ctx, x, y, w, h, r)
                    ctx.clip()
                    ctx.fillStyle = rgba(baseColor, fillAlpha)
                    ctx.fillRect(x, y, w * frac, h)
                    ctx.restore()
                }
            }
        }

        // geometry from IconRenderer: top bar 30×12px at y5, bottom bar 30×8px at y23
        var topRadius = isClaude ? 2 : 6
        drawBar(3, 5, 30, 12, topRadius, remainingPrimary)
        drawBar(3, 23, 30, 8, 4, remainingSecondary)

        // critter face cut out of the top bar
        if (critter) {
            var cy = oy + (5 + 6) * u        // vertical center of top bar
            var cxL = ox + 18 * u - 7 * u
            var cxR = ox + 18 * u + 7 * u
            ctx.globalCompositeOperation = "destination-out"
            if (isClaude) {
                // asterisk eyes (Claude starburst)
                ctx.lineWidth = 1.7 * u
                ctx.lineCap = "round"
                var len = 2.6 * u
                var centers = [cxL, cxR]
                for (var i = 0; i < centers.length; i++) {
                    var cx = centers[i]
                    for (var k = 0; k < 3; k++) {
                        var ang = (Math.PI / 3) * k + Math.PI / 6
                        ctx.beginPath()
                        ctx.moveTo(cx - Math.cos(ang) * len, cy - Math.sin(ang) * len)
                        ctx.lineTo(cx + Math.cos(ang) * len, cy + Math.sin(ang) * len)
                        ctx.stroke()
                    }
                }
            } else {
                // square eyes (Codex)
                var e = 4 * u
                ctx.fillRect(cxL - e / 2, cy - e / 2, e, e)
                ctx.fillRect(cxR - e / 2, cy - e / 2, e, e)
            }
            ctx.globalCompositeOperation = "source-over"
        }
    }
}
