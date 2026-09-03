pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.desktop.modules.common

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
    property string configuredWallpaperUrl: ""
    // Keep a QML-owned reference to each read process. A local JavaScript
    // reference can be collected before its exit callback on some reloads,
    // which leaves the old boolean guard permanently set.
    property var _refreshProcess: null
    property var _resolveProcess: null
    readonly property color primary: palette.primary
    readonly property color secondary: palette.secondary
    readonly property bool ready: palette.ready

    function _applyWallpaperUrl(nextUrl) {
        if (wallpaperUrl.toString() === nextUrl)
            return
        console.log("[WallpaperPalette] sampling screen=" + preferredScreen
            + " " + nextUrl)
        wallpaperUrl = nextUrl
    }

    function _resolveWallpaperUrl(nextUrl) {
        if (!nextUrl.endsWith("/")) {
            _applyWallpaperUrl(nextUrl)
            return
        }

        if (_resolveProcess) {
            _resolveProcess.running = false
            _resolveProcess.destroy()
            _resolveProcess = null
        }

        const screen = Quickshell.screens[Math.min(preferredScreen,
            Math.max(0, Quickshell.screens.length - 1))]
        const targetAspect = screen && screen.height > 0
            ? screen.width / screen.height : 16 / 9
        const packagePath = decodeURIComponent(nextUrl
            .replace(/^file:\/\//, "").replace(/\/+$/, ""))
        const imageSet = ThemeService.isDark ? "images_dark" : "images"
        const requestedUrl = nextUrl
        const proc = _processFactory.createObject(svc, {
            command: ["sh", "-c",
                "base=\"$1/contents/$2\"; [ -d \"$base\" ] || base=\"$1/contents/images\"; "
                    + "find \"$base\" -maxdepth 1 -type f -print 2>/dev/null | "
                    + "awk -v target=\"$3\" 'match($0, /([0-9]+)x([0-9]+)/, size) { ratio=size[1]/size[2]; diff=ratio-target; if (diff<0) diff=-diff; area=size[1]*size[2]; if (!best || diff<bestDiff || (diff==bestDiff && area>bestArea)) { best=$0; bestDiff=diff; bestArea=area } } END { print best }'",
                "wallpaper-package-resolve", packagePath, imageSet,
                String(targetAspect)],
        })
        _resolveProcess = proc
        proc.exited.connect(function(code) {
            if (svc._resolveProcess === proc)
                svc._resolveProcess = null
            const resolvedPath = (proc.stdout?.text ?? "").trim()
            if (code === 0 && resolvedPath
                    && svc.configuredWallpaperUrl === requestedUrl)
                svc._applyWallpaperUrl("file://" + resolvedPath)
            else if (svc.configuredWallpaperUrl === requestedUrl)
                console.warn("[WallpaperPalette] package image resolve failed "
                    + requestedUrl)
            proc.destroy()
        })
        proc.running = true
    }

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
            if (configuredWallpaperUrl === nextUrl)
                return
            configuredWallpaperUrl = nextUrl
            _resolveWallpaperUrl(nextUrl)
        } else {
            configuredWallpaperUrl = ""
            wallpaperUrl = ""
            console.warn("[WallpaperPalette] no image wallpaper found")
        }
    }

    function refresh() {
        if (_refreshProcess)
            return
        const proc = _processFactory.createObject(svc, {
            command: ["sh", "-c", "cat \"$1\"", "wallpaper-palette-read", configPath],
        })
        _refreshProcess = proc
        _refreshWatchdog.restart()
        proc.exited.connect(function(code) {
            svc._refreshWatchdog.stop()
            if (svc._refreshProcess === proc)
                svc._refreshProcess = null
            const output = proc.stdout?.text ?? ""
            if (code === 0)
                svc._readWallpaperText(output)
            else
                console.warn("[WallpaperPalette] config read failed code=" + code)
            proc.destroy()
        })
        proc.running = true
    }

    property Timer _refreshWatchdog: Timer {
        interval: 1500
        repeat: false
        onTriggered: {
            const proc = svc._refreshProcess
            if (!proc)
                return
            console.warn("[WallpaperPalette] config reader stalled; retrying")
            svc._refreshProcess = null
            proc.running = false
            proc.destroy()
            svc.refresh()
        }
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
        // LiquidGlassSurface owns the slow visual transition for wallpaper
        // adaptation. Keep the palette value immediate and unambiguous.
        transitionDuration: 0
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

    property Connections _themeWatch: Connections {
        target: ThemeService
        function onIsDarkChanged() {
            if (svc.configuredWallpaperUrl.endsWith("/"))
                svc._resolveWallpaperUrl(svc.configuredWallpaperUrl)
        }
    }

    Component.onCompleted: refresh()
}
