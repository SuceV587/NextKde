import QtQuick

// Text with the glass readability outline baked in. Root type is Text, so
// every property (anchors, font, elide, nested MouseArea, Text.* enums)
// passes through natively — swap `Text {` for `GlassText {` on white/light
// text that sits on translucent glass or directly on the wallpaper.
// The outline follows the ink luminance, protecting both light text on bright
// content and dark text on dark content. Callers can still override styleColor.
Text {
    id: root

    readonly property real inkLuminance: color.r * 0.2126
        + color.g * 0.7152 + color.b * 0.0722
    renderType: Text.NativeRendering
    style: (styleColor.a > 0.01) ? Text.Outline : Text.Normal
    // Vibrancy-like protection: light ink receives a dark edge to protect against
    // bright backgrounds. On dark ink (light mode), white outlines produce jagged
    // halo artifacts around text glyphs, so keep the default edge transparent.
    // Callers can still override styleColor if an explicit border is desired.
    styleColor: inkLuminance >= 0.55
        ? Qt.rgba(0.03, 0.045, 0.07, 0.36)
        : "transparent"
}
