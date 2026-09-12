pragma Singleton
import QtQuick
import Quickshell

// Keeps output-bound windows away from Qt's synthetic placeholder screen.
// During suspend/resume the compositor may briefly publish no real outputs;
// retain the last real screen reference and hide surfaces until a valid output
// is available again instead of rebinding every PanelWindow to the placeholder.
QtObject {
    id: service

    property var activeScreen: null
    property bool outputAvailable: false

    function _isUsableScreen(screen) {
        return screen !== null
            && screen !== undefined
            && String(screen.name || "").length > 0
            && Number(screen.width) > 0
            && Number(screen.height) > 0
    }

    function _usableScreens() {
        const result = []
        const screens = Quickshell.screens
        for (let index = 0; index < screens.length; ++index) {
            if (_isUsableScreen(screens[index]))
                result.push(screens[index])
        }
        return result
    }

    function refresh() {
        const screens = _usableScreens()
        let nextScreen = null

        // 1. 优先精准匹配主屏幕名称（如用户的中间主显示器 DP-1）
        for (let i = 0; i < screens.length; ++i) {
            if (screens[i].name === "DP-1") {
                nextScreen = screens[i]
                break
            }
        }

        // 2. 若未匹配到指定名称且存在多屏环境：
        // 自动过滤笔记本内置屏幕 (eDP)，并对外部显示器按水平物理坐标排序，选取居中的主屏
        if (!nextScreen && screens.length > 0) {
            const externalScreens = screens.filter(function(s) {
                return !String(s.name || "").startsWith("eDP")
            })
            if (externalScreens.length > 0) {
                const sorted = externalScreens.slice().sort(function(a, b) {
                    return Number(a.x || 0) - Number(b.x || 0)
                })
                const midIndex = Math.floor(sorted.length / 2)
                nextScreen = sorted[midIndex]
            }
        }

        // 3. 保底 fallback：当只有单个显示器或仅有内置屏时回退到首个可用屏幕
        if (!nextScreen && screens.length > 0) {
            nextScreen = screens[0]
        }

        outputAvailable = nextScreen !== null
        if (nextScreen !== null) {
            console.log("[ScreenLifecycle] selected activeScreen:", nextScreen.name, "geometry:", nextScreen.x, nextScreen.y, nextScreen.width, nextScreen.height)
            activeScreen = nextScreen
        }
    }

    function refreshAndSettle() {
        // Hide all output-bound surfaces before Qt tears down/recreates its
        // QScreen objects, then drop the wrapper before its QObject destructor
        // can notify bindings that still reach into a QQuickWindow item tree.
        outputAvailable = false
        activeScreen = null
        settleTimer.restart()
    }

    property Connections screenConnections: Connections {
        target: Quickshell
        function onScreensChanged() { service.refreshAndSettle() }
    }

    property Timer settleTimer: Timer {
        interval: 300
        repeat: false
        onTriggered: service.refresh()
    }

    Component.onCompleted: refresh()
}
