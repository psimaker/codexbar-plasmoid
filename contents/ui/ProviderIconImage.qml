import QtQuick
import org.kde.ksvg as KSvg

// Provider SVGs use Plasma's ColorScheme-Text convention for themeable
// monochrome artwork. KSvg resolves that color once through Plasma's SVG
// cache while leaving intentional provider accent colors unchanged.
Item {
    id: iconRoot

    property string iconFile: ""

    KSvg.SvgItem {
        anchors.fill: parent
        svg: KSvg.Svg {
            imagePath: iconRoot.iconFile !== ""
                       ? Qt.resolvedUrl("../icons/" + iconRoot.iconFile) : ""
        }
    }
}
