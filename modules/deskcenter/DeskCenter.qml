import Quickshell

// A desktop surface is intentionally independent from application windows.
// Variants recreates it when KWin removes or restores an output.
Scope {
    id: root

    readonly property var targetScreen: Quickshell.screens.length > 1 ? Quickshell.screens[1] : (Quickshell.screens[0] ?? null)

    Variants {
        model: root.targetScreen ? [root.targetScreen] : []

        DeskCenterWindow {
            required property var modelData

            screen: modelData
        }

    }

}
