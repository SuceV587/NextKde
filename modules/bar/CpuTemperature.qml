import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.dock

// Compact CPU thermal indicator. Kernel thermal zones are reported in
// millidegrees Celsius, so the sampler filters CPU/package zones and averages
// their raw readings before presenting a rounded Celsius value.
Item {
    id: root

    property real averageMilliC: -1
    property real maximumMilliC: -1
    property var peakSamples: []
    property var _refreshProcess: null

    readonly property int sampleIntervalMs: 5000
    readonly property int peakWindowSeconds: 60
    readonly property int peakSampleLimit: peakWindowSeconds * 1000 / sampleIntervalMs
    readonly property bool available: averageMilliC >= 0 && maximumMilliC >= 0
    readonly property int averageC: Math.round(averageMilliC / 1000)
    readonly property int maximumC: Math.round(maximumMilliC / 1000)

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
                + "[ \"$count\" -gt 0 ] && printf '%s %s\\n' $((sum / count)) \"$maximum\"",
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
            } else {
                root.averageMilliC = -1
                root.maximumMilliC = -1
                root.peakSamples = []
            }
            proc.destroy()
        })
        proc.running = true
    }

    Row {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
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

            Text {
                text: "平均温度 " + root.averageC + "°"
                color: ThemeService.foregroundColor
                font {
                    family: "SF Pro Display"
                    pixelSize: 9
                    weight: Font.Normal
                }
            }

            Text {
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
    }

    PopupWindow {
        visible: hoverArea.containsMouse && root.available
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

    Component {
        id: processFactory
        Process {
            stdout: StdioCollector {}
            stderr: StdioCollector {}
        }
    }

    Timer {
        interval: root.sampleIntervalMs
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
