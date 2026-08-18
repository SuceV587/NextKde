import Quickshell

// Keep the Dock bound to a live output. A resume can temporarily remove every
// screen from KWin; Variants then disposes the old layer surface and creates a
// new one when the preferred output returns.
Scope {
    id: root

    readonly property var targetScreen: Quickshell.screens.length > 1
        ? Quickshell.screens[1]
        : (Quickshell.screens[0] ?? null)

    Variants {
        model: root.targetScreen ? [root.targetScreen] : []

        DockWindow {
            required property var modelData
            screen: modelData
        }
    }
}
