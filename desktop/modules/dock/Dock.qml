import Quickshell
import QtQuick

// Keep the Dock bound to a live output. A resume can temporarily remove every
// screen from KWin; Variants then disposes the old layer surface and creates a
// new one when the preferred output returns.
Scope {
    id: root

    readonly property var targetScreen: Quickshell.screens.length > 1
        ? Quickshell.screens[1]
        : (Quickshell.screens[0] ?? null)

    // One concrete component per dock edge. The position literal lives in the
    // component body, so every freshly created window commits its final anchors
    // on its first layer-shell commit. Forwarding position through Loader
    // properties would instead create the window with the default value first,
    // then patch anchors on the live surface.
    Component {
        id: bottomDock
        DockWindow {
            property var modelData: null
            position: "bottom"
            screen: modelData
        }
    }
    Component {
        id: leftDock
        DockWindow {
            property var modelData: null
            position: "left"
            screen: modelData
        }
    }
    Component {
        id: rightDock
        DockWindow {
            property var modelData: null
            position: "right"
            screen: modelData
        }
    }

    Variants {
        model: root.targetScreen ? [root.targetScreen] : []

        // Switching sourceComponent disposes the old layer surface and creates
        // a fresh one: layer-shell state is committed at creation, and updating
        // anchors on a live surface does not reliably reach the compositor.
        delegate: Loader {
            required property var modelData
            sourceComponent: ConfigService.position === "left"
                ? leftDock
                : (ConfigService.position === "right" ? rightDock : bottomDock)
        }
    }
}
