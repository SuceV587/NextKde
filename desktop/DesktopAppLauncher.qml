pragma Singleton
import QtQuick
import Quickshell

// Starts standalone Qt Quick applications without importing their UI into, or
// tying their lifetime to, the Shell process.
QtObject {
    id: launcher

    readonly property string settingsEntrypoint:
        Quickshell.shellDir + "/apps/settings/main.qml"
    readonly property string settingsBinary:
        Quickshell.shellDir + "/.build/apps/settings/kos-settings"

    function openSettings() {
        // The native host exposes the narrow Settings IPC bridge. Keep a QML
        // fallback so contributors can still inspect the UI before building.
        Quickshell.execDetached([
            "sh", "-c",
            "if [ -x \"$1\" ]; then exec \"$1\"; fi; exec qml6 \"$2\"",
            "kos-settings-launch", launcher.settingsBinary,
            launcher.settingsEntrypoint
        ])
    }
}
