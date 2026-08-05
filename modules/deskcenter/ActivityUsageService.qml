pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.dock

// One local activity ledger shared by future desktop cards. It records only
// desktop app identities and durations: never window titles or user content.
QtObject {
    id: service

    property var appsByDay: ({})
    property var uptimeByDay: ({})
    property bool journalSeeded: false
    property string activeAppId: ""
    property string activeAppName: ""
    property string activeAppIcon: ""
    property double lastSettledAt: Date.now()
    property var _loadProcess: null
    property var _saveProcess: null
    property var _seedProcess: null
    readonly property string statePath: Quickshell.stateDir + "/activity-usage.json"

    function dayKey(time) {
        return Qt.formatDate(new Date(time), "yyyy-MM-dd")
    }

    function addInterval(target, start, end, app) {
        let cursor = start
        while (cursor < end) {
            const date = new Date(cursor)
            const tomorrow = new Date(date)
            tomorrow.setHours(24, 0, 0, 0)
            const segmentEnd = Math.min(end, tomorrow.getTime())
            const seconds = Math.max(0, (segmentEnd - cursor) / 1000)
            const key = dayKey(cursor)
            if (app) {
                const days = Object.assign({}, appsByDay)
                const entries = Object.assign({}, days[key] ?? {})
                const old = entries[app.id] ?? { name: app.name, icon: app.icon, seconds: 0 }
                entries[app.id] = {
                    name: app.name || old.name || app.id,
                    icon: app.icon || old.icon || "",
                    seconds: old.seconds + seconds
                }
                days[key] = entries
                appsByDay = days
            } else {
                const days = Object.assign({}, uptimeByDay)
                days[key] = (Number(days[key]) || 0) + seconds
                uptimeByDay = days
            }
            cursor = segmentEnd
        }
    }

    function settle() {
        const now = Date.now()
        if (now <= lastSettledAt)
            return
        // Online time covers the awake shell session; app time is only
        // attributed while KWin reports a normal foreground window.
        addInterval(uptimeByDay, lastSettledAt, now, null)
        if (activeAppId)
            addInterval(appsByDay, lastSettledAt, now, {
                id: activeAppId, name: activeAppName, icon: activeAppIcon
            })
        lastSettledAt = now
    }

    function updateActiveApp() {
        settle()
        const record = WindowService.windowById(WindowService.activeWindowId)
        activeAppId = record?.identity?.desktopId ?? ""
        activeAppName = record?.identity?.name ?? ""
        activeAppIcon = record?.iconSource ?? ""
    }

    function todayApps() {
        const entries = appsByDay[dayKey(Date.now())] ?? {}
        return Object.keys(entries).map(id => Object.assign({ id: id }, entries[id]))
            .sort((left, right) => right.seconds - left.seconds)
    }

    function recentUptimeDays(count) {
        const result = []
        const start = new Date()
        start.setHours(0, 0, 0, 0)
        start.setDate(start.getDate() - count + 1)
        for (let i = 0; i < count; i++) {
            const date = new Date(start)
            date.setDate(start.getDate() + i)
            const key = dayKey(date.getTime())
            result.push({ key: key, seconds: Number(uptimeByDay[key]) || 0 })
        }
        return result
    }

    function save() {
        settle()
        if (_saveProcess)
            return
        const json = JSON.stringify({ appsByDay: appsByDay, uptimeByDay: uptimeByDay,
            journalSeeded: journalSeeded })
        const process = processFactory.createObject(service, {
            command: ["sh", "-c",
                "dir=$(dirname \"$1\"); mkdir -p \"$dir\" && printf '%s' \"$2\" > \"$1.tmp\" && mv \"$1.tmp\" \"$1\"",
                "activity-usage-save", statePath, json]
        })
        _saveProcess = process
        process.exited.connect(function() {
            if (service._saveProcess === process)
                service._saveProcess = null
            process.destroy()
        })
        process.running = true
    }

    function seedJournalHistory() {
        if (journalSeeded || _seedProcess)
            return
        // short-unix gives epoch timestamps without locale-dependent date
        // parsing. Seed only once; later time comes from this service.
        const process = processFactory.createObject(service, {
            command: ["sh", "-c",
                "LC_ALL=C; journalctl --list-boots --no-pager 2>/dev/null | awk 'NR <= 84 {print $1}' | while read -r boot; do journalctl -b \"$boot\" -o short-unix --no-pager 2>/dev/null | awk 'NR==1 {first=$1} {last=$1} END {gsub(/[^0-9.]/, \"\", first); gsub(/[^0-9.]/, \"\", last); if (first != \"\" && last != \"\") print first \"|\" last}'; done",
                "activity-usage-journal"]
        })
        _seedProcess = process
        process.exited.connect(function() {
            const lines = (process.stdout?.text ?? "").trim().split("\n")
            for (let i = 0; i < lines.length; i++) {
                const fields = lines[i].split("|")
                const start = Number(fields[0]) * 1000
                const end = Number(fields[1]) * 1000
                if (Number.isFinite(start) && Number.isFinite(end) && end > start)
                    addInterval(uptimeByDay, start, end, null)
            }
            journalSeeded = true
            service.save()
            if (service._seedProcess === process)
                service._seedProcess = null
            process.destroy()
        })
        process.running = true
    }

    function load() {
        const process = processFactory.createObject(service, {
            command: ["sh", "-c", "cat \"$1\" 2>/dev/null", "activity-usage-load", statePath]
        })
        _loadProcess = process
        process.exited.connect(function() {
            try {
                const saved = JSON.parse((process.stdout?.text ?? "").trim())
                appsByDay = saved.appsByDay ?? ({})
                uptimeByDay = saved.uptimeByDay ?? ({})
                journalSeeded = !!saved.journalSeeded
            } catch (_) {}
            service.seedJournalHistory()
            service.updateActiveApp()
            if (service._loadProcess === process)
                service._loadProcess = null
            process.destroy()
        })
        process.running = true
    }

    property Component processFactory: Component { Process { stdout: StdioCollector {} } }
    property Connections windowConnection: Connections {
        target: WindowService
        function onRevisionChanged() { service.updateActiveApp() }
    }
    property Timer settlementTimer: Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: service.settle()
    }
    property Timer saveTimer: Timer {
        interval: 300000
        repeat: true
        running: true
        onTriggered: service.save()
    }
    Component.onCompleted: load()
}
