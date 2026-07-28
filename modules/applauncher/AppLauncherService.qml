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
    // Launcher-owned presentation overrides are published here instead of
    // making Dock read the launcher config file. This keeps persistence local
    // while giving every shell surface one reactive icon-override contract.
    property var appIconOverrides: ({})
    property int appIconOverridesRevision: 0
    // Cross-module action contract. AppLauncher must not import Dock's model
    // services directly, otherwise Dock → Launcher geometry publishing forms
    // a circular QML module dependency.
    signal pinToDockRequested(string appId)

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

    function requestPinToDock(appId) {
        if (!appId)
            return
        console.log("[AppLauncher] request pin app=" + appId)
        service.pinToDockRequested(appId)
    }

    function setAppIconOverrides(overrides) {
        const next = overrides || ({})
        if (JSON.stringify(next) === JSON.stringify(service.appIconOverrides))
            return false
        service.appIconOverrides = next
        service.appIconOverridesRevision++
        console.log("[AppLauncher] published icon overrides="
            + Object.keys(next).length)
        return true
    }

}
