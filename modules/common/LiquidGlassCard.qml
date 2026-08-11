import QtQuick
import QtQuick.Effects

// Per-card liquid glass following the Kyant0/AndroidLiquidGlass architecture:
// each card independently samples the shared wallpaper texture at its own screen
// position and applies its own blur + refraction + SDF mask + highlight.
//
// The card is a Rectangle (so radius/color/border work naturally for callers
// used to Rectangle cards). The glass material is a ShaderEffect layered on top
// of the (transparent) Rectangle body; the optional border draws above the
// shader. Gaps between sibling cards are transparent and show the real desktop
// wallpaper - the "hollow" look iOS uses for its control center.
//
// Usage:
//   LiquidGlassCard {
//       wallpaperTexture: provider.texture
//       screenSize: provider.screenSize
//       cardScreenPos: Qt.point(card.mapToItem(windowContent, 0, 0).x + window.x, ...)
//       radius: 19
//       refractionStrength: 0.6
//       border.width: 1; border.color: Qt.rgba(1,1,1,0.2)
//       // children: Text, icons, controls...
//   }
Rectangle {
    id: root

    color: "transparent"

    // ── Inputs ──
    // Shared wallpaper texture (a ShaderEffectSource from WallpaperTextureProvider).
    property var wallpaperTexture: null
    // Full screen size in logical pixels (provider.screenSize).
    property size screenSize: Qt.size(1920, 1080)
    // Card's top-left position in screen coordinates (logical pixels).
    // Callers compute this from mapToItem(windowContent, 0, 0) + window screen pos.
    property point cardScreenPos: Qt.point(0, 0)

    // ── Material parameters ──
    property real refractionStrength: 0.55   // 0..1 lens bend
    property real dispersion: 0.35           // 0..1 chromatic fringe
    property real innerShadow: 0.15          // 0..1 inset darkening
    property real highlightFalloff: 3.0      // specular exponent
    property real highlightIntensity: 0.45   // 0..1 specular brightness
    property color tintColor: Qt.rgba(1, 1, 1, 0.10)
    property color highlightColor: Qt.rgba(1, 1, 1, 0.6)
    // Light comes from the top (screen-space), matching natural UI lighting.
    property vector2d lightDir: Qt.vector2d(0.0, -1.0)

    // Whether the wallpaper texture is ready to sample.
    readonly property bool textureReady: wallpaperTexture !== null

    // ── Layer 1: blur the wallpaper texture with MultiEffect ──
    // Capture the screen region this card occupies from the shared wallpaper
    // texture, then blur it. The blurred result feeds the refraction shader so
    // the sampled background is already soft (like real frosted glass).
    ShaderEffectSource {
        id: rawBackdrop
        visible: false
        live: true
        sourceItem: root.wallpaperTexture
        // Capture only the screen region this card occupies, so the blur is
        // local and cheap. Coordinates are in the wallpaper texture's space
        // (which spans the full screen).
        sourceRect: Qt.rect(root.cardScreenPos.x, root.cardScreenPos.y, root.width, root.height)
        width: root.width
        height: root.height
        textureSize: Qt.size(Math.max(1, Math.ceil(root.width)), Math.max(1, Math.ceil(root.height)))
    }

    MultiEffect {
        id: blurredBackdrop
        visible: false
        source: rawBackdrop
        anchors.fill: parent
        blurEnabled: true
        blur: 0.8
        blurMax: 32
        blurMultiplier: 1.0
    }

    // ── Layer 2: the glass material shader ──
    // Samples the blurred wallpaper, applies refraction + SDF mask + tint +
    // highlight + inner shadow. Outputs the glass body with AA rounded corners.
    ShaderEffect {
        id: glassShader
        anchors.fill: parent

        // sampler2D (binding 1) - the blurred wallpaper.
        property var u_wallpaper: blurredBackdrop

        // uniform block (binding 0) - MUST match glass_card.frag order.
        property point u_cardScreenPos: root.cardScreenPos
        property size u_cardSize: Qt.size(root.width, root.height)
        property size u_screenSize: root.screenSize
        property real u_cornerRadius: root.radius
        property real u_refractionStrength: root.refractionStrength
        property real u_dispersion: root.dispersion
        property real u_innerShadow: root.innerShadow
        property real u_highlightFalloff: root.highlightFalloff
        property real u_highlightIntensity: root.highlightIntensity
        property color u_tintColor: root.tintColor
        property color u_highlightColor: root.highlightColor
        property vector2d u_lightDir: root.lightDir

        vertexShader: Qt.resolvedUrl("../../shaders/glass_card.vert.qsb")
        fragmentShader: Qt.resolvedUrl("../../shaders/glass_card.frag.qsb")

        // Hide the shader until the wallpaper texture is loaded to avoid
        // sampling a null sampler.
        visible: root.textureReady
    }

    // ── Layer 3: fallback when no texture (subtle neutral glass) ──
    // Keeps the card readable if the wallpaper URL hasn't resolved yet.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: !root.textureReady
        color: Qt.rgba(0.08, 0.09, 0.12, 0.35)
        border.width: root.border.width
        border.color: root.border.color
    }
}
