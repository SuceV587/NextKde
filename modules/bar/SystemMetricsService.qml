pragma Singleton

import QtQuick

// The Bar owns sampling. Other surfaces consume this exact in-memory snapshot
// so their values never drift behind the Bar's cached on-disk hand-off.
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
    property var memoryHistory: []
    property var cpuHistory: []
    property var frequencyHistory: []

    function publish(snapshot) {
        averageMilliC = snapshot.averageMilliC
        maximumMilliC = snapshot.maximumMilliC
        cpuUsage = snapshot.cpuUsage
        cpuFrequencyMhz = snapshot.cpuFrequencyMhz
        memoryUsedBytes = snapshot.memoryUsedBytes
        memoryTotalBytes = snapshot.memoryTotalBytes
        diskUsedBytes = snapshot.diskUsedBytes
        diskTotalBytes = snapshot.diskTotalBytes
        memoryHistory = snapshot.memoryHistory
        cpuHistory = snapshot.cpuHistory
        frequencyHistory = snapshot.frequencyHistory
        ready = true
    }
}
