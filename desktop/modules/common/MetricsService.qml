pragma Singleton

import QtQuick
import Quickshell.Io

// The Bar's thermal indicator and the DeskCenter system card both consume the
// shell-data-service metrics snapshot through this singleton, so neither QML
// surface polls /proc or /sys and their values can never drift apart. The Go
// service owns sampling, history, and sensor enumeration; this file only
// reads the atomic snapshot and reformats it for the two views.
QtObject {
    id: service

    property bool ready: false
    property real averageMilliC: -1
    property real maximumMilliC: -1
    property real cpuUsage: 0
    property real cpuFrequencyMhz: 0
    property real memoryUsedBytes: 0
    property real memoryTotalBytes: 0
    property real diskUsedBytes: 0
    property real diskTotalBytes: 0
    property var sensors: []
    property var memoryHistory: []
    property var cpuHistory: []
    property var frequencyHistory: []
    readonly property var memoryHistoryValues: historyValues(memoryHistory)
    readonly property var cpuHistoryValues: historyValues(cpuHistory)
    readonly property var frequencyHistoryValues: historyValues(frequencyHistory)
    property var _readProcess: null

    function historyValues(samples) {
        return samples.map(sample => sample.value)
    }

    // Keep the same ten-second cadence as the service sampler with a little
    // slack so the reloads never synchronize with its writes.
    property Timer refreshTimer: Timer {
        interval: 10000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: service.reload()
    }

    function reload() {
        if (_readProcess)
            return
        const process = processFactory.createObject(service, {
            command: ["sh", "-c",
                "state=${XDG_STATE_HOME:-$HOME/.local/state}; cat \"$state/quickshell/shell-data-service/snapshot.json\" 2>/dev/null",
                "metrics-snapshot"]
        })
        _readProcess = process
        process.exited.connect(function() {
            try {
                const snapshot = JSON.parse((process.stdout?.text ?? "").trim())
                const metrics = snapshot.metrics ?? {}
                averageMilliC = Number(metrics.averageMilliC ?? -1)
                maximumMilliC = Number(metrics.maximumMilliC ?? -1)
                cpuUsage = Number(metrics.cpu ?? 0)
                cpuFrequencyMhz = Number(metrics.frequencyMhz ?? 0)
                memoryUsedBytes = Number(metrics.memoryUsedBytes ?? 0)
                memoryTotalBytes = Number(metrics.memoryTotalBytes ?? 0)
                diskUsedBytes = Number(metrics.diskUsedBytes ?? 0)
                diskTotalBytes = Number(metrics.diskTotalBytes ?? 0)
                sensors = Array.isArray(metrics.sensors) ? metrics.sensors : []
                memoryHistory = normalized(metrics.history, sample => sample.memory)
                cpuHistory = normalized(metrics.history, sample => sample.cpu)
                frequencyHistory = normalized(metrics.history, sample => sample.frequency)
                ready = true
            } catch (_) {
                // The service has not been installed or written its first
                // snapshot yet. Keep the previous values and the callers'
                // availability fallbacks.
            }
            if (service._readProcess === process)
                service._readProcess = null
            process.destroy()
        })
        process.running = true
    }

    // History samples older than one hour or outside 0..1 are dropped; the
    // trend charts only need the recent window the service retains.
    function normalized(history, pick) {
        const cutoff = Date.now() - 60 * 60 * 1000
        const result = []
        const samples = Array.isArray(history) ? history : []
        for (let i = 0; i < samples.length; i++) {
            const sample = samples[i]
            const at = Number(sample?.at ?? 0)
            const value = Number(sample ? pick(sample) : 0)
            if (at >= cutoff && Number.isFinite(value) && value >= 0 && value <= 1)
                result.push({ time: at, value: value })
        }
        return result
    }

    property Component processFactory: Component {
        Process {
            stdout: StdioCollector {}
            stderr: StdioCollector {}
        }
    }

    Component.onCompleted: reload()
}
