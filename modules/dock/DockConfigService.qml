pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ────────────────────────────────────────────────────────────────
// DockConfigService — Persistent JSON configuration.
//
// Reads/writes dock/config.json on disk.  All values have sensible
// defaults so the dock works before the first config file exists.
//
// Writes are debounced (500 ms) so rapid changes batch into one save.
// ────────────────────────────────────────────────────────────────

QtObject {
    id: svc

    // Pin state is runtime user data, not QML source. Keeping it outside the
    // shell directory prevents Quickshell's source-file watcher from reloading
    // the shell while a temporary config file is being atomically replaced.
    readonly property string configDir:  Quickshell.stateDir + "/dock"
    readonly property string configPath: configDir + "/config.json"

    // ── Default proportion constants ──
    readonly property var defaultProportions: ({
        vpad:      0.20,
        hpad:      0.4,
        spacing:   0.09,
        divmargin: 0.20,
    })

    // ═══════════════════════════════════════════════════════════
    // Runtime values (backed by JSON when available)
    // ═══════════════════════════════════════════════════════════
    property real   baseHeight:   60
    property real   maxWidthRatio: 0.9
    property string theme:        "dark"
    // Optional per-app icon overrides keyed by canonical desktop ID.
    // Example: { "code.desktop": "/path/to/custom.svg" }
    property var iconOverrides:   ({})
    // Pinned entries are shown only while the corresponding app has no open
    // window. Once a window exists, the window section is the single visible
    // representation of that app until all its windows are closed.
    property var pinnedAppIds: [
        "org.kde.dolphin.desktop",
        "org.kde.kate.desktop",
        "code.desktop",
    ]
    property var    proportions:  defaultProportions

    // ═══════════════════════════════════════════════════════════
    // Proportion accessor — safe fallback to defaults
    // ═══════════════════════════════════════════════════════════
    function prop(key) {
        if (svc.proportions && svc.proportions[key] !== undefined) {
            return svc.proportions[key]
        }
        return svc.defaultProportions[key] ?? 0
    }

    // ═══════════════════════════════════════════════════════════
    // Debounced save
    // ═══════════════════════════════════════════════════════════
    property Timer _saveTimer: Timer {
        interval: 500
        repeat: false
        onTriggered: svc._doSave()
    }

    function scheduleSave() { _saveTimer.restart() }

    // ═══════════════════════════════════════════════════════════
    // Persistence — write JSON via shell process
    // ═══════════════════════════════════════════════════════════
    function _doSave() {
        const obj = {
            version: 1,
            baseHeight:    svc.baseHeight,
            maxWidthRatio: svc.maxWidthRatio,
            theme:         svc.theme,
            iconOverrides: svc.iconOverrides,
            pinnedAppIds:  svc.pinnedAppIds,
            proportions:   svc.proportions,
        }
        const json = JSON.stringify(obj, null, 2)
        console.log("[DockConfig] save requested path=" + svc.configPath
                    + " pinned=" + JSON.stringify(obj.pinnedAppIds))

        // Pass the directory and JSON as separate process arguments. The old
        // implementation called write() before exec() while stdinEnabled was
        // false, so the data was discarded and config.json was never created.
        // Using printf with positional shell arguments avoids fragile quoting
        // and does not depend on a stdin channel being closed correctly.
        const proc = _makeProc([
            "sh", "-c",
            "mkdir -p \"$1\" && printf %s \"$2\" > \"$1/config.json.tmp\" && mv \"$1/config.json.tmp\" \"$1/config.json\"",
            "dock-config-save",
            svc.configDir,
            json,
        ])
        if (proc) {
            proc.exited.connect(function(code) {
                const stderr = proc.stderr?.text ?? ""
                if (code === 0) {
                    console.log("[DockConfig] save complete path=" + svc.configPath)
                } else {
                    console.warn("[DockConfig] save failed code=" + code
                                 + " stderr=" + stderr)
                }
                proc.destroy()
            })
            // Setting running is the documented, unambiguous process start
            // path. It avoids the exec() overload ambiguity in QML.
            proc.running = true
        }
    }

    function loadConfig() {
        console.log("[DockConfig] load requested path=" + svc.configPath)
        const proc = _makeProc([
            "sh", "-c", "cat \"$1\"", "dock-config-load", svc.configPath
        ])
        if (!proc) return
        proc.exited.connect(function(code) {
            // Process.stdout is a StdioCollector, not a string. Its text
            // field contains the JSON collected after the command finishes.
            const output = proc.stdout?.text ?? ""
            const stderr = proc.stderr?.text ?? ""
            if (code === 0 && output) {
                try {
                    const obj = JSON.parse(output)
                    _apply(obj)
                    console.log("[DockConfig] load complete pinned="
                                + JSON.stringify(svc.pinnedAppIds))
                } catch (e) {
                    console.warn("[DockConfig] parse error, using defaults: " + e)
                }
            } else if (code !== 0) {
                console.log("[DockConfig] no saved config yet code=" + code
                            + " stderr=" + stderr)
            }
            proc.destroy()
        })
        proc.running = true
    }

    // Reusable Process factory
    property Component _procFactory: Component {
        Process {
            // Collect both streams so completion logs contain the actual
            // command failure, and loadConfig can parse stdout.text.
            stdout: StdioCollector {}
            stderr: StdioCollector {}
        }
    }

    function _makeProc(command) {
        try {
            return _procFactory.createObject(svc, { command: command })
        } catch (e) {
            console.warn("DockConfigService: cannot create Process:", e)
        }
        return null
    }

    function _apply(obj) {
        if (obj.baseHeight   !== undefined) svc.baseHeight   = obj.baseHeight
        if (obj.maxWidthRatio !== undefined) svc.maxWidthRatio = obj.maxWidthRatio
        if (obj.theme        !== undefined) svc.theme        = obj.theme
        if (obj.iconOverrides !== undefined) svc.iconOverrides = obj.iconOverrides
        if (obj.pinnedAppIds !== undefined) svc.pinnedAppIds  = obj.pinnedAppIds
        if (obj.proportions  !== undefined) svc.proportions   = obj.proportions
    }

    // ── Init: load on startup ──
    Component.onCompleted: loadConfig()
}
