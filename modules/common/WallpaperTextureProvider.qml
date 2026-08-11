import QtQuick
import qs.modules.dock

// Provides the wallpaper as a GPU texture that LiquidGlassCard instances can
// sample at their own screen position. This mirrors the Kyant0/AndroidLiquidGlass
// architecture: every glass element independently samples a shared backdrop
// texture instead of relying on a single compositor-blurred region.
//
// Plasma renders the wallpaper with Image.PreserveAspectCrop (FillMode=2, the
// default for org.kde.image and not overridden in the user's appletsrc). We must
// replicate that exact transform here so the region sampled behind a card matches
// what the user actually sees on the desktop.
Item {
    id: root

    // The screen this provider serves. Callers bind this to their window's
    // `screen` (a Quickshell ShellScreen). Falls back to Quickshell.screens[1]
    // to match shell.qml's primaryScreen selection.
    property var screen: Quickshell.screens[1] ?? Quickshell.screens[0] ?? null

    readonly property real dpr: screen ? screen.devicePixelRatio : 1.0
    readonly property int screenW: screen ? screen.width : 1920
    readonly property int screenH: screen ? screen.height : 1080
    readonly property int screenX: screen ? screen.x : 0
    readonly property int screenY: screen ? screen.y : 0

    // The GPU texture consumers bind to. This is a ShaderEffectSource wrapping
    // the wallpaper Image, sized to the full screen (logical pixels).
    readonly property var texture: wallpaperSource
    readonly property size screenSize: Qt.size(screenW, screenH)
    readonly property point screenOrigin: Qt.point(screenX, screenY)
    readonly property bool ready: wallpaperImage.status === Image.Ready

    // Hidden wallpaper image, sized to the full screen. PreserveAspectCrop
    // matches Plasma's default FillMode so sampled regions align with the real
    // desktop. The Image is never visible; ShaderEffectSource captures it.
    Image {
        id: wallpaperImage
        visible: false
        // WallpaperPaletteService.wallpaperUrl may be a bare path (Plasma stores
        // it without a scheme for local files). QML Image requires a URL, so
        // normalize here. Remote URLs (http/https) pass through unchanged.
        source: {
            var url = WallpaperPaletteService.wallpaperUrl.toString()
            if (url.length === 0)
                return ""
            if (url.indexOf("://") !== -1)
                return url
            return "file://" + url
        }
        fillMode: Image.PreserveAspectCrop
        // Match the screen in logical pixels. sourceSize at DPR keeps the
        // decoded texture sharp on HiDPI without over-allocating.
        sourceSize: Qt.size(Math.ceil(screenW * dpr), Math.ceil(screenH * dpr))
        width: screenW
        height: screenH
        x: 0
        y: 0
        asynchronous: true
        cache: true
        smooth: true
    }

    ShaderEffectSource {
        id: wallpaperSource
        sourceItem: wallpaperImage
        // hideSource keeps the Image off-screen while still rendering it into
        // the texture. live:true updates the texture when the Image reloads
        // (e.g. wallpaper change).
        hideSource: true
        live: true
        visible: false
        // Texture resolution at device pixels for crisp sampling.
        textureSize: Qt.size(Math.ceil(screenW * dpr), Math.ceil(screenH * dpr))
        // The source rect covers the whole screen-sized Image.
        sourceRect: Qt.rect(0, 0, screenW, screenH)
    }
}
