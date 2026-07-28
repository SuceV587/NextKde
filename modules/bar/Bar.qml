import Quickshell

// Recreate the layer-shell window whenever KWin removes and re-adds outputs,
// which is exactly what happens around a sleep/resume cycle on some systems.
Scope {
    id: root

    readonly property var targetScreen: Quickshell.screens.length > 1
        ? Quickshell.screens[1]
        : (Quickshell.screens[0] ?? null)

    Variants {
        model: root.targetScreen ? [root.targetScreen] : []

        BarWindow {
            required property var modelData
            screen: modelData
        }
    }
}
