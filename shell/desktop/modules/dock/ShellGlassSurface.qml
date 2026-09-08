import QtQuick
import qs.desktop.modules.common

// Canonical compositor-backed material for shell chrome.
//
// KWin owns backdrop sampling, blur, refraction and the optical rim. This
// component owns the one QML pigment/ambient treatment used by Dock,
// QuickSearch, AppLauncher and Control Center. Callers may choose semantic
// material depth, geometry and opacity, but must not rebuild the material.
LiquidGlassSurface {
    baseColor: ThemeService.backgroundColor
    blurStrength: AppearanceConfigService.globalBlurStrength
    liquidStrength: AppearanceConfigService.globalLiquidStrength
    ambientPrimary: WallpaperPaletteService.primary
    ambientSecondary: WallpaperPaletteService.secondary
    ambientStrength: 0.35 * AppearanceTokens.glass.ambientMultiplier
    material: "regular"
    compositorManaged: true
    border.width: 0
}
