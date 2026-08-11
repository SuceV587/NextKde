import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.modules.common

// One concrete output-bound Dock layer surface.
PanelWindow {
    id: root

    // Distinguish this surface from other quickshell panels so the glass
    // plugin can give it its own highlight direction.
    WlrLayershell.namespace: "quickshell-dock"

    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    // Keep the persistent Dock on the normal layer-shell Top layer.
    WlrLayershell.layer: WlrLayer.Top

    anchors {
        left: true
        bottom: true
        right: true
    }
    margins {
        bottom: 5
    }

    implicitHeight: dockWrapper.height
    exclusiveZone: implicitHeight + 5

    BackgroundEffect.blurRegion: RoundedBlurRegion {
        item: dockWrapper
        radius: dockContainer.pillRadius
    }

    Item {
        id: dockWrapper
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
        }
        width: dockContainer.computedDockWidth
        height: dockContainer.computedDockHeight

        // LiquidGlassSurface temporarily disabled to isolate KWin effect rendering.
        // LiquidGlassSurface {
        //     anchors.fill: parent
        //     radius: dockContainer.pillRadius
        //     baseColor: ThemeService.backgroundColor
        //     ambientPrimary: WallpaperPaletteService.primary
        //     ambientSecondary: WallpaperPaletteService.secondary
        //     ambientStrength: 0.82
        // }

        DockContainer {
            id: dockContainer
            anchors.centerIn: parent
        }
    }
}
