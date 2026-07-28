pragma Singleton

import QtQuick
import Quickshell.Io

// Thin adapter around cliphist. Keeping it here gives QuickSearch one stable
// clipboard interface while cliphist continues to own persistence and dedupe.
QtObject {
    id: service

    property var entries: []
    property int revision: 0
    property var _listProcess: null

    // cliphist is only a database. Separate text and image watchers preserve
    // the original Wayland MIME type instead of turning image entries into a
    // filename or text preview.
    property Process textHistoryWatcher: Process {
        command: ["wl-paste", "--type", "text", "--watch", "cliphist", "store"]
        running: true
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => console.warn("[Clipboard] text watcher: " + data)
        }
    }
    property Process imageHistoryWatcher: Process {
        command: ["wl-paste", "--type", "image", "--watch", "cliphist", "store"]
        running: true
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => console.warn("[Clipboard] image watcher: " + data)
        }
    }

    function refresh() {
        if (_listProcess)
            return

        const proc = processFactory.createObject(service, {
            command: ["cliphist", "list"],
        })
        _listProcess = proc
        proc.exited.connect(function(code) {
            if (service._listProcess === proc)
                service._listProcess = null
            if (code === 0)
                service._readList(proc.stdout?.text ?? "")
            else
                console.warn("[Clipboard] cliphist list failed: "
                             + (proc.stderr?.text ?? ""))
            proc.destroy()
        })
        proc.running = true
    }

    function copy(selectionRecord) {
        // cliphist decode intentionally receives the complete original list
        // row (id + tab + preview), not an id alone. Passing it positionally
        // keeps clipboard data out of shell evaluation and restores image
        // bytes with their original MIME type.
        const proc = processFactory.createObject(service, {
            command: ["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy",
                      "quicksearch-clipboard-copy", String(selectionRecord)],
        })
        proc.exited.connect(function(code) {
            if (code !== 0)
                console.warn("[Clipboard] failed to copy history entry: "
                             + (proc.stderr?.text ?? ""))
            proc.destroy()
        })
        proc.running = true
    }

    function _readList(output) {
        const parsed = []
        const lines = output.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const tab = lines[i].indexOf("\t")
            if (tab <= 0)
                continue
            const entryId = lines[i].slice(0, tab)
            const preview = lines[i].slice(tab + 1).trim()
            if (preview) {
                // cliphist formats decoded image previews as
                // "[[ binary data 123 KiB png 1920x1080 ]]". Do not infer an
                // image from a text filename such as "screenshot.png".
                const isImage = /^\[\[ binary data .+ (png|jpe?g|gif|bmp|tiff?|webp) \d+x\d+ \]\]$/i.test(preview)
                parsed.push({
                    id: entryId,
                    preview: preview,
                    record: lines[i],
                    isImage: isImage,
                })
            }
        }
        entries = parsed
        revision += 1
    }

    Component.onCompleted: refresh()

    property Component processFactory: Component {
        Process {
            stdout: StdioCollector {}
            stderr: StdioCollector {}
        }
    }
}
