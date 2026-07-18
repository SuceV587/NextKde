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
    // `dockItems` is the canonical, ordered Dock configuration. App and
    // folder entries are now rendered; editing and drag-and-drop arrive in
    // later increments.
    //
    // App item:    { type: "app",    appId: "code.desktop" }
    // Folder item: { type: "folder", id: "dev", name: "开发",
    //                appIds: ["code.desktop", "org.kde.kate.desktop"] }
    property var dockItems: [
        { type: "app", appId: "org.kde.dolphin.desktop" },
        { type: "app", appId: "org.kde.kate.desktop" },
        { type: "app", appId: "code.desktop" },
    ]

    // Compatibility projection for the current Dock UI and AppGroupService.
    // Never edit this directly in new code: use setDockItems/addAppItem/
    // removeAppItem so future folder and drag operations have one source of
    // truth. It contains every app ID represented by a top-level app or
    // folder, so existing runtime window filtering continues to work.
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

            // Folder entries are preserved now even though their visual
            // representation lands in a later incremental change. Keeping
            // them here makes persistence forward-compatible and prevents a
            // newer configuration from silently losing user data.
            if (item.type === "folder" && typeof item.id === "string"
                    && item.id.length > 0) {
                const appIds = Array.isArray(item.appIds)
                    ? item.appIds.filter(appId => typeof appId === "string" && appId.length > 0)
                    : []
                normalized.push({
                    type: "folder",
                    id: item.id,
                    name: typeof item.name === "string" && item.name.length > 0
                        ? item.name : item.id,
                    appIds: appIds,
                })
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
            else if (item.type === "folder")
                for (let j = 0; j < item.appIds.length; j++)
                    ids.push(item.appIds[j])
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

    // Reorder one top-level Dock entry without changing any folder members.
    // `sourceKey` deliberately uses the persisted identifier so this remains
    // stable even while application metadata is still resolving.
    function moveDockItem(sourceType, sourceKey, targetIndex) {
        const items = _normalizeDockItems(svc.dockItems)
        let sourceIndex = -1
        for (let i = 0; i < items.length; i++) {
            const item = items[i]
            if ((sourceType === "app" && item.type === "app" && item.appId === sourceKey)
                    || (sourceType === "folder" && item.type === "folder" && item.id === sourceKey)) {
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
            if (item.type === "folder" && item.appIds.indexOf(appId) >= 0) {
                const appIds = item.appIds.filter(id => id !== appId)
                removed = true
                if (appIds.length > 0)
                    remaining.push({
                        type: "folder", id: item.id, name: item.name, appIds: appIds
                    })
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

    function renameFolder(folderId, newName) {
        const name = String(newName ?? "").trim()
        if (!name.length)
            return false

        const items = _normalizeDockItems(svc.dockItems)
        for (let i = 0; i < items.length; i++) {
            const item = items[i]
            if (item.type !== "folder" || item.id !== folderId)
                continue

            if (item.name === name)
                return false
            items[i] = {
                type: "folder",
                id: item.id,
                name: name,
                appIds: item.appIds,
            }
            const changed = setDockItems(items)
            if (changed)
                scheduleSave()
            return changed
        }
        return false
    }

    // Replace one folder in place with its ordered app entries.
    function dissolveFolder(folderId) {
        const items = _normalizeDockItems(svc.dockItems)
        const result = []
        let dissolved = false
        for (let i = 0; i < items.length; i++) {
            const item = items[i]
            if (item.type !== "folder" || item.id !== folderId) {
                result.push(item)
                continue
            }

            for (let j = 0; j < item.appIds.length; j++)
                result.push({ type: "app", appId: item.appIds[j] })
            dissolved = true
        }
        if (!dissolved)
            return false

        const changed = setDockItems(result)
        if (changed)
            scheduleSave()
        return changed
    }

    // Move one member out of a folder, keeping it immediately after the
    // folder. A folder with no remaining members is removed naturally.
    function removeAppFromFolder(folderId, appId) {
        const items = _normalizeDockItems(svc.dockItems)
        const result = []
        let moved = false
        for (let i = 0; i < items.length; i++) {
            const item = items[i]
            if (item.type !== "folder" || item.id !== folderId) {
                result.push(item)
                continue
            }

            const remaining = []
            let movedId = ""
            for (let j = 0; j < item.appIds.length; j++) {
                const candidate = item.appIds[j]
                if (!moved && AppIdentityService.sameApp(candidate, appId)) {
                    moved = true
                    movedId = candidate
                } else {
                    remaining.push(candidate)
                }
            }
            if (!movedId) {
                result.push(item)
                continue
            }
            if (remaining.length > 0) {
                result.push({
                    type: "folder", id: item.id, name: item.name, appIds: remaining
                })
            }
            result.push({ type: "app", appId: movedId })
        }
        if (!moved)
            return false

        const changed = setDockItems(result)
        if (changed)
            scheduleSave()
        return changed
    }

    // Move one top-level app into an existing folder without changing the
    // folder's Dock position or the order of its existing members.
    function moveAppToFolder(folderId, appId) {
        const items = _normalizeDockItems(svc.dockItems)
        let sourceId = ""
        let target = null
        for (let i = 0; i < items.length; i++) {
            const item = items[i]
            if (item.type === "app" && AppIdentityService.sameApp(item.appId, appId))
                sourceId = item.appId
            if (item.type === "folder" && item.id === folderId)
                target = item
        }
        if (!sourceId || !target)
            return false
        if (target.appIds.some(id => AppIdentityService.sameApp(id, sourceId)))
            return false

        const result = []
        for (let i = 0; i < items.length; i++) {
            const item = items[i]
            if (item.type === "app" && AppIdentityService.sameApp(item.appId, sourceId))
                continue
            if (item.type === "folder" && item.id === folderId) {
                result.push({
                    type: "folder",
                    id: item.id,
                    name: item.name,
                    appIds: item.appIds.concat([sourceId]),
                })
                continue
            }
            result.push(item)
        }

        const changed = setDockItems(result)
        if (changed)
            scheduleSave()
        return changed
    }

    // Phase 2A creation action. The app stays at the same Dock position, now
    // represented by a folder item containing it. A stable generated ID is
    // enough until the editor phase adds user-selected names and IDs.
    function createFolderWithApp(appId) {
        const items = _normalizeDockItems(svc.dockItems)
        for (let i = 0; i < items.length; i++) {
            const item = items[i]
            if (item.type === "folder" && item.appIds.indexOf(appId) >= 0)
                return false
            if (item.type === "app" && item.appId === appId) {
                items[i] = {
                    type: "folder",
                    id: "folder-" + Date.now(),
                    name: "新文件夹",
                    appIds: [appId],
                }
                const changed = setDockItems(items)
                if (changed)
                    scheduleSave()
                return changed
            }
        }
        return false
    }

    // ═══════════════════════════════════════════════════════════
    // Persistence — write JSON via shell process
    // ═══════════════════════════════════════════════════════════
    function _doSave() {
        const obj = {
            version: 2,
            baseHeight:    svc.baseHeight,
            maxWidthRatio: svc.maxWidthRatio,
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
        if (obj.maxWidthRatio !== undefined) svc.maxWidthRatio = obj.maxWidthRatio
        if (obj.theme        !== undefined) svc.theme        = obj.theme
        if (obj.iconOverrides !== undefined) svc.iconOverrides = obj.iconOverrides

        if (obj.dockItems !== undefined) {
            setDockItems(obj.dockItems)
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
