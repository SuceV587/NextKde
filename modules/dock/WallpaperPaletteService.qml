pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Plasma updates its wallpaper config through atomic file replacement on some
// versions. That can evade an inotify FileView watch, so we read this small
// config on a low-frequency timer and only sample when the URL truly changes.
QtObject {
    id: svc

    readonly property string configPath: Quickshell.env("HOME")
        + "/.config/plasma-org.kde.plasma.desktop-appletsrc"
    // Keep this aligned with shell.qml's primaryScreen selection.
    readonly property int preferredScreen: Quickshell.screens.length > 1 ? 1 : 0
    property url wallpaperUrl: ""
    property bool _refreshing: false
    readonly property color primary: palette.primary
    readonly property color secondary: palette.secondary
    readonly property bool ready: palette.ready

    function _readWallpaperText(content) {
        const containmentScreens = ({})
        const wallpapers = ({})
        let containmentId = ""
        let wallpaperId = ""
        const lines = content.split("\n")

        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i]
            const containmentMatch = line.match(/^\[Containments\]\[(\d+)\]$/)
            const wallpaperMatch = line.match(/^\[Containments\]\[(\d+)\]\[Wallpaper\]\[org\.kde\.image\]\[General\]$/)

            if (containmentMatch) {
                containmentId = containmentMatch[1]
                wallpaperId = ""
                continue
            }
            if (wallpaperMatch) {
                wallpaperId = wallpaperMatch[1]
                containmentId = ""
                continue
            }
            if (containmentId && line.startsWith("lastScreen=")) {
                containmentScreens[containmentId] = Number(line.slice("lastScreen=".length))
            } else if (wallpaperId && line.startsWith("Image=")) {
                wallpapers[wallpaperId] = line.slice("Image=".length).trim()
            }
        }

        let nextUrl = ""
        for (const id in containmentScreens) {
            if (containmentScreens[id] === preferredScreen && wallpapers[id]) {
                nextUrl = wallpapers[id]
                break
            }
        }
        if (!nextUrl) {
            for (const id in wallpapers) {
                nextUrl = wallpapers[id]
                break
            }
        }

        if (nextUrl) {
            if (wallpaperUrl.toString() === nextUrl)
                return
            console.log("[WallpaperPalette] sampling screen=" + preferredScreen
                + " " + nextUrl)
            wallpaperUrl = nextUrl
        } else {
            wallpaperUrl = ""
            console.warn("[WallpaperPalette] no image wallpaper found")
        }
    }

    function refresh() {
        if (_refreshing)
            return
        _refreshing = true
        const proc = _processFactory.createObject(svc, {
            command: ["sh", "-c", "cat \"$1\"", "wallpaper-palette-read", configPath],
        })
        proc.exited.connect(function(code) {
            svc._refreshing = false
            const output = proc.stdout?.text ?? ""
            if (code === 0)
                svc._readWallpaperText(output)
            else
                console.warn("[WallpaperPalette] config read failed code=" + code)
            proc.destroy()
        })
        proc.running = true
    }

    property Component _processFactory: Component {
        Process {
            stdout: StdioCollector {}
            stderr: StdioCollector {}
        }
    }

    property Timer _refreshTimer: Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: svc.refresh()
    }

    property ArtworkPalette _palette: ArtworkPalette {
        id: palette
        source: svc.wallpaperUrl
    }

    property Connections _paletteLog: Connections {
        target: palette
        function onReadyChanged() {
            if (palette.ready) {
                console.log("[WallpaperPalette] primary=" + palette.primary
                    + " secondary=" + palette.secondary)
            }
        }
    }

    Component.onCompleted: refresh()
}
