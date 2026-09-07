pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared application-action contract.
//
// This singleton deliberately does not import Dock or AppLauncher. Launching
// a DesktopEntry is provider-neutral, while persistence actions are emitted
// as requests and handled by their owning module. That prevents a dependency
// cycle and lets future surfaces (Alt+Tab, Stage Manager, search) use the
// exact same public actions.
QtObject {
    id: service

    signal pinRequested(string appId)
    signal unpinRequested(string appId)
    signal hideRequested(string appId)
    signal editRequested(var application)

    // The shell runs inside its autostart unit's cgroup, and any process it
    // spawns directly inherits that cgroup. Without this indirection every
    // app started from the dock, launcher, or desktop is accounted (and, on a
    // shell restart, killed) together with quickshell itself. A transient
    // systemd scope gives each app its own cgroup — the same scheme KDE's and
    // GNOME's launchers use — and the app-*.scope prefix keeps Plasma's
    // process tools attributing memory to the app instead of lumping it onto
    // "Quickshell Desktop".
    function scopedUnitName(appId) {
        const sanitized = String(appId ?? "app").replace(/[^A-Za-z0-9.:_-]/g, "-").slice(0, 160)
        const unique = Date.now().toString(36) + Math.floor(Math.random() * 1e6).toString(36)
        return "app-" + sanitized + "-" + unique + ".scope"
    }

    function scopedCommand(command, appId) {
        return ["systemd-run", "--user", "--scope", "--quiet", "--collect",
            "--unit", scopedUnitName(appId)].concat(command)
    }

    function launch(application) {
        const entry = application?.entry ?? application
        const appId = String(application?.id ?? entry?.id ?? "")
        if (!entry?.execute) {
            console.warn("[AppAction] cannot launch without DesktopEntry app=" + appId)
            return false
        }
        // Resolve the desktop file and start it inside its own scope. IDs no
        // data directory resolves (flatpak exports, custom in-memory entries)
        // fall back to quickshell's direct DesktopEntry spawn.
        const desktopId = /\.desktop$/i.test(appId) ? appId : appId + ".desktop"
        const script = "id=$1; unit=$2; for root in \"${XDG_DATA_HOME:-$HOME/.local/share}/applications\" /usr/local/share/applications /usr/share/applications; do if test -f \"$root/$id\"; then if command -v systemd-run >/dev/null 2>&1; then exec systemd-run --user --scope --quiet --collect --unit \"$unit\" gio launch \"$root/$id\"; fi; exec gio launch \"$root/$id\"; fi; done; exit 3"
        const process = processFactory.createObject(service, {
            command: ["sh", "-c", script, "app-action-launch", desktopId,
                scopedUnitName(desktopId.replace(/\.desktop$/i, ""))]
        })
        process.exited.connect(function(exitCode) {
            if (exitCode === 3) {
                try {
                    entry.execute()
                } catch (error) {
                    console.warn("[AppAction] failed to launch app=" + appId + ": " + error)
                }
            }
            process.destroy()
        })
        process.running = true
        console.log("[AppAction] launch app=" + appId)
        return true
    }

    function entryForId(desktopId) {
        const raw = String(desktopId ?? "")
        const candidates = [raw, raw.replace(/\.desktop$/i, ""),
                            raw.endsWith(".desktop") ? raw : raw + ".desktop"]
        for (let index = 0; index < candidates.length; index++) {
            try {
                const entry = DesktopEntries.byId(candidates[index])
                if (entry)
                    return entry
            } catch (_) {}
        }
        return null
    }

    // Widgets use the desktop entry as the executable authority, then append
    // app-owned deep-link arguments. With no arguments the regular launcher
    // path remains in use, including all DesktopEntry environment handling.
    function launchById(desktopId, launchArguments) {
        const entry = entryForId(desktopId)
        if (!entry) {
            console.warn("[AppAction] desktop entry is not installed: " + desktopId)
            return false
        }
        const extra = launchArguments ?? []
        if (extra.length === 0)
            return launch(entry)
        const baseCommand = entry.command ?? []
        if (baseCommand.length === 0) {
            console.warn("[AppAction] desktop entry has no launch command: " + desktopId)
            return false
        }
        try {
            Quickshell.execDetached([String(baseCommand[0])].concat(extra))
            console.log("[AppAction] deep link app=" + desktopId
                        + " args=" + JSON.stringify(extra))
            return true
        } catch (error) {
            console.warn("[AppAction] deep-link launch failed app=" + desktopId
                         + ": " + error)
            return false
        }
    }

    function pin(appId) {
        if (!appId)
            return false
        pinRequested(String(appId))
        return true
    }

    function unpin(appId) {
        if (!appId)
            return false
        unpinRequested(String(appId))
        return true
    }

    function hide(appId) {
        if (!appId)
            return false
        hideRequested(String(appId))
        return true
    }

    function edit(application) {
        if (!application)
            return false
        editRequested(application)
        return true
    }

    property Component processFactory: Component {
        Process {
            stdout: StdioCollector {}
            stderr: StdioCollector {}
        }
    }

}
