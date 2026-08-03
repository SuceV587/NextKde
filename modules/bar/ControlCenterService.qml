pragma Singleton

import QtQuick
import Quickshell.Io

// Shared adapter for the first real Control Centre controls. Presentation
// components read this state only; system writes remain explicit methods here.
QtObject {
    id: service

    property bool audioAvailable: false
    property int volumePercent: 0
    property bool audioMuted: false
    property bool volumeChangeInProgress: false
    property bool bluetoothAvailable: false
    property bool bluetoothPowered: false
    property bool bluetoothChangeInProgress: false
    // Known devices are supplied as normalized { address, name, paired,
    // connected } objects so every future Bluetooth surface shares one parser.
    property var bluetoothDevices: []
    property bool bluetoothDevicesRefreshInProgress: false
    property bool bluetoothDeviceChangeInProgress: false
    property string bluetoothChangingAddress: ""
    // This is consumed by NotificationCenter. Keep the policy state in the
    // control service so future notification surfaces have one shared source.
    property bool doNotDisturbEnabled: false
    property bool screenshotInProgress: false
    property bool logoutInProgress: false
    property var _refreshProcess: null

    function refresh() {
        if (_refreshProcess)
            return
        const proc = processFactory.createObject(service, {
            command: ["sh", "-c",
                "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null; "
                    + "printf '\\036'; bluetoothctl show 2>/dev/null",
                "control-center-refresh"]
        })
        _refreshProcess = proc
        proc.exited.connect(function(code) {
            if (service._refreshProcess === proc)
                service._refreshProcess = null
            const parts = (proc.stdout?.text ?? "").split("\u001e")
            const volumeMatch = (parts[0] || "").match(/Volume:\s*([0-9.]+)/)
            service.audioAvailable = volumeMatch !== null
            if (volumeMatch)
                service.volumePercent = Math.round(Math.max(0,
                    Math.min(100, Number(volumeMatch[1]) * 100)))
            service.audioMuted = (parts[0] || "").indexOf("[MUTED]") >= 0
            const poweredMatch = (parts[1] || "").match(/Powered:\s*(yes|no)/i)
            service.bluetoothAvailable = poweredMatch !== null
            if (poweredMatch)
                service.bluetoothPowered = poweredMatch[1].toLowerCase() === "yes"
            proc.destroy()
        })
        proc.running = true
    }

    function setVolume(percent) {
        const value = Math.round(Math.max(0, Math.min(100, Number(percent) || 0)))
        if (!audioAvailable || volumeChangeInProgress)
            return false
        volumeChangeInProgress = true
        const proc = processFactory.createObject(service, {
            command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", String(value / 100)]
        })
        proc.exited.connect(function(code) {
            service.volumeChangeInProgress = false
            if (code === 0)
                service.volumePercent = value
            service.refresh()
            proc.destroy()
        })
        proc.running = true
        return true
    }

    // Mute is intentionally a separate operation from setting volume to 0.
    // That preserves the user's chosen volume and mirrors normal desktop
    // control-centre behaviour when the button is tapped a second time.
    function setMuted(muted) {
        const desired = Boolean(muted)
        if (!audioAvailable || volumeChangeInProgress || desired === audioMuted)
            return false
        volumeChangeInProgress = true
        const proc = processFactory.createObject(service, {
            command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", desired ? "1" : "0"]
        })
        proc.exited.connect(function(code) {
            service.volumeChangeInProgress = false
            if (code === 0)
                service.audioMuted = desired
            service.refresh()
            proc.destroy()
        })
        proc.running = true
        return true
    }

    function setBluetoothEnabled(enabled) {
        const desired = Boolean(enabled)
        if (!bluetoothAvailable || bluetoothChangeInProgress || desired === bluetoothPowered)
            return false
        bluetoothChangeInProgress = true
        const proc = processFactory.createObject(service, {
            command: ["bluetoothctl", "power", desired ? "on" : "off"]
        })
        proc.exited.connect(function(code) {
            service.bluetoothChangeInProgress = false
            if (code === 0)
                service.bluetoothPowered = desired
            service.refresh()
            service.refreshBluetoothDevices()
            proc.destroy()
        })
        proc.running = true
        return true
    }

    function _parseBluetoothDevices(allOutput, connectedOutput, pairedOutput) {
        function parseBlock(output) {
            const devices = []
            const lines = String(output || "").split("\n")
            for (let i = 0; i < lines.length; i++) {
                const match = lines[i].match(/^Device\s+([0-9A-F:]{17})\s+(.+)$/i)
                if (match)
                    devices.push({ address: match[1].toUpperCase(), name: match[2].trim() })
            }
            return devices
        }
        const connected = parseBlock(connectedOutput)
        const paired = parseBlock(pairedOutput)
        const connectedAddresses = connected.map(device => device.address)
        const pairedAddresses = paired.map(device => device.address)
        const source = parseBlock(allOutput).concat(paired)
        const seen = {}
        const normalized = []
        for (let i = 0; i < source.length; i++) {
            const device = source[i]
            if (seen[device.address])
                continue
            seen[device.address] = true
            normalized.push({
                address: device.address,
                name: device.name || device.address,
                paired: pairedAddresses.indexOf(device.address) >= 0,
                connected: connectedAddresses.indexOf(device.address) >= 0
            })
        }
        normalized.sort((left, right) => Number(right.connected) - Number(left.connected)
            || Number(right.paired) - Number(left.paired) || left.name.localeCompare(right.name))
        return normalized
    }

    function refreshBluetoothDevices() {
        if (bluetoothDevicesRefreshInProgress || !bluetoothPowered)
            return
        bluetoothDevicesRefreshInProgress = true
        const proc = processFactory.createObject(service, {
            command: ["sh", "-c", "bluetoothctl devices; printf '\\036'; bluetoothctl devices Connected; printf '\\036'; bluetoothctl devices Paired"]
        })
        proc.exited.connect(function() {
            const parts = (proc.stdout?.text ?? "").split("\u001e")
            service.bluetoothDevices = service._parseBluetoothDevices(parts[0], parts[1], parts[2])
            service.bluetoothDevicesRefreshInProgress = false
            proc.destroy()
        })
        proc.running = true
    }

    function setBluetoothDeviceConnected(device, connected) {
        if (!device || !device.address || bluetoothDeviceChangeInProgress)
            return false
        bluetoothDeviceChangeInProgress = true
        bluetoothChangingAddress = device.address
        const proc = processFactory.createObject(service, {
            command: ["bluetoothctl", connected ? "connect" : "disconnect", device.address]
        })
        proc.exited.connect(function() {
            service.bluetoothDeviceChangeInProgress = false
            service.bluetoothChangingAddress = ""
            service.refreshBluetoothDevices()
            proc.destroy()
        })
        proc.running = true
        return true
    }

    // Spectacle's region mode lets the user choose the capture area after
    // tapping the shortcut, which is safer and more useful than silently
    // saving an arbitrary full-screen image.
    function captureInteractiveScreenshot() {
        if (screenshotInProgress)
            return false
        screenshotInProgress = true
        const proc = processFactory.createObject(service, {
            command: ["spectacle", "-r"]
        })
        proc.exited.connect(function() {
            service.screenshotInProgress = false
            proc.destroy()
        })
        proc.running = true
        return true
    }

    // This command runs only after an explicit click on the logout shortcut.
    // Terminating the current logind session returns the user to their display
    // manager without trying to guess a compositor-specific exit command.
    function logoutCurrentSession() {
        if (logoutInProgress)
            return false
        logoutInProgress = true
        const proc = processFactory.createObject(service, {
            command: ["sh", "-c", "loginctl terminate-session \"$XDG_SESSION_ID\""]
        })
        proc.exited.connect(function() {
            service.logoutInProgress = false
            proc.destroy()
        })
        proc.running = true
        return true
    }

    function toggleDoNotDisturb() {
        doNotDisturbEnabled = !doNotDisturbEnabled
        return doNotDisturbEnabled
    }

    property Component processFactory: Component {
        Process {
            stdout: StdioCollector {}
            stderr: StdioCollector {}
        }
    }
    property Timer refreshTimer: Timer {
        interval: 3000; repeat: true; running: true
        onTriggered: service.refresh()
    }
    Component.onCompleted: refresh()
}
