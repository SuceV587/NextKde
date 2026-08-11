import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.dock
import qs.modules.common

// Compact CPU thermal indicator. Kernel thermal zones are reported in
// millidegrees Celsius, so the sampler filters CPU/package zones and averages
// their raw readings before presenting a rounded Celsius value.
Item {
    id: root

    property real averageMilliC: -1
    property real maximumMilliC: -1
    property var peakSamples: []
    property var sensorReadings: []
    property real memoryUsedBytes: 0
    property real memoryTotalBytes: 0
    property real diskUsedBytes: 0
    property real diskTotalBytes: 0
    property var memoryHistory: []
    property var cpuHistory: []
    property var cpuFrequencyHistory: []
    property real cpuUsage: 0
    property real cpuFrequencyMhz: 0
    property real _lastCpuTotal: -1
    property real _lastCpuIdle: -1
    property var _refreshProcess: null
    property var _historyLoadProcess: null
    property var _historySaveProcess: null
    property bool historyLoaded: false

    // Thermal and usage values change slowly at idle. Sampling every ten
    // seconds halves process launches without making the bar feel stale.
    readonly property int sampleIntervalMs: 10000
    readonly property int peakWindowSeconds: 60
    readonly property int peakSampleLimit: peakWindowSeconds * 1000 / sampleIntervalMs
    readonly property int historySampleLimit: 60 * 60 * 1000 / sampleIntervalMs
    readonly property int historyWindowMs: 60 * 60 * 1000
    readonly property string historyPath: Quickshell.stateDir + "/bar/usage-history.json"
    readonly property bool available: averageMilliC >= 0 && maximumMilliC >= 0
    readonly property int averageC: Math.round(averageMilliC / 1000)
    readonly property int maximumC: Math.round(maximumMilliC / 1000)
    readonly property real memoryUsage: memoryTotalBytes > 0 ? memoryUsedBytes / memoryTotalBytes : 0
    readonly property real diskUsage: diskTotalBytes > 0 ? diskUsedBytes / diskTotalBytes : 0

    implicitWidth: available ? content.implicitWidth : 0
    implicitHeight: 20
    width: implicitWidth
    height: implicitHeight
    visible: available

    // Keep one raw maximum from each sample. `maximumMilliC` is deliberately
    // a short rolling peak, rather than the maximum of only this instant.
    function recordPeakSample(value) {
        const samples = peakSamples.slice(-(peakSampleLimit - 1))
        samples.push(value)
        peakSamples = samples

        let peak = samples[0]
        for (let i = 1; i < samples.length; i++)
            peak = Math.max(peak, samples[i])
        return peak
    }

    function updateSensorReadings(output) {
        const readings = []
        const lines = output.trim().split("\n")
        for (let i = 0; i < lines.length; i++) {
            const fields = lines[i].split("|")
            if (fields.length !== 4 || (fields[0] !== "hwmon" && fields[0] !== "thermal"))
                continue

            const milliC = Number(fields[3])
            if (!Number.isFinite(milliC) || milliC <= 0)
                continue

            readings.push({
                source: fields[0],
                device: fields[1],
                label: fields[2],
                milliC: milliC
            })
        }
        sensorReadings = readings
    }

    function recordUsageSample(samples, value) {
        const now = Date.now()
        const cutoff = now - historyWindowMs
        const next = []
        for (let i = 0; i < samples.length; i++) {
            const sample = samples[i]
            if (sample && Number.isFinite(sample.time) && Number.isFinite(sample.value)
                    && sample.time >= cutoff)
                next.push(sample)
        }
        next.push({ time: now, value: value })
        return next.slice(-historySampleLimit)
    }

    function normalizedHistory(raw, maximum) {
        const cutoff = Date.now() - historyWindowMs
        const samples = Array.isArray(raw) ? raw : []
        const max = maximum ?? 1
        const next = []
        for (let i = 0; i < samples.length; i++) {
            const sample = samples[i]
            if (sample && Number.isFinite(sample.time) && Number.isFinite(sample.value)
                    && sample.time >= cutoff && sample.value >= 0 && sample.value <= max)
                next.push({ time: sample.time, value: sample.value })
        }
        return next.slice(-historySampleLimit)
    }

    function historyValues(samples) {
        return samples.map(sample => sample.value)
    }

    function scheduleHistorySave() {
        // Coalesce periodic writes without postponing them indefinitely: a
        // restart-on-every-sample debounce would never fire while the bar is
        // active. This caps state-directory writes at two per minute.
        if (!historySaveTimer.running)
            historySaveTimer.start()
    }

    function loadHistory() {
        const proc = processFactory.createObject(root, {
            command: ["sh", "-c", "cat \"$1\"", "bar-usage-history-load", historyPath]
        })
        _historyLoadProcess = proc
        proc.exited.connect(function() {
            try {
                const saved = JSON.parse((proc.stdout?.text ?? "").trim())
                memoryHistory = normalizedHistory(saved.memory)
                cpuHistory = normalizedHistory(saved.cpu)
                cpuFrequencyHistory = normalizedHistory(saved.frequency, 10000)
            } catch (_) {
                // A missing or malformed cache is equivalent to no history.
            }
            historyLoaded = true
            scheduleHistorySave()
            refresh()
            proc.destroy()
            _historyLoadProcess = null
        })
        proc.running = true
    }

    function saveHistory() {
        if (!historyLoaded || _historySaveProcess)
            return
        // This file is also the lightweight hand-off for desktop widgets.
        // Keeping the current values next to the already-persisted history
        // means DeskCenter never needs its own /proc polling process.
        const json = JSON.stringify({
            memory: memoryHistory,
            cpu: cpuHistory,
            frequency: cpuFrequencyHistory,
            current: {
                cpuUsage: cpuUsage,
                cpuFrequencyMhz: cpuFrequencyMhz,
                averageMilliC: averageMilliC,
                maximumMilliC: maximumMilliC,
                memoryUsedBytes: memoryUsedBytes,
                memoryTotalBytes: memoryTotalBytes,
                diskUsedBytes: diskUsedBytes,
                diskTotalBytes: diskTotalBytes
            }
        })
        const proc = processFactory.createObject(root, {
            command: [
                "sh", "-c",
                "dir=$(dirname \"$1\"); mkdir -p \"$dir\" && printf '%s' \"$2\" > \"$1.tmp\" && mv \"$1.tmp\" \"$1\"",
                "bar-usage-history-save", historyPath, json
            ]
        })
        _historySaveProcess = proc
        proc.exited.connect(function() {
            if (root._historySaveProcess === proc)
                root._historySaveProcess = null
            proc.destroy()
        })
        proc.running = true
    }

    function updateUsage(output) {
        const lines = output.trim().split("\n")
        for (let i = 0; i < lines.length; i++) {
            const fields = lines[i].split("|")
            if (fields.length !== 4 || fields[0] !== "usage")
                continue

            const primary = Number(fields[2])
            const secondary = Number(fields[3])
            if (!Number.isFinite(primary) || !Number.isFinite(secondary))
                continue
            if (fields[1] === "cpu") {
                const elapsed = primary - _lastCpuTotal
                const idleElapsed = secondary - _lastCpuIdle
                if (_lastCpuTotal >= 0 && elapsed > 0) {
                    cpuUsage = Math.max(0, Math.min(1, 1 - idleElapsed / elapsed))
                    cpuHistory = recordUsageSample(cpuHistory, cpuUsage)
                    scheduleHistorySave()
                }
                _lastCpuTotal = primary
                _lastCpuIdle = secondary
            } else if (fields[1] === "frequency") {
                cpuFrequencyMhz = primary
                cpuFrequencyHistory = recordUsageSample(cpuFrequencyHistory, primary)
                scheduleHistorySave()
            } else if (secondary <= 0) {
                continue
            } else if (fields[1] === "memory") {
                const used = primary
                const total = secondary
                memoryUsedBytes = used
                memoryTotalBytes = total
                memoryHistory = recordUsageSample(memoryHistory, used / total)
                scheduleHistorySave()
            } else if (fields[1] === "disk") {
                const used = primary
                const total = secondary
                diskUsedBytes = used
                diskTotalBytes = total
            }
        }
    }

    function formatBytes(value) {
        if (value >= 1073741824)
            return (value / 1073741824).toFixed(1) + " GiB"
        if (value >= 1048576)
            return (value / 1048576).toFixed(0) + " MiB"
        return Math.round(value / 1024) + " KiB"
    }

    function publishSharedMetrics() {
        SystemMetricsService.publish({
            averageMilliC: averageMilliC,
            maximumMilliC: maximumMilliC,
            cpuUsage: cpuUsage,
            cpuFrequencyMhz: cpuFrequencyMhz,
            memoryUsedBytes: memoryUsedBytes,
            memoryTotalBytes: memoryTotalBytes,
            diskUsedBytes: diskUsedBytes,
            diskTotalBytes: diskTotalBytes,
            memoryHistory: memoryHistory,
            cpuHistory: cpuHistory,
            frequencyHistory: cpuFrequencyHistory
        })
    }

    function refresh() {
        if (_refreshProcess)
            return

        const proc = processFactory.createObject(root, {
            command: [
                "sh", "-c",
                "sum=0; count=0; maximum=0; "
                + "for zone in /sys/class/thermal/thermal_zone*; do "
                + "[ -r \"$zone/type\" ] && [ -r \"$zone/temp\" ] || continue; "
                + "kind=$(cat \"$zone/type\" 2>/dev/null); "
                + "case \"$kind\" in *[Cc][Pp][Uu]*|*[Pp][Kk][Gg]*) "
                + "value=$(cat \"$zone/temp\" 2>/dev/null); "
                + "case \"$value\" in ''|*[!0-9]*) ;; *) sum=$((sum + value)); count=$((count + 1)); [ \"$value\" -gt \"$maximum\" ] && maximum=$value;; esac;; "
                + "esac; done; "
                + "[ \"$count\" -gt 0 ] && printf '%s %s\\n' $((sum / count)) \"$maximum\""
                + "; for hwmon in /sys/class/hwmon/hwmon*; do "
                + "[ -r \"$hwmon/name\" ] || continue; device=$(cat \"$hwmon/name\" 2>/dev/null); "
                + "for input in \"$hwmon\"/temp*_input; do [ -r \"$input\" ] || continue; "
                + "index=${input##*/temp}; index=${index%_input}; labelFile=\"$hwmon/temp${index}_label\"; "
                + "label=$(cat \"$labelFile\" 2>/dev/null); [ -n \"$label\" ] || label=\"Temperature $index\"; "
                + "value=$(cat \"$input\" 2>/dev/null); case \"$value\" in ''|*[!0-9]*) ;; *) printf 'hwmon|%s|%s|%s\\n' \"$device\" \"$label\" \"$value\";; esac; done; done "
                + "; for zone in /sys/class/thermal/thermal_zone*; do [ -r \"$zone/type\" ] && [ -r \"$zone/temp\" ] || continue; "
                + "label=$(cat \"$zone/type\" 2>/dev/null); value=$(cat \"$zone/temp\" 2>/dev/null); "
                + "case \"$value\" in ''|*[!0-9]*) ;; *) printf 'thermal|kernel|%s|%s\\n' \"$label\" \"$value\";; esac; done "
                + "; memTotal=$(awk '/^MemTotal:/ { print $2 * 1024 }' /proc/meminfo); memAvailable=$(awk '/^MemAvailable:/ { print $2 * 1024 }' /proc/meminfo); "
                + "[ -n \"$memTotal\" ] && [ -n \"$memAvailable\" ] && printf 'usage|memory|%s|%s\\n' $((memTotal - memAvailable)) \"$memTotal\" "
                + "; awk '/^cpu / { idle = $5 + $6; total = 0; for (i = 2; i <= NF; i++) total += $i; printf \"usage|cpu|%.0f|%.0f\\n\", total, idle }' /proc/stat "
                + "; sum=0; count=0; for policy in /sys/devices/system/cpu/cpufreq/policy*; do value=$(cat \"$policy/scaling_cur_freq\" 2>/dev/null); case \"$value\" in ''|*[!0-9]*) ;; *) sum=$((sum + value)); count=$((count + 1));; esac; done; "
                + "if [ \"$count\" -gt 0 ]; then printf 'usage|frequency|%s|%s\\n' $((sum / count / 1000)) \"$count\"; else awk '/^cpu MHz/ { sum += $4; count++ } END { if (count) printf \"usage|frequency|%.0f|%d\\n\", sum / count, count }' /proc/cpuinfo; fi "
                + "; df -B1 / 2>/dev/null | awk 'NR == 2 { printf \"usage|disk|%s|%s\\n\", $3, $2 }'",
                "bar-cpu-temperature"
            ]
        })
        _refreshProcess = proc
        proc.exited.connect(function(code) {
            if (root._refreshProcess === proc)
                root._refreshProcess = null
            const readings = (proc.stdout?.text ?? "").trim().split(/\s+/)
            const average = Number(readings[0])
            const maximum = Number(readings[1])
            if (code === 0 && Number.isFinite(average) && average > 0
                    && Number.isFinite(maximum) && maximum > 0) {
                root.averageMilliC = average
                root.maximumMilliC = root.recordPeakSample(maximum)
                root.updateSensorReadings(proc.stdout?.text ?? "")
                root.updateUsage(proc.stdout?.text ?? "")
                root.publishSharedMetrics()
            } else {
                root.averageMilliC = -1
                root.maximumMilliC = -1
                root.peakSamples = []
                root.sensorReadings = []
                root.memoryHistory = []
                root.cpuHistory = []
                root.cpuFrequencyHistory = []
                root._lastCpuTotal = -1
                root._lastCpuIdle = -1
                root.publishSharedMetrics()
            }
            proc.destroy()
        })
        proc.running = true
    }

    Row {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        GlassText {
            text: ""
            color: ThemeService.foregroundColor
            font {
                family: "LXGW WenKai Mono Nerd Font"
                pixelSize: 17
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            spacing: -1
            anchors.verticalCenter: parent.verticalCenter

            GlassText {
                text: "平均温度 " + root.averageC + "°"
                color: ThemeService.foregroundColor
                font {
                    family: "SF Pro Display"
                    pixelSize: 9
                    weight: Font.Normal
                }
            }

            GlassText {
                text: "最高温度 " + root.maximumC + "°"
                color: ThemeService.foregroundColor
                font {
                    family: "SF Pro Display"
                    pixelSize: 9
                    weight: Font.Normal
                }
            }
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: detailsPopup.visible = !detailsPopup.visible
    }

    PopupWindow {
        visible: hoverArea.containsMouse && root.available && !detailsPopup.visible
        implicitWidth: tooltipText.implicitWidth + 16
        implicitHeight: tooltipText.implicitHeight + 10
        color: "transparent"
        anchor {
            item: root
            edges: Edges.Bottom
            gravity: Edges.Bottom
            margins.bottom: -6
        }

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: ThemeService.tooltipBackground

            Text {
                id: tooltipText
                anchors.centerIn: parent
                text: "CPU 平均 " + root.averageC + "°C · 60 秒最高 " + root.maximumC + "°C"
                color: ThemeService.foregroundColor
                font {
                    family: "Noto Sans CJK SC"
                    pixelSize: 12
                    weight: Font.DemiBold
                }
            }
        }
    }

    // A click opens the persistent, iStat-style sensor dashboard. Hover still
    // keeps the compact one-line tooltip for a quick glance.
    PopupWindow {
        id: detailsPopup
        visible: false
        implicitWidth: 360
        implicitHeight: 670
        color: "transparent"
        anchor {
            item: root
            edges: Edges.Bottom
            gravity: Edges.Bottom
            margins.bottom: -6
        }

        LiquidGlassSurface {
            id: detailsSurface
            anchors.fill: parent
            radius: 16
            // The blur region below supplies the real backdrop blur; this
            // richer translucent material adds the specular glass finish.
            baseColor: ThemeService.isDark
                ? Qt.rgba(0.04, 0.05, 0.07, 0.72)
                : Qt.rgba(0.94, 0.95, 0.98, 0.68)
            surfaceOpacity: 0.96
            materialDepth: 1.8

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Row {
                    width: parent.width

                    Column {
                        width: parent.width - closeButton.width
                        spacing: 2

                        GlassText {
                            text: "温度传感器"
                            color: ThemeService.foregroundColor
                            font { family: "Noto Sans CJK SC"; pixelSize: 16; weight: Font.DemiBold }
                        }

                        GlassText {
                            text: "每 " + root.sampleIntervalMs / 1000 + " 秒更新 · " + root.sensorReadings.length + " 个读数"
                            color: Qt.rgba(ThemeService.foregroundColor.r, ThemeService.foregroundColor.g, ThemeService.foregroundColor.b, 0.62)
                            font { family: "Noto Sans CJK SC"; pixelSize: 11 }
                        }
                    }

                    Rectangle {
                        id: closeButton
                        width: 24
                        height: 24
                        radius: width / 2
                        color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"

                        GlassText {
                            anchors.centerIn: parent
                            text: "×"
                            color: ThemeService.foregroundColor
                            font.pixelSize: 20
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: detailsPopup.visible = false
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.12) }

                Row {
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: [
                            { label: "平均 CPU", value: root.averageC + "°C" },
                            { label: "60 秒最高", value: root.maximumC + "°C" }
                        ]
                        delegate: Rectangle {
                            width: (parent.width - 8) / 2
                            height: 55
                            radius: 8
                            color: Qt.rgba(1, 1, 1, 0.08)
                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                GlassText { text: modelData.label; color: Qt.rgba(ThemeService.foregroundColor.r, ThemeService.foregroundColor.g, ThemeService.foregroundColor.b, 0.65); font.pixelSize: 11 }
                                GlassText { text: modelData.value; color: ThemeService.foregroundColor; font { pixelSize: 19; weight: Font.DemiBold } }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 8

                    UsageRing {
                        width: (parent.width - 8) / 2
                        label: "内存"
                        detail: root.formatBytes(root.memoryUsedBytes) + " / " + root.formatBytes(root.memoryTotalBytes)
                        value: root.memoryUsage
                        accentColor: "#5e5ce6"
                    }
                    UsageRing {
                        width: (parent.width - 8) / 2
                        label: "磁盘 /"
                        detail: root.formatBytes(root.diskUsedBytes) + " / " + root.formatBytes(root.diskTotalBytes)
                        value: root.diskUsage
                        accentColor: "#30d158"
                    }
                }

                Row {
                    width: parent.width
                    spacing: 12

                    Column {
                        width: (parent.width - 12) / 2
                        spacing: 3
                        GlassText {
                            text: "内存趋势 · 最近 " + root.memoryHistory.length * root.sampleIntervalMs / 1000 + " 秒"
                            color: Qt.rgba(ThemeService.foregroundColor.r, ThemeService.foregroundColor.g, ThemeService.foregroundColor.b, 0.62)
                            font { family: "Noto Sans CJK SC"; pixelSize: 10 }
                        }
                        UsageSparkline { width: parent.width; values: root.historyValues(root.memoryHistory); lineColor: "#5e5ce6"; adaptiveRange: true }
                    }
                    Column {
                        width: (parent.width - 12) / 2
                        spacing: 3
                        GlassText {
                            text: "CPU 趋势 · " + Math.round(root.cpuUsage * 100) + "% · 最近 " + root.cpuHistory.length * root.sampleIntervalMs / 1000 + " 秒"
                            color: Qt.rgba(ThemeService.foregroundColor.r, ThemeService.foregroundColor.g, ThemeService.foregroundColor.b, 0.62)
                            font { family: "Noto Sans CJK SC"; pixelSize: 10 }
                        }
                        UsageSparkline { width: parent.width; values: root.historyValues(root.cpuHistory); lineColor: "#ff9f0a" }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 3
                    GlassText {
                        text: "CPU 平均频率 · " + Math.round(root.cpuFrequencyMhz) + " MHz · 最近 " + root.cpuFrequencyHistory.length * root.sampleIntervalMs / 1000 + " 秒"
                        color: Qt.rgba(ThemeService.foregroundColor.r, ThemeService.foregroundColor.g, ThemeService.foregroundColor.b, 0.62)
                        font { family: "Noto Sans CJK SC"; pixelSize: 10 }
                    }
                    UsageSparkline {
                        width: parent.width
                        values: root.historyValues(root.cpuFrequencyHistory)
                        lineColor: "#64d2ff"
                        adaptiveRange: true
                    }
                }

                GlassText {
                    text: "实时读数"
                    color: ThemeService.foregroundColor
                    font { family: "Noto Sans CJK SC"; pixelSize: 12; weight: Font.DemiBold }
                }

                ListView {
                    width: parent.width
                    height: parent.height - y
                    clip: true
                    model: root.sensorReadings
                    spacing: 2
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: 38
                        radius: 6
                        color: index % 2 ? "transparent" : Qt.rgba(1, 1, 1, 0.045)
                        GlassText {
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            width: parent.width - valueText.width - 28
                            elide: Text.ElideRight
                            text: modelData.device + " · " + modelData.label
                            color: ThemeService.foregroundColor
                            font { family: "Noto Sans CJK SC"; pixelSize: 12 }
                        }
                        GlassText {
                            id: valueText
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: (modelData.milliC / 1000).toFixed(1) + "°C"
                            color: modelData.milliC >= 85000 ? "#ff453a" : modelData.milliC >= 70000 ? "#ff9f0a" : ThemeService.foregroundColor
                            font { family: "SF Pro Display"; pixelSize: 13; weight: Font.DemiBold }
                        }
                    }
                }
            }
        }

        BackgroundEffect.blurRegion: RoundedBlurRegion {
            item: detailsSurface
            radius: detailsSurface.radius
        }
    }

    Component {
        id: processFactory
        Process {
            stdout: StdioCollector {}
            stderr: StdioCollector {}
        }
    }

    Timer {
        id: historySaveTimer
        interval: 30000
        repeat: false
        onTriggered: root.saveHistory()
    }

    Timer {
        interval: root.sampleIntervalMs
        repeat: true
        running: root.historyLoaded
        onTriggered: root.refresh()
    }

    Component.onCompleted: loadHistory()
}
