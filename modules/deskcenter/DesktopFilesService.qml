pragma Singleton

import QtQuick
import Quickshell.Io

// QML only consumes the shell-data-service snapshot. Directory scanning and
// ordering deliberately remain in the service so this view survives reloads
// without turning the desktop renderer into a file manager backend.
QtObject {
    id: service

    property var entries: []
    property string directory: ""
    property bool ready: false
    property string lastError: ""
    property var _readProcess: null
    property bool desktopSubscriptionEnabled: true
    property var openWith: ({ loading: false, mime: "", defaultId: "", handlers: [] })
    // The URI list is also published through wl-copy, while this state keeps
    // the cut/copy distinction for a later paste in this shell session.
    property string clipboardMode: ""
    property var clipboardPaths: []

    function requestDesktopRefresh() {
        const process = processFactory.createObject(service, {
            command: ["sh", "-c",
                "runtime=${XDG_RUNTIME_DIR:-/tmp}; printf '%s\\n' '{\"type\":\"refresh_desktop\"}' | socat - UNIX-CONNECT:\"$runtime/shell-data-service.sock\"",
                "desktop-files-refresh"]
        })
        process.exited.connect(function() {
            // The socket command returns as soon as it has been delivered.
            // Give the service one short turn to atomically publish its scan.
            service.fastRefresh.restart()
            process.destroy()
        })
        process.running = true
    }

    function reload() {
        if (_readProcess)
            return
        const process = processFactory.createObject(service, {
            command: ["sh", "-c",
                "state=${XDG_STATE_HOME:-$HOME/.local/state}; cat \"$state/quickshell/shell-data-service/snapshot.json\" 2>/dev/null",
                "desktop-files-snapshot"]
        })
        _readProcess = process
        process.exited.connect(function() {
            try {
                const snapshot = JSON.parse((process.stdout?.text ?? "").trim())
                const desktop = snapshot.desktop ?? {}
                entries = Array.isArray(desktop.entries) ? desktop.entries : []
                directory = desktop.directory ?? ""
                ready = true
            } catch (_) {
                // The service has not been installed or written its first
                // snapshot yet. Keep the desktop surface visually empty.
            }
            if (service._readProcess === process)
                service._readProcess = null
            process.destroy()
        })
        process.running = true
    }

    function validName(name) {
        const trimmed = (name ?? "").trim()
        return trimmed.length > 0 && trimmed !== "." && trimmed !== ".."
            && !trimmed.includes("/") && !trimmed.includes("\u0000")
    }

    function run(command, callback) {
        const process = processFactory.createObject(service, { command: command })
        process.exited.connect(function(exitCode) {
            if (exitCode !== 0)
                service.lastError = "操作未完成"
            else if (callback)
                callback()
            process.destroy()
        })
        process.running = true
    }

    function openEntry(entry) {
        if (!entry?.path)
            return
        if (entry.kind === "launcher")
            run(["gio", "launch", entry.path])
        else
            run(["xdg-open", entry.path])
    }

    // gio deliberately reports an empty file as application/x-zerosize,
    // discarding a useful suffix such as .md.  The file manager still offers
    // editors in that case, so retain the common text/source associations for
    // the desktop's “打开方式” menu.
    function emptyFileMimeFromSuffix(path) {
        const suffix = (path ?? "").split(".").pop().toLowerCase()
        const textSuffixes = ["txt", "text", "log", "md", "markdown", "rst",
            "csv", "tsv", "json", "xml", "yaml", "yml", "ini", "conf",
            "js", "ts", "jsx", "tsx", "qml", "py", "go", "rs", "c", "cc",
            "cpp", "h", "hpp", "java", "sh", "zsh", "bash", "html", "css"]
        if (["md", "markdown"].indexOf(suffix) >= 0)
            return "text/markdown"
        return textSuffixes.indexOf(suffix) >= 0 ? "text/plain" : ""
    }

    function queryOpenWith(entry, callback) {
        if (!entry?.path)
            return
        openWith = ({ loading: true, mime: "", defaultId: "", handlers: [] })
        const info = processFactory.createObject(service, {
            command: ["gio", "info", "-a", "standard::content-type", entry.path]
        })
        info.exited.connect(function(exitCode) {
            const match = (info.stdout?.text ?? "").match(/standard::content-type:\s*(\S+)/)
            const detectedMime = exitCode === 0 && match ? match[1] : ""
            const mime = detectedMime === "application/x-zerosize"
                ? emptyFileMimeFromSuffix(entry.path) : detectedMime
            info.destroy()
            if (!mime) {
                service.openWith = ({ loading: false, mime: "", defaultId: "", handlers: [] })
                if (callback) callback(service.openWith)
                return
            }
            const handlers = processFactory.createObject(service, { command: ["gio", "mime", mime] })
            handlers.exited.connect(function(handlerExitCode) {
                const lines = (handlers.stdout?.text ?? "").split(/\r?\n/)
                let defaultId = ""
                const ids = []
                for (let index = 0; index < lines.length; ++index) {
                    const line = lines[index].trim()
                    const defaultMatch = line.match(/^Default application.*:\s*(\S+)/)
                    if (defaultMatch) defaultId = defaultMatch[1]
                    const idMatch = line.match(/^(\S+\.desktop)$/)
                    if (idMatch && ids.indexOf(idMatch[1]) < 0) ids.push(idMatch[1])
                }
                if (defaultId && ids.indexOf(defaultId) < 0) ids.unshift(defaultId)
                service.openWith = ({ loading: false, mime: mime, defaultId: defaultId,
                    handlers: handlerExitCode === 0 ? ids : [] })
                handlers.destroy()
                if (callback) callback(service.openWith)
            })
            handlers.running = true
        })
        info.running = true
    }

    function launchWith(entry, desktopId) {
        if (!entry?.path || !desktopId)
            return
        const script = "id=$1; target=$2; for root in \"${XDG_DATA_HOME:-$HOME/.local/share}/applications\" /usr/local/share/applications /usr/share/applications; do if test -f \"$root/$id\"; then exec gio launch \"$root/$id\" \"$target\"; fi; done; exit 1"
        run(["sh", "-c", script, "desktop-open-with", desktopId, entry.path])
    }

    function setDefaultOpenWith(mime, desktopId) {
        if (!mime || !desktopId)
            return
        run(["gio", "mime", mime, desktopId])
    }

    function showKdeOpenWith(entry) {
        if (!entry?.path)
            return
        // Installed by tools/kde-open-with-helper.  It opens KDE's modern
        // portal chooser, rather than a shell-maintained imitation.
        run(["sh", "-c", "exec \"$HOME/.local/bin/quickshell-kde-open-with\" \"$1\"",
            "quickshell-kde-open-with", entry.path])
    }

    function openDirectory() {
        if (directory)
            run(["xdg-open", directory])
    }

    function createUntitledFolder(callback) {
        if (!directory)
            return
        lastError = ""
        const script = "dir=$1; base='untitled folder'; target=\"$dir/$base\"; index=2; while test -e \"$target\"; do target=\"$dir/$base $index\"; index=$((index + 1)); done; mkdir -- \"$target\" && printf '%s' \"$target\""
        const process = processFactory.createObject(service, {
            command: ["sh", "-c", script, "desktop-new-folder", directory]
        })
        process.exited.connect(function(exitCode) {
            const createdPath = (process.stdout?.text ?? "").trim()
            if (exitCode === 0 && createdPath) {
                service.requestDesktopRefresh()
                if (callback)
                    callback(createdPath)
            } else {
                service.lastError = "无法创建文件夹"
            }
            process.destroy()
        })
        process.running = true
    }

    function renameEntry(entry, name) {
        if (!entry?.path || !directory || !validName(name)) {
            lastError = "名称不能为空，且不能包含 /"
            return false
        }
        const target = directory + "/" + name.trim()
        if (target === entry.path)
            return true
        lastError = ""
        run(["mv", "--", entry.path, target], requestDesktopRefresh)
        return true
    }

    function trashEntries(entries, onSuccess) {
        const paths = entries.map(function(entry) { return entry.path })
            .filter(function(path) { return !!path })
        if (paths.length === 0)
            return
        lastError = ""
        // gio trash follows the desktop trash specification, so this action
        // is recoverable and never directly unlinks user data.
        run(["gio", "trash"].concat(paths), function() {
            requestDesktopRefresh()
            if (onSuccess)
                onSuccess()
        })
    }

    function trashEntry(entry) {
        trashEntries(entry ? [entry] : [])
    }

    function copyEntries(entries, mode) {
        const paths = entries.map(function(entry) { return entry.path })
            .filter(function(path) { return !!path })
        if (paths.length === 0)
            return
        const uriList = paths.map(function(path) {
            return "file://" + encodeURIComponent(path).replace(/%2F/gi, "/")
        }).join("\r\n") + "\r\n"
        const process = processFactory.createObject(service, {
            command: ["sh", "-c", "printf '%s' \"$1\" | wl-copy --type text/uri-list",
                "desktop-file-copy", uriList]
        })
        process.exited.connect(function(exitCode) {
            if (exitCode === 0) {
                service.clipboardMode = mode
                service.clipboardPaths = paths
            } else {
                service.lastError = "无法写入剪贴板"
                console.warn("[DesktopFiles] wl-copy failed: " + (process.stderr?.text ?? ""))
            }
            process.destroy()
        })
        process.running = true
    }

    function filePathsFromUriList(raw) {
        const paths = []
        const lines = String(raw ?? "").split(/\r?\n/)
        for (let index = 0; index < lines.length; ++index) {
            const uri = lines[index].trim()
            if (!uri || uri.startsWith("#") || !uri.startsWith("file://"))
                continue
            try {
                const path = decodeURIComponent(uri.slice("file://".length))
                if (path.startsWith("/") && paths.indexOf(path) < 0)
                    paths.push(path)
            } catch (_) {}
        }
        return paths
    }

    function samePathList(left, right) {
        if (left.length !== right.length)
            return false
        for (let index = 0; index < left.length; ++index) {
            if (left[index] !== right[index])
                return false
        }
        return true
    }

    function pasteIntoDesktop() {
        if (!directory)
            return
        const reader = processFactory.createObject(service, {
            command: ["wl-paste", "--no-newline", "--type", "text/uri-list"]
        })
        reader.exited.connect(function(exitCode) {
            const paths = exitCode === 0 ? service.filePathsFromUriList(reader.stdout?.text) : []
            reader.destroy()
            if (paths.length === 0) {
                service.lastError = "剪贴板中没有可粘贴的文件"
                if (exitCode !== 0)
                    console.warn("[DesktopFiles] wl-paste failed: " + (reader.stderr?.text ?? ""))
                return
            }
            const mode = service.clipboardMode === "cut"
                    && service.samePathList(paths, service.clipboardPaths) ? "cut" : "copy"
            const script = "mode=$1; destination=$2; shift 2\n"
                + "for source do\n"
                + "  test -e \"$source\" || continue\n"
                + "  if test \"$mode\" = cut && test \"$(dirname \"$source\")\" = \"$destination\"; then continue; fi\n"
                + "  base=${source##*/}; candidate=\"$destination/$base\"; count=1\n"
                + "  while test -e \"$candidate\"; do\n"
                + "    stem=${base%.*}; extension=.${base##*.}\n"
                + "    if test \"$stem\" = \"$base\" || test -z \"$stem\"; then candidate=\"$destination/$base (副本 $count)\"; else candidate=\"$destination/$stem (副本 $count)$extension\"; fi\n"
                + "    count=$((count + 1))\n"
                + "  done\n"
                + "  if test \"$mode\" = cut; then mv -- \"$source\" \"$candidate\"; else cp -a -- \"$source\" \"$candidate\"; fi\n"
                + "done"
            const worker = processFactory.createObject(service, {
                command: ["sh", "-c", script, "desktop-file-paste", mode, directory].concat(paths)
            })
            worker.exited.connect(function(workerExitCode) {
                if (workerExitCode === 0) {
                    if (mode === "cut") {
                        service.clipboardMode = ""
                        service.clipboardPaths = []
                    }
                    service.requestDesktopRefresh()
                } else {
                    service.lastError = "粘贴未完成"
                }
                worker.destroy()
            })
            worker.running = true
        })
        reader.running = true
    }

    property Process desktopSubscription: Process {
        // The Go service owns the inotify watcher. Keep this local socket open
        // for change notifications; reload() then reads its atomic snapshot.
        command: ["sh", "-c",
            "runtime=${XDG_RUNTIME_DIR:-/tmp}; exec socat - UNIX-CONNECT:\"$runtime/shell-data-service.sock\"",
            "desktop-files-subscription"]
        running: service.desktopSubscriptionEnabled
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: _ => service.fastRefresh.restart()
        }
        stderr: SplitParser { splitMarker: "\n" }
        onExited: {
            service.desktopSubscriptionEnabled = false
            service.subscriptionRetry.restart()
        }
    }
    property Timer subscriptionRetry: Timer {
        interval: 1000
        repeat: false
        onTriggered: service.desktopSubscriptionEnabled = true
    }
    property Timer fastRefresh: Timer {
        interval: 120
        repeat: false
        onTriggered: service.reload()
    }
    property Component processFactory: Component {
        Process {
            stdout: StdioCollector {}
            stderr: StdioCollector {}
        }
    }
    Component.onCompleted: reload()
}
