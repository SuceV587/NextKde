pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: service

    property bool ready: false
    property string imagePath: ""
    property var palette: ({})
    property var _process: null

    function color(role, darkMode, fallback) {
        const entry = palette && palette[role]
        const variant = entry && entry[darkMode ? "dark" : "light"]
        return variant && variant.color ? variant.color : fallback
    }

    function generateFromWallpaper(url) {
        const path = decodeURIComponent(String(url || "").replace(/^file:\/\//, ""))
        if (!path || path === imagePath && ready)
            return
        imagePath = path
        ready = false
        if (_process) {
            _process.running = false
            _process.destroy()
        }
        const proc = processFactory.createObject(service, {
            command: ["matugen", "image", path, "--json", "hex", "--dry-run",
                "--source-color-index", "0", "--type", "scheme-tonal-spot"]
        })
        _process = proc
        proc.exited.connect(function(code) {
            if (service._process === proc)
                service._process = null
            if (code === 0) {
                try {
                    const result = JSON.parse(proc.stdout.text)
                    service.palette = result.colors || ({})
                    service.ready = Object.keys(service.palette).length > 0
                    if (service.ready)
                        console.log("[MaterialTheme] matugen palette ready for " + path)
                } catch (error) {
                    console.warn("[MaterialTheme] invalid matugen JSON: " + error)
                }
            } else {
                console.warn("[MaterialTheme] matugen failed: " + proc.stderr.text)
            }
            proc.destroy()
        })
        proc.running = true
    }

    property Component processFactory: Component {
        Process {
            stdout: StdioCollector {}
            stderr: StdioCollector {}
        }
    }
}
