import QtQuick
import org.kde.ksvg as KSvg

// Provider SVGs use Plasma's ColorScheme-Text convention for themeable
// monochrome artwork. KSvg resolves that color once through Plasma's SVG
// cache while leaving intentional provider accent colors unchanged.
Item {
    id: iconRoot

    enum DisplayContext {
        NormalContext,
        SelectedContext,
        ContrastingContext
    }

    property string iconFile: ""
    property int displayContext: ProviderIconImage.NormalContext

    KSvg.SvgItem {
        anchors.fill: parent
        svg: KSvg.Svg {
            imagePath: iconRoot.iconFile !== ""
                       ? Qt.resolvedUrl("../icons/" + iconRoot.iconFile) : ""
            status: iconRoot.displayContext === ProviderIconImage.SelectedContext
                    ? KSvg.Svg.Selected : KSvg.Svg.Normal
            colorSet: iconRoot.displayContext === ProviderIconImage.ContrastingContext
                      ? KSvg.Svg.Complementary : KSvg.Svg.Window
        }
    }
}
