import QtQuick
import qs.desktop.modules.common
import qs.desktop.modules.dock

// Component-level glass that intentionally does not sample the desktop.
// That makes its highlight and pigment treatment stable for still images,
// video wallpapers, and third-party wallpaper renderers alike.
Item {
    id: root

    property real cornerRadius: 26
    property real strength: 1.0
    property string appearanceMode: IconAppearanceService.mode
    // "topLeft" gives the familiar bright top-left / dark bottom-right lens;
    // widgets can select "topRight" when their visual needs the reverse.
    property string lightDirection: "topLeft"
    // Treat wallpaper brightness as the material's light source. A bright
    // desktop needs a darker lens for contrast, while a dark desktop receives
    // a pale one. This is continuous rather than a light/dark theme switch.
    readonly property real wallpaperLuminance: Math.max(0.0, Math.min(1.0,
        ((WallpaperPaletteService.primary.r * 0.2126
            + WallpaperPaletteService.primary.g * 0.7152
            + WallpaperPaletteService.primary.b * 0.0722) * 0.64)
        + ((WallpaperPaletteService.secondary.r * 0.2126
            + WallpaperPaletteService.secondary.g * 0.7152
            + WallpaperPaletteService.secondary.b * 0.0722) * 0.36)))
    readonly property real darkMaterialAmount: wallpaperLuminance
    readonly property color adaptiveBase: Qt.rgba(
        0.94 * (1.0 - darkMaterialAmount) + 0.025 * darkMaterialAmount,
        0.96 * (1.0 - darkMaterialAmount) + 0.040 * darkMaterialAmount,
        1.00 * (1.0 - darkMaterialAmount) + 0.075 * darkMaterialAmount,
        (0.14 + darkMaterialAmount * 0.25) * strength)
    // Lifted wallpaper pigments for the tiny coloured reflections.  The
    // values stay close to white so a widget reads as glass, not as a colour
    // card.
    readonly property color pigmentPrimary: appearanceMode === "tint"
        ? IconAppearanceService.tintColor : WallpaperPaletteService.primary
    readonly property color pigmentSecondary: appearanceMode === "tint"
        ? IconAppearanceService.tintColor : WallpaperPaletteService.secondary
    readonly property color primarySheen: Qt.rgba(
        pigmentPrimary.r * 0.42 + 0.58,
        pigmentPrimary.g * 0.42 + 0.58,
        pigmentPrimary.b * 0.42 + 0.58, 1.0)
    readonly property color secondarySheen: Qt.rgba(
        pigmentSecondary.r * 0.42 + 0.58,
        pigmentSecondary.g * 0.42 + 0.58,
        pigmentSecondary.b * 0.42 + 0.58, 1.0)

    LiquidGlassSurface {
        anchors.fill: parent
        compositorManaged: false
        radius: root.cornerRadius
        material: "regular"
        materialDepth: 0.35
        // Desktop widgets self-render (compositorManaged: false) and cannot
        // use the KWin backdrop pass, so their body must not be gated by the
        // Dock blur slider — that setting only makes sense for surfaces the
        // compositor actually blurs.
        blurStrength: 1.0
        surfaceOpacity: 0.92 * root.strength
        baseColor: root.adaptiveBase
        ambientPrimary: root.pigmentPrimary
        ambientSecondary: root.pigmentSecondary
        // Tint is a subtle ambient reflection, not an opaque colour card.
        // Keep it markedly lighter than full-colour wallpaper pigment.
        ambientStrength: root.appearanceMode === "grayscale" ? 0.0
            : (root.appearanceMode === "tint" ? 0.18 : 0.42) * root.strength
        ambientTransitionDuration: 2800
        adaptiveDarkScrim: root.wallpaperLuminance > 0.54
    }

    // This horizontal component combines with LiquidGlassSurface's existing
    // top-white/bottom-black finish, producing a *static* diagonal light
    // field: top-left bright and bottom-right deep (or the reverse).
    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: root.lightDirection === "topLeft"
                    ? Qt.rgba(0.88, 0.95, 1.0, 0.085 * root.strength)
                    : Qt.rgba(0.005, 0.012, 0.030, 0.080 * root.strength)
            }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
            GradientStop {
                position: 1.0
                color: root.lightDirection === "topLeft"
                    ? Qt.rgba(0.005, 0.012, 0.030, 0.080 * root.strength)
                    : Qt.rgba(0.88, 0.95, 1.0, 0.085 * root.strength)
            }
        }
    }

    // A quiet colour wash makes the glass pick up its surroundings even
    // without backdrop sampling. It fades before the centre so text keeps a
    // neutral, legible resting area.
    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(root.primarySheen.r, root.primarySheen.g, root.primarySheen.b, (0.050 + (1.0 - root.wallpaperLuminance) * 0.065) * root.strength) }
            GradientStop { position: 0.48; color: Qt.rgba(1, 1, 1, 0.014 * root.strength) }
            GradientStop { position: 1.0; color: Qt.rgba(root.secondarySheen.r, root.secondarySheen.g, root.secondarySheen.b, (0.040 + (1.0 - root.wallpaperLuminance) * 0.055) * root.strength) }
        }
    }

    // Edge glints converge toward each edge's midpoint and fade before the
    // corners. They follow the adaptive base: a bright desktop yields a dark
    // material, where a white glint would vanish, so the glint flips dark;
    // a dark desktop keeps the familiar white glint.
    readonly property real _glintDarkMix: darkMaterialAmount
    readonly property color _glintCore: Qt.rgba(
        1.0 - 0.96 * _glintDarkMix,
        1.0 - 0.95 * _glintDarkMix,
        1.0 - 0.93 * _glintDarkMix, 1.0)
    readonly property color _glintPrimary: _mixGlint(root.primarySheen)
    readonly property color _glintSecondary: _mixGlint(root.secondarySheen)

    function _mixGlint(sheen) {
        const m = _glintDarkMix * 0.9
        return Qt.rgba(
            sheen.r * (1.0 - m) + 0.03 * m,
            sheen.g * (1.0 - m) + 0.04 * m,
            sheen.b * (1.0 - m) + 0.06 * m, 1.0)
    }

    // Top edge: the strongest glint; the coloured part stays a sub-pixel
    // accent while the centre keeps a neutral glass glint.
    Rectangle {
        x: Math.min(parent.width / 2, root.cornerRadius + 5)
        y: 1
        width: Math.max(0, parent.width - x * 2)
        height: 1.1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(root._glintPrimary.r, root._glintPrimary.g, root._glintPrimary.b, 0.0) }
            GradientStop { position: 0.18; color: Qt.rgba(root._glintPrimary.r, root._glintPrimary.g, root._glintPrimary.b, 0.34 * root.strength) }
            GradientStop { position: 0.50; color: Qt.rgba(root._glintCore.r, root._glintCore.g, root._glintCore.b, 0.48 * root.strength) }
            GradientStop { position: 0.82; color: Qt.rgba(root._glintSecondary.r, root._glintSecondary.g, root._glintSecondary.b, 0.30 * root.strength) }
            GradientStop { position: 1.0; color: Qt.rgba(root._glintSecondary.r, root._glintSecondary.g, root._glintSecondary.b, 0.0) }
        }
    }

    // Bottom edge: the same convergence, dimmer so it reads as light
    // reflected up from below rather than a second key light.
    Rectangle {
        x: Math.min(parent.width / 2, root.cornerRadius + 5)
        y: parent.height - height - 1
        width: Math.max(0, parent.width - x * 2)
        height: 1.1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(root._glintSecondary.r, root._glintSecondary.g, root._glintSecondary.b, 0.0) }
            GradientStop { position: 0.18; color: Qt.rgba(root._glintSecondary.r, root._glintSecondary.g, root._glintSecondary.b, 0.21 * root.strength) }
            GradientStop { position: 0.50; color: Qt.rgba(root._glintCore.r, root._glintCore.g, root._glintCore.b, 0.30 * root.strength) }
            GradientStop { position: 0.82; color: Qt.rgba(root._glintPrimary.r, root._glintPrimary.g, root._glintPrimary.b, 0.19 * root.strength) }
            GradientStop { position: 1.0; color: Qt.rgba(root._glintPrimary.r, root._glintPrimary.g, root._glintPrimary.b, 0.0) }
        }
    }

    // Side edges: shorter and fainter still, converging toward the vertical
    // midpoint. The wider corner inset keeps them clear of the corner arcs.
    Rectangle {
        x: 1
        y: Math.min(parent.height / 2, root.cornerRadius + 12)
        width: 1.1
        height: Math.max(0, parent.height - y * 2)
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(root._glintPrimary.r, root._glintPrimary.g, root._glintPrimary.b, 0.0) }
            GradientStop { position: 0.22; color: Qt.rgba(root._glintPrimary.r, root._glintPrimary.g, root._glintPrimary.b, 0.13 * root.strength) }
            GradientStop { position: 0.50; color: Qt.rgba(root._glintCore.r, root._glintCore.g, root._glintCore.b, 0.21 * root.strength) }
            GradientStop { position: 0.78; color: Qt.rgba(root._glintPrimary.r, root._glintPrimary.g, root._glintPrimary.b, 0.13 * root.strength) }
            GradientStop { position: 1.0; color: Qt.rgba(root._glintPrimary.r, root._glintPrimary.g, root._glintPrimary.b, 0.0) }
        }
    }
    Rectangle {
        x: parent.width - width - 1
        y: Math.min(parent.height / 2, root.cornerRadius + 12)
        width: 1.1
        height: Math.max(0, parent.height - y * 2)
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(root._glintSecondary.r, root._glintSecondary.g, root._glintSecondary.b, 0.0) }
            GradientStop { position: 0.22; color: Qt.rgba(root._glintSecondary.r, root._glintSecondary.g, root._glintSecondary.b, 0.13 * root.strength) }
            GradientStop { position: 0.50; color: Qt.rgba(root._glintCore.r, root._glintCore.g, root._glintCore.b, 0.21 * root.strength) }
            GradientStop { position: 0.78; color: Qt.rgba(root._glintSecondary.r, root._glintSecondary.g, root._glintSecondary.b, 0.13 * root.strength) }
            GradientStop { position: 1.0; color: Qt.rgba(root._glintSecondary.r, root._glintSecondary.g, root._glintSecondary.b, 0.0) }
        }
    }
}
