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
    property string theme:        "dark"
    // Legacy compatibility field. New app name/icon edits live in
    // AppLauncherConfigService and are published through AppPresentationService.
    // Keep existing values round-trippable so older config files are not lost.
    property var iconOverrides:   ({})
    // `dockItems` is the canonical ordered list of pinned applications.
    // App item: { type: "app", appId: "code.desktop" }
    property var dockItems: [
        { type: "app", appId: "org.kde.dolphin.desktop" },
        { type: "app", appId: "org.kde.kate.desktop" },
        { type: "app", appId: "code.desktop" },
    ]

    // Compatibility projection for the current Dock UI and AppGroupService.
    // Never edit this directly in new code: use setDockItems/addAppItem/
    // removeAppItem so all Dock persistence has one source of truth.
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

    // Public settings contract. Keeping validation and persistence here means
    // external callers cannot put the Dock into an impossible layout state.
    function updateLayout(rawHeight) {
        const height = Math.max(40, Math.min(100, Number(rawHeight)))
        if (!Number.isFinite(height))
            return false
        if (Math.abs(baseHeight - height) <= 0.01)
            return false
        baseHeight = height
        scheduleSave()
        return true
    }

    function isValidTheme(value) {
        return value === "light" || value === "dark" || value === "system"
    }

    function updateTheme(rawTheme) {
        const nextTheme = String(rawTheme)
        if (!isValidTheme(nextTheme))
            return false
        if (theme === nextTheme)
            return false
        theme = nextTheme
        scheduleSave()
        return true
    }


    // ═══════════════════════════════════════════════════════════
    // Dock item model — Phase 1 persistence API
    // ═══════════════════════════════════════════════════════════
    function _normalizeDockItems(rawItems) {
        const normalized = []
        const items = Array.isArray(rawItems) ? rawItems : []

        for (let i = 0; i < items.length; i++) {
            const item = items[i]
            if (!item || typeof item !== "object")
                continue

            if (item.type === "app" && typeof item.appId === "string"
                    && item.appId.length > 0) {
                normalized.push({ type: "app", appId: item.appId })
                continue
            }

            // Folder support was removed. Flatten legacy entries in-place so
            // no previously pinned application disappears after the upgrade.
            if (item.type === "folder" && typeof item.id === "string"
                    && item.id.length > 0) {
                const appIds = Array.isArray(item.appIds)
                    ? item.appIds.filter(appId => typeof appId === "string" && appId.length > 0)
                    : []
                for (let j = 0; j < appIds.length; j++)
                    normalized.push({ type: "app", appId: appIds[j] })
            }
        }
        return normalized
    }

    function _pinnedIdsFromDockItems(items) {
        const ids = []
        for (let i = 0; i < items.length; i++) {
            const item = items[i]
            if (item.type === "app")
                ids.push(item.appId)
        }
        return ids
    }

    // All future editor and drag operations must go through this transaction.
    // It updates the legacy projection atomically, so the current Dock cannot
    // observe a half-updated configuration while the model is being extended.
    function setDockItems(rawItems) {
        const items = _normalizeDockItems(rawItems)
        const before = JSON.stringify(svc.dockItems)
        const after = JSON.stringify(items)
        if (before === after)
            return false

        svc.dockItems = items
        svc.pinnedAppIds = _pinnedIdsFromDockItems(items)
        return true
    }

    function addAppItem(appId) {
        if (typeof appId !== "string" || !appId.length)
            return false
        const items = _normalizeDockItems(svc.dockItems)
        if (_pinnedIdsFromDockItems(items).indexOf(appId) >= 0)
            return false
        items.push({ type: "app", appId: appId })
        const changed = setDockItems(items)
        if (changed)
            scheduleSave()
        return changed
    }

    // Reorder one pinned application.
    // `sourceKey` deliberately uses the persisted identifier so this remains
    // stable even while application metadata is still resolving.
    function moveDockItem(sourceType, sourceKey, targetIndex) {
        const items = _normalizeDockItems(svc.dockItems)
        let sourceIndex = -1
        for (let i = 0; i < items.length; i++) {
            const item = items[i]
            if (sourceType === "app" && item.type === "app" && item.appId === sourceKey) {
                sourceIndex = i
                break
            }
        }

        if (sourceIndex < 0)
            return false

        const destination = Math.max(0, Math.min(items.length - 1,
                                                   Math.round(targetIndex)))
        if (sourceIndex === destination)
            return false

        const moved = items.splice(sourceIndex, 1)[0]
        items.splice(destination, 0, moved)
        const changed = setDockItems(items)
        if (changed)
            scheduleSave()
        return changed
    }

    function removeAppItem(appId) {
        const items = _normalizeDockItems(svc.dockItems)
        const remaining = []
        let removed = false
        for (let i = 0; i < items.length; i++) {
            const item = items[i]
            if (item.type === "app" && item.appId === appId) {
                removed = true
                continue
            }
            remaining.push(item)
        }
        if (!removed)
            return false
        const changed = setDockItems(remaining)
        if (changed)
            scheduleSave()
        return changed
    }

    // ═══════════════════════════════════════════════════════════
    // Persistence — write JSON via shell process
    // ═══════════════════════════════════════════════════════════
    function _doSave() {
        const obj = {
            version: 2,
            baseHeight:    svc.baseHeight,
            theme:         svc.theme,
            iconOverrides: svc.iconOverrides,
            dockItems:     svc.dockItems,
            // Kept for one compatibility release. New code reads dockItems.
            pinnedAppIds:  svc.pinnedAppIds,
            proportions:   svc.proportions,
        }
        const json = JSON.stringify(obj, null, 2)
        console.log("[DockConfig] save requested path=" + svc.configPath
                    + " items=" + JSON.stringify(obj.dockItems))

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
        if (obj.theme !== undefined) {
            if (isValidTheme(obj.theme)) {
                svc.theme = obj.theme
            } else {
                // Do not let a malformed legacy value leak into the IPC
                // contract. The next ordinary save rewrites it as "dark".
                console.warn("[DockConfig] invalid theme ignored")
                scheduleSave()
            }
        }
        if (obj.iconOverrides !== undefined) svc.iconOverrides = obj.iconOverrides

        if (obj.dockItems !== undefined) {
            const flattened = _normalizeDockItems(obj.dockItems)
            const requiresFolderMigration = JSON.stringify(obj.dockItems)
                !== JSON.stringify(flattened)
            setDockItems(flattened)
            // Rewrite legacy folder entries as ordinary pinned apps once the
            // configuration has loaded, so the removed feature cannot return
            // after a later shell restart.
            if (requiresFolderMigration)
                scheduleSave()
        } else if (obj.pinnedAppIds !== undefined) {
            // Version 1 migration: retain the order of the old flat list,
            // then write version 2 after loading. This migration is safe to
            // repeat because dockItems wins once it exists on disk.
            setDockItems(obj.pinnedAppIds.map(appId => ({
                type: "app", appId: appId,
            })))
            console.log("[DockConfig] migrated pinnedAppIds to dockItems")
            scheduleSave()
        }
        if (obj.proportions  !== undefined) svc.proportions   = obj.proportions
    }

    // ── Init: load on startup ──
    Component.onCompleted: loadConfig()
}
