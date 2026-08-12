pragma Singleton
import QtQuick
import Quickshell

// AppLauncherService — public control and geometry contract for the launcher.
//
// The launcher is intentionally independent from Dock. Dock only publishes
// its already-calculated geometry here; keyboard shortcuts, IPC, search and
// app-grid state can all toggle this service without importing Dock visuals.
QtObject {
    id: service

    Component.onCompleted: console.log("[AppLauncherService] instantiated")

    property bool open: false
    property real dockWidth: 0
    property real dockHeight: 0
    // Dock publishes material values as data rather than making this module
    // import qs.modules.dock. That prevents a circular QML module dependency.
    property color dockBackgroundColor: Qt.rgba(0.08, 0.09, 0.12, 0.92)
    property color dockAmbientPrimary: "transparent"
    property color dockAmbientSecondary: "transparent"
    property color dockForegroundColor: "white"
    // Screen-space centre of the dock's launcher icon at the moment it was
    // tapped. The launcher window (a full-screen surface) reads this as the
    // origin every app icon scatters from when the grid opens. A negative x
    // means "no origin captured" so the launcher falls back to its own centre.
    property point launcherOriginPoint: Qt.point(-1, -1)

    function setLauncherOrigin(screenX, screenY) {
        service.launcherOriginPoint = Qt.point(screenX, screenY)
    }

    function setDockPresentation(width, height, background, primary, secondary, foreground) {
        service.dockWidth = width
        service.dockHeight = height
        service.dockBackgroundColor = background
        service.dockAmbientPrimary = primary
        service.dockAmbientSecondary = secondary
        service.dockForegroundColor = foreground
        console.log("[AppLauncherService] presentation " + width + "x" + height)
    }

    onOpenChanged: console.log("[AppLauncherService] open=" + open)

    function show() {
        service.open = true
        console.log("[AppLauncher] show width=" + dockWidth
            + " height=" + dockHeight)
    }
    function hide() { service.open = false }
    function toggle() {
        service.open = !service.open
        console.log("[AppLauncher] toggle open=" + service.open
            + " width=" + dockWidth + " height=" + dockHeight)
    }

}
