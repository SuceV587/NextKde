import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.applauncher
import qs.modules.bar
import qs.modules.dock
import qs.modules.weather

// iPadOS-inspired desktop widgets. This is a Background layer: normal and
// maximised application windows are always painted and interacted with above
// it, and it reserves no usable desktop area.
PanelWindow {
    id: root

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Background

    anchors { top: true; left: true; right: true; bottom: true }
    implicitWidth: screen?.width ?? 1920
    implicitHeight: screen?.height ?? 1080

    // Ten square units are derived exclusively from screen width. Every
    // widget uses integer spans, giving desktop cards the intentional, large
    // iPadOS scale rather than a collection of small floating macOS tiles.
    readonly property int columns: 10
    readonly property real sideMargin: 8
    readonly property real topInset: 56
    readonly property real bottomInset: Math.max(96, AppLauncherService.dockHeight + 24)
    readonly property real gap: 10
    readonly property real cellSize: Math.max(1,
        (width - sideMargin * 2 - gap * (columns - 1)) / columns)
    readonly property int usableRows: Math.max(0, Math.floor(
        (height - topInset - bottomInset + gap) / (cellSize + gap)))
    property int timerSeconds: 0
    property int timerDuration: 0
    property bool timerRunning: false
    property bool timerHasStarted: false
    property bool timerView: false
    property var systemMetrics: ({})
    property var systemMetricsReadProcess: null
    readonly property string systemMetricsPath: Quickshell.stateDir + "/bar/usage-history.json"

    function formattedTimer() {
        const hours = Math.floor(timerSeconds / 3600)
        const minutes = Math.floor((timerSeconds % 3600) / 60)
        const seconds = timerSeconds % 60
        return (hours < 10 ? "0" : "") + hours + ":"
            + (minutes < 10 ? "0" : "") + minutes + ":"
            + (seconds < 10 ? "0" : "") + seconds
    }

    function formattedTimerEndTime() {
        const end = new Date(Date.now() + timerSeconds * 1000)
        return Qt.formatTime(end, "h:mm")
    }

    function lunarDate(date) {
        try {
            return new Intl.DateTimeFormat("zh-CN-u-ca-chinese", {
                month: "long",
                day: "numeric"
            }).format(date)
        } catch (error) {
            return "农历日期"
        }
    }

    function formatMetricBytes(bytes) {
        if (!Number.isFinite(bytes) || bytes <= 0)
            return "--"
        if (bytes >= 1073741824)
            return (bytes / 1073741824).toFixed(1) + " GB"
        return Math.round(bytes / 1048576) + " MB"
    }

    function reloadSystemMetrics() {
        if (systemMetricsReadProcess)
            return
        const process = systemMetricsReader.createObject(root, {
            command: ["sh", "-c", "cat \"$1\" 2>/dev/null", "deskcenter-system-metrics", systemMetricsPath]
        })
        systemMetricsReadProcess = process
        process.exited.connect(function() {
            try {
                const saved = JSON.parse((process.stdout?.text ?? "").trim())
                if (saved.current)
                    systemMetrics = saved.current
            } catch (_) {
                // The top bar has not saved its first sample yet.
            }
            if (systemMetricsReadProcess === process)
                systemMetricsReadProcess = null
            process.destroy()
        })
        process.running = true
    }

    property Component systemMetricsReader: Component {
        Process { stdout: StdioCollector {} }
    }

    Timer {
        // This reads the bar's cached metrics; matching its ten-second
        // sampler is enough, with a little slack to avoid synchronized work.
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.reloadSystemMetrics()
    }

    function addTimerMinute() {
        addTimerMinutes(1)
    }

    function addTimerMinutes(minutes) {
        timerSeconds += minutes * 60
        timerDuration += minutes * 60
    }

    function toggleTimer() {
        if (timerRunning) {
            timerRunning = false
            return
        }
        if (timerSeconds === 0) {
            timerSeconds = 60
            timerDuration = 60
        } else if (timerDuration < timerSeconds) {
            timerDuration = timerSeconds
        }
        timerRunning = true
        timerHasStarted = true
        sendTimerNotification("倒计时开始", "剩余 " + formattedTimer())
    }

    Timer {
        interval: 1000
        running: root.timerRunning
        repeat: true
        onTriggered: {
            if (root.timerSeconds > 1) {
                root.timerSeconds--
                return
            }
            root.timerSeconds = 0
            root.timerRunning = false
            root.timerHasStarted = false
            root.sendTimerNotification("倒计时结束", "计时已完成")
        }
    }

    property Component notificationProcess: Component {
        Process {}
    }

    function sendTimerNotification(summary, body) {
        const process = notificationProcess.createObject(root, {
            command: ["notify-send", "--app-name=DeskCenter", summary, body]
        })
        process.exited.connect(function() { process.destroy() })
        process.running = true
    }

    // Higher priority widgets win when a short display cannot accommodate all
    // rows. The desktop never scrolls and cards never shrink their type.
    readonly property var widgetDefinitions: [
        { id: "clock", title: "", columns: 1, rows: 1, priority: 100,
            startColor: "#21161e", endColor: "#170f14", surface: false },
        { id: "weather", title: "", columns: 3, rows: 1, priority: 90,
            startColor: "#404f86", endColor: "#30345e", surface: false },
        { id: "calendar", title: "", columns: 2, rows: 1, priority: 80, row: 1, column: 2,
            startColor: "#ffffff", endColor: "#f2f2f4", surface: false },
        { id: "system", title: "", columns: 2, rows: 1, priority: 70, row: 1, column: 0,
            startColor: "#f5f3f6", endColor: "#e9e6eb", surface: false }
    ]

    function packWidgets(definitions, columnCount, rowCount) {
        const sorted = definitions.slice().sort(function(a, b) {
            return b.priority - a.priority
        })
        const occupied = []
        const result = []
        for (let row = 0; row < rowCount; row++)
            occupied[row] = Array(columnCount).fill(false)

        for (let i = 0; i < sorted.length; i++) {
            const widget = sorted[i]
            let placed = false
            const firstRow = widget.row ?? 0
            const lastRow = widget.row ?? (rowCount - widget.rows)
            const firstColumn = widget.column ?? 0
            const lastColumn = widget.column ?? (columnCount - widget.columns)
            for (let row = firstRow; row <= lastRow && !placed; row++) {
                for (let column = firstColumn; column <= lastColumn && !placed; column++) {
                    let fits = true
                    for (let y = row; y < row + widget.rows && fits; y++)
                        for (let x = column; x < column + widget.columns; x++)
                            if (occupied[y][x]) { fits = false; break }
                    if (!fits)
                        continue
                    for (let y = row; y < row + widget.rows; y++)
                        for (let x = column; x < column + widget.columns; x++)
                            occupied[y][x] = true
                    result.push({ id: widget.id, column: column, row: row,
                        columns: widget.columns, rows: widget.rows })
                    placed = true
                }
            }
        }
        return result
    }

    readonly property var placements: packWidgets(widgetDefinitions, columns, usableRows)
    function placementFor(widgetId) {
        for (let i = 0; i < placements.length; i++)
            if (placements[i].id === widgetId)
                return placements[i]
        return null
    }
    function spanSize(span) { return span * cellSize + (span - 1) * gap }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Repeater {
        model: root.widgetDefinitions

        delegate: DeskWidgetCard {
            id: card
            required property var modelData
            readonly property var placement: root.placementFor(modelData.id)
            visible: placement !== null
            title: modelData.title
            startColor: modelData.startColor
            endColor: modelData.endColor
            showSurface: modelData.surface
            x: root.sideMargin + (placement?.column ?? 0) * (root.cellSize + root.gap)
            y: root.topInset + (placement?.row ?? 0) * (root.cellSize + root.gap)
            width: root.spanSize(placement?.columns ?? 1)
            height: root.spanSize(placement?.rows ?? 1)
            Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

            // Compact analogue clock, matching the one-unit reference tile.
            Item {
                anchors.fill: parent
                visible: card.modelData.id === "clock"
                clip: true

                Item {
                    id: clockPage
                    width: parent.width
                    height: parent.height
                    y: root.timerView ? -height : 0
                    Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                Canvas {
                    id: analogClock
                    anchors.fill: parent
                    anchors.margins: 14
                    onPaint: {
                        const ctx = getContext("2d")
                        const size = Math.min(width, height)
                        const center = size / 2
                        const radius = size / 2 - 3
                        const date = clock.date
                        ctx.reset()
                        ctx.translate((width - size) / 2 + center, (height - size) / 2 + center)
                        ctx.fillStyle = "#fafafa"
                        ctx.beginPath(); ctx.arc(0, 0, radius, 0, Math.PI * 2); ctx.fill()
                        ctx.strokeStyle = "#dedede"; ctx.lineWidth = 1
                        ctx.beginPath(); ctx.arc(0, 0, radius, 0, Math.PI * 2); ctx.stroke()
                        ctx.strokeStyle = "#171717"; ctx.lineCap = "round"
                        for (let mark = 0; mark < 12; mark++) {
                            const angle = mark * Math.PI / 6
                            ctx.lineWidth = mark % 3 === 0 ? 1.8 : 0.8
                            ctx.beginPath()
                            ctx.moveTo(Math.sin(angle) * (radius - 4), -Math.cos(angle) * (radius - 4))
                            ctx.lineTo(Math.sin(angle) * (radius - (mark % 3 === 0 ? 10 : 7)), -Math.cos(angle) * (radius - (mark % 3 === 0 ? 10 : 7)))
                            ctx.stroke()
                        }
                        // Full hour numerals make the small analogue clock
                        // readable at a glance, rather than relying on ticks
                        // alone. Their radius leaves a clear channel for the
                        // hands in this one-cell tile.
                        ctx.fillStyle = "#242126"
                        ctx.font = "bold " + Math.max(7, Math.round(radius * 0.18)) + "px sans-serif"
                        ctx.textAlign = "center"
                        ctx.textBaseline = "middle"
                        for (let number = 1; number <= 12; number++) {
                            const angle = number * Math.PI / 6
                            const numberRadius = radius * 0.68
                            ctx.fillText(String(number),
                                Math.sin(angle) * numberRadius,
                                -Math.cos(angle) * numberRadius)
                        }
                        const hour = (date.getHours() % 12 + date.getMinutes() / 60) * Math.PI / 6
                        const minute = date.getMinutes() * Math.PI / 30
                        const second = date.getSeconds() * Math.PI / 30
                        ctx.lineWidth = 2.5; ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(Math.sin(hour) * radius * 0.48, -Math.cos(hour) * radius * 0.48); ctx.stroke()
                        ctx.lineWidth = 1.8; ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(Math.sin(minute) * radius * 0.70, -Math.cos(minute) * radius * 0.70); ctx.stroke()
                        ctx.strokeStyle = "#ee7659"; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(Math.sin(second) * radius * 0.76, -Math.cos(second) * radius * 0.76); ctx.stroke()
                        ctx.fillStyle = "#ee7659"; ctx.beginPath(); ctx.arc(0, 0, 2.2, 0, Math.PI * 2); ctx.fill()
                    }
                    Connections { target: clock; function onDateChanged() { analogClock.requestPaint() } }
                }

                Rectangle {
                    id: timerButton
                    width: 21
                    height: 21
                    radius: width / 2
                    anchors { right: parent.right; bottom: parent.bottom; rightMargin: 12; bottomMargin: 12 }
                    color: "transparent"
                    border.width: 0
                    Image {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        width: 17
                        height: 17
                        source: "../../assets/countdown.svg"
                        sourceSize.width: 26
                        sourceSize.height: 26
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                    MouseArea {
                        id: timerPointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.timerView = true
                    }
                }
                }

                Item {
                    id: timerPage
                    width: parent.width
                    height: parent.height
                    y: root.timerView ? 0 : height
                    Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    Item {
                        id: timerDial
                        width: Math.min(parent.width - 28, parent.height - 45)
                        height: width
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 5 }
                        Canvas {
                            id: timerProgress
                            anchors.fill: parent
                            onPaint: {
                                const ctx = getContext("2d")
                                const center = width / 2
                                const radius = center - 7
                                const amount = root.timerDuration > 0
                                    ? Math.max(0, Math.min(1, root.timerSeconds / root.timerDuration)) : 1
                                ctx.reset()
                                ctx.lineWidth = Math.max(8, width * 0.08)
                                ctx.lineCap = "round"
                                ctx.strokeStyle = "rgba(255, 255, 255, 0.10)"
                                ctx.beginPath(); ctx.arc(center, center, radius, -Math.PI / 2, Math.PI * 1.5); ctx.stroke()
                                if (amount > 0) {
                                    ctx.strokeStyle = "#ffa515"
                                    ctx.beginPath(); ctx.arc(center, center, radius, -Math.PI / 2,
                                        -Math.PI / 2 + Math.PI * 2 * amount); ctx.stroke()
                                }
                            }
                            Connections {
                                target: root
                                function onTimerSecondsChanged() { timerProgress.requestPaint() }
                                function onTimerDurationChanged() { timerProgress.requestPaint() }
                            }
                            Component.onCompleted: requestPaint()
                        }
                        Text {
                            id: timerTimeText
                            anchors.centerIn: parent
                            text: root.formattedTimer()
                            color: "white"
                            font { family: "SF Pro Display"; pixelSize: Math.min(16, timerDial.width * 0.15); weight: Font.Medium }
                        }
                    }
                    Row {
                        visible: root.timerSeconds > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: timerDial.y + timerTimeText.y - height - 2
                        spacing: 5
                        Canvas {
                            width: 14
                            height: 16
                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.reset(); ctx.strokeStyle = "#ffb028"; ctx.lineWidth = 1.3; ctx.lineCap = "round"
                                ctx.beginPath(); ctx.moveTo(3, 10); ctx.quadraticCurveTo(4, 8.7, 4, 6.4)
                                ctx.quadraticCurveTo(4, 3.8, 7, 3.8); ctx.quadraticCurveTo(10, 3.8, 10, 6.4)
                                ctx.quadraticCurveTo(10, 8.7, 11, 10); ctx.lineTo(3, 10); ctx.stroke()
                                ctx.beginPath(); ctx.moveTo(5.3, 12); ctx.lineTo(8.7, 12); ctx.stroke()
                            }
                        }
                        Text {
                            text: "结束于 " + root.formattedTimerEndTime()
                            color: Qt.rgba(1, 1, 1, 0.72)
                            font { pixelSize: 10; weight: Font.DemiBold }
                        }
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: timerDial.y + timerTimeText.y + timerTimeText.height + 2
                        spacing: 5
                        Repeater {
                            model: [1, 5, 15]
                            delegate: Rectangle {
                                required property int modelData
                                width: modelData === 15 ? 30 : 25
                                height: 17
                                radius: height / 2
                                color: Qt.rgba(255 / 255, 165 / 255, 21 / 255, 0.16)
                                border.width: 1
                                border.color: Qt.rgba(255 / 255, 165 / 255, 21 / 255, 0.72)
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "分"
                                    color: "#ffb028"
                                    font { pixelSize: 8; weight: Font.DemiBold }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.addTimerMinutes(modelData)
                                }
                            }
                        }
                    }
                    Row {
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 5 }
                        spacing: 22
                        Repeater {
                            model: ["取消", root.timerRunning ? "暂停"
                                : (root.timerHasStarted ? "继续" : "开始")]
                            delegate: Rectangle {
                                required property var modelData
                                width: 38
                                height: 21
                                radius: height / 2
                                color: modelData !== "取消"
                                    ? Qt.rgba(255 / 255, 165 / 255, 21 / 255, 0.24)
                                    : Qt.rgba(1, 1, 1, 0.13)
                                border.width: 1
                                border.color: modelData !== "取消"
                                    ? "#ffa515" : Qt.rgba(1, 1, 1, 0.22)
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: modelData !== "取消" ? "#ffb028" : "white"
                                    font { pixelSize: 9; weight: Font.DemiBold }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData === "取消") {
                                            root.timerRunning = false
                                            root.timerSeconds = 0
                                            root.timerDuration = 0
                                            root.timerHasStarted = false
                                        } else {
                                            root.toggleTimer()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        anchors { left: parent.left; top: parent.top; leftMargin: 10; topMargin: 7 }
                        text: "×"
                        color: Qt.rgba(1, 1, 1, 0.74)
                        font { pixelSize: 18; weight: Font.Light }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.timerView = false
                        }
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: card.modelData.id === "date"
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 27
                    color: "#ff626a"
                }
                Text {
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 5 }
                    text: Qt.formatDateTime(clock.date, "yyyy年M月")
                    color: "white"
                    font { pixelSize: 11; weight: Font.Bold }
                }
                Text { anchors.centerIn: parent; anchors.verticalCenterOffset: 10; text: Qt.formatDateTime(clock.date, "d日 dddd"); color: "#111118"; font { pixelSize: 24; weight: Font.Bold } }
                Text {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 10 }
                    text: Qt.formatDateTime(clock.date, "dddd")
                    color: "#3c3c43"
                    font.pixelSize: 9
                }
            }

            Item {
                anchors.fill: parent
                visible: card.modelData.id === "weather"

                // Keep the weather artwork static. Continuous transforms on
                // this always-visible background card force redraws even when
                // the desktop is otherwise idle.
                Item {
                    id: deskWeatherMotion
                    anchors.fill: parent
                    clip: true
                    opacity: 0.34

                    Item {
                        id: deskSunLayer
                        visible: WeatherService.weatherCode === 0 && WeatherService.isDay
                        width: 70
                        height: 70
                        anchors { right: parent.right; top: parent.top; rightMargin: 20; topMargin: 5 }
                        Repeater {
                            model: 8
                            delegate: Rectangle {
                                required property int index
                                width: 2
                                height: 12
                                radius: 1
                                color: "#ffe36a"
                                x: deskSunLayer.width / 2 - width / 2
                                y: 2
                                transform: Rotation { origin.x: 1; origin.y: 33; angle: index * 45 }
                            }
                        }
                        Rectangle { anchors.centerIn: parent; width: 28; height: 28; radius: 14; color: "#ffe36a" }
                    }

                    Item {
                        id: deskCloudLayer
                        anchors.fill: parent
                        visible: WeatherService.weatherCode === 1 || WeatherService.weatherCode === 2
                            || WeatherService.weatherCode === 3 || WeatherService.weatherCode === 45
                            || WeatherService.weatherCode === 48
                        Image {
                            id: deskCloudBack
                            width: parent.width * 0.34
                            height: parent.height * 0.36
                            y: 2
                            x: -width
                            source: "../../assets/weather-cloud.svg"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                        Image {
                            id: deskCloudFront
                            width: parent.width * 0.30
                            height: parent.height * 0.29
                            y: parent.height * 0.18
                            x: parent.width
                            source: "../../assets/weather-cloud-wide.svg"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                    }

                    Item {
                        id: deskRainLayer
                        anchors.fill: parent
                        visible: (WeatherService.weatherCode >= 51 && WeatherService.weatherCode <= 67)
                            || (WeatherService.weatherCode >= 80 && WeatherService.weatherCode <= 82)
                        Repeater {
                            model: 9
                            delegate: Rectangle {
                                required property int index
                                width: 1
                                height: 12
                                radius: 1
                                color: "#d9f1ff"
                                x: deskRainLayer.width * (index + 0.4) / 9
                                rotation: -13
                            }
                        }
                    }
                }
                Text {
                    anchors { left: parent.left; top: parent.top; leftMargin: 16; topMargin: 12 }
                    text: WeatherService.cityName
                    color: "white"
                    font { pixelSize: 15; weight: Font.DemiBold }
                }
                Text {
                    anchors { left: parent.left; top: parent.top; leftMargin: 15; topMargin: 29 }
                    text: WeatherService.temperature
                    color: "white"
                    font { family: "SF Pro Display"; pixelSize: Math.min(42, parent.height * 0.32); weight: Font.Normal }
                }
                Text {
                    anchors { right: parent.right; top: parent.top; rightMargin: 18; topMargin: 14 }
                    text: WeatherService.conditionSymbol(WeatherService.weatherCode, WeatherService.isDay)
                    color: "#ffd23f"
                    font.pixelSize: Math.min(34, parent.height * 0.26)
                }
                Text {
                    anchors { right: parent.right; top: parent.top; rightMargin: 16; topMargin: 48 }
                    text: WeatherService.conditionText(WeatherService.weatherCode)
                    color: "white"
                    font { pixelSize: 15; weight: Font.DemiBold }
                }
                Text {
                    anchors { right: parent.right; bottom: weeklyForecast.top; rightMargin: 16; bottomMargin: 3 }
                    text: WeatherService.forecastDays.length > 0
                        ? "最高 " + WeatherService.forecastDays[0].high + "°  最低 "
                            + WeatherService.forecastDays[0].low + "°" : "正在更新预报"
                    color: Qt.rgba(1, 1, 1, 0.74)
                    font.pixelSize: 11
                }
                Item {
                    id: weeklyForecast
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 10; rightMargin: 10; bottomMargin: 8 }
                    height: Math.min(62, parent.height * 0.46)
                    Repeater {
                        model: WeatherService.forecastDays
                        delegate: Item {
                            required property var modelData
                            required property int index
                            x: index * weeklyForecast.width / 7
                            width: weeklyForecast.width / 7
                            height: weeklyForecast.height
                            Text {
                                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
                                text: WeatherService.forecastLabel(modelData.date, index)
                                color: Qt.rgba(1, 1, 1, 0.72)
                                font { pixelSize: 10; weight: Font.DemiBold }
                            }
                            Text {
                                anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
                                text: WeatherService.conditionSymbol(modelData.code, true)
                                color: "#ffd23f"
                                font.pixelSize: 22
                            }
                            Text {
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                                text: modelData.high + "°/" + modelData.low + "°"
                                color: "white"
                                font { pixelSize: 10; weight: Font.DemiBold }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: WeatherService.forecastDays.length === 0
                        text: WeatherService.loading ? "正在获取 7 日预报…" : "暂无 7 日预报"
                        color: Qt.rgba(1, 1, 1, 0.65)
                        font.pixelSize: 11
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: WeatherService.refresh() }
            }

            Item {
                anchors.fill: parent
                visible: card.modelData.id === "status"
                Row {
                    anchors.centerIn: parent
                    spacing: 18
                    Repeater {
                        model: [
                            { label: "音量", value: Math.round(ControlCenterService.volumePercent) + "%", amount: ControlCenterService.volumePercent / 100 },
                            { label: "湿度", value: WeatherService.humidity, amount: Math.min(1, Number(WeatherService.humidity.replace("%", "")) / 100) },
                            { label: "天气", value: WeatherService.temperature, amount: 0.72 }
                        ]
                        delegate: Item {
                            required property var modelData
                            width: 54; height: 74
                            Canvas {
                                id: ring
                                width: 48; height: 48
                                anchors.horizontalCenter: parent.horizontalCenter
                                onPaint: {
                                    const ctx = getContext("2d")
                                    ctx.reset(); ctx.lineWidth = 6; ctx.lineCap = "round"
                                    ctx.strokeStyle = "#f7f4f7"; ctx.beginPath(); ctx.arc(24, 24, 18, -Math.PI / 2, Math.PI * 1.5); ctx.stroke()
                                    ctx.strokeStyle = "#08be72"; ctx.beginPath(); ctx.arc(24, 24, 18, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * modelData.amount); ctx.stroke()
                                }
                                Component.onCompleted: requestPaint()
                            }
                            Text {
                                anchors { horizontalCenter: parent.horizontalCenter; top: ring.bottom; topMargin: 2 }
                                text: modelData.value
                                color: "#36313a"
                                font { pixelSize: 10; weight: Font.Bold }
                            }
                            Text {
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                                text: modelData.label
                                color: "#5e5660"
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: card.modelData.id === "photo"
                Image { anchors.fill: parent; source: "../../assets/defaultCover.png"; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 28
                    color: Qt.rgba(0, 0, 0, 0.34)
                }
                Text {
                    anchors { left: parent.left; bottom: parent.bottom; leftMargin: 12; bottomMargin: 8 }
                    text: "精选画面"
                    color: "white"
                    font { pixelSize: 11; weight: Font.DemiBold }
                }
            }

            Item {
                id: systemContent
                anchors.fill: parent
                visible: card.modelData.id === "system"
                // A 2×1 tile has very different physical pixels on a 1080p
                // and a 4K display. Size every visual from the card itself,
                // rather than leaving desktop-scale content at 54px.
                readonly property real ringSize: Math.min(width * 0.28, height * 0.58)
                Row {
                    id: systemUsageRow
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: systemContent.height * 0.07 }
                    spacing: systemContent.ringSize * 0.45
                    Repeater {
                        model: [
                            { label: "CPU", icon: "", value: root.systemMetrics.cpuUsage ?? 0, color: "#30a46c" },
                            { label: "内存", icon: "󰍛", value: root.systemMetrics.memoryTotalBytes > 0 ? root.systemMetrics.memoryUsedBytes / root.systemMetrics.memoryTotalBytes : 0, color: "#30a46c" }
                        ]
                        delegate: Item {
                            required property var modelData
                            width: systemContent.ringSize
                            height: systemContent.ringSize
                            Canvas {
                                id: usageRing
                                property real amount: modelData.value
                                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
                                width: systemContent.ringSize
                                height: systemContent.ringSize
                                onAmountChanged: requestPaint()
                                onPaint: {
                                    const ctx = getContext("2d")
                                    const value = Math.max(0, Math.min(1, amount))
                                    ctx.reset()
                                    ctx.lineWidth = Math.min(20, width * 0.11)
                                    ctx.lineCap = "round"
                                    ctx.strokeStyle = "#dedbe1"
                                    ctx.beginPath()
                                    ctx.arc(width / 2, height / 2, width * 0.39, -Math.PI / 2, Math.PI * 1.5)
                                    ctx.stroke()
                                    ctx.strokeStyle = modelData.color
                                    ctx.beginPath()
                                    ctx.arc(width / 2, height / 2, width * 0.39, -Math.PI / 2,
                                        -Math.PI / 2 + Math.PI * 2 * value)
                                    ctx.stroke()
                                }
                                Component.onCompleted: requestPaint()
                            }
                            Column {
                                anchors.centerIn: usageRing
                                spacing: 6
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Math.round(modelData.value * 100) + "%"
                                    color: "#302c34"
                                    font { family: "SF Pro Display"; pixelSize: 18; weight: Font.Bold }
                                }
                                Item {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: metricIcon.width + 3 + metricLabel.implicitWidth
                                    height: metricLabel.implicitHeight
                                    Text {
                                        id: metricIcon
                                        anchors { left: parent.left; baseline: metricLabel.baseline }
                                        width: 12
                                        text: modelData.icon
                                        horizontalAlignment: Text.AlignHCenter
                                        color: "#5d5761"
                                        font { family: "LXGW WenKai Mono Nerd Font"; pixelSize: 12 }
                                    }
                                    Text {
                                        id: metricLabel
                                        anchors { left: metricIcon.right; leftMargin: 3; verticalCenter: parent.verticalCenter }
                                        text: modelData.label
                                        color: "#5d5761"
                                        font { pixelSize: 12; weight: Font.DemiBold }
                                    }
                                }
                            }
                        }
                    }
                }
                Item {
                    id: diskUsage
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: systemContent.width * 0.06; rightMargin: systemContent.width * 0.06; bottomMargin: systemContent.height * 0.08 }
                    height: systemContent.height * 0.18
                    readonly property real amount: root.systemMetrics.diskTotalBytes > 0
                        ? root.systemMetrics.diskUsedBytes / root.systemMetrics.diskTotalBytes : 0
                    Text {
                        id: diskLabel
                        anchors { left: parent.left; bottom: parent.bottom }
                        text: "磁盘"
                        color: "#4e4954"
                        font { pixelSize: systemContent.height * 0.075; weight: Font.DemiBold }
                    }
                    Text {
                        id: diskDetail
                        anchors { right: parent.right; bottom: parent.bottom }
                        text: root.formatMetricBytes(root.systemMetrics.diskUsedBytes)
                            + " / " + root.formatMetricBytes(root.systemMetrics.diskTotalBytes)
                        color: "#4e4954"
                        font { family: "SF Pro Display"; pixelSize: systemContent.height * 0.075; weight: Font.DemiBold }
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: systemContent.height * 0.045
                        radius: height / 2
                        color: "#dedbe1"
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, diskUsage.amount))
                            height: parent.height
                            radius: parent.radius
                            color: "#30a46c"
                            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: card.modelData.id === "notes"
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 27
                    color: "#f5c400"
                }
                Text {
                    anchors { left: parent.left; top: parent.top; leftMargin: 12; topMargin: 7 }
                    text: "备忘录"
                    color: "white"
                    font { pixelSize: 11; weight: Font.Bold }
                }
                Text {
                    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 12; rightMargin: 12; topMargin: 42 }
                    text: "暂时没有更多备忘"
                    color: "#333238"
                    font.pixelSize: 11
                }
            }

            Item {
                anchors.fill: parent
                visible: card.modelData.id === "overview"
                Text {
                    text: "桌面工作区"
                    color: "white"
                    anchors { left: parent.left; top: parent.top; leftMargin: 18; topMargin: 42 }
                    font { pixelSize: 24; weight: Font.DemiBold }
                }
                Text {
                    text: "日历、天气和媒体会在此保持一目了然"
                    wrapMode: Text.Wrap
                    color: Qt.rgba(1, 1, 1, 0.74)
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 18; rightMargin: 18; bottomMargin: 20 }
                    font.pixelSize: 14
                }
            }

            Item {
                anchors.fill: parent
                visible: card.modelData.id === "music"
                Image {
                    id: musicArtwork
                    width: 58
                    height: 58
                    anchors { left: parent.left; top: parent.top; leftMargin: 11; topMargin: 12 }
                    source: DockMprisService.activePlayer?.trackArtUrl || "../../assets/defaultCover.png"
                    fillMode: Image.PreserveAspectCrop
                }
                Text {
                    text: DockMprisService.activePlayer?.trackTitle || "没有正在播放的内容"
                    elide: Text.ElideRight
                    color: "white"
                    anchors { left: musicArtwork.right; right: parent.right; top: parent.top; leftMargin: 10; rightMargin: 10; topMargin: 15 }
                    font { pixelSize: 12; weight: Font.DemiBold }
                }
                Text {
                    text: DockMprisService.activePlayer?.trackArtist || "媒体控制"
                    elide: Text.ElideRight
                    color: Qt.rgba(1, 1, 1, 0.68)
                    anchors { left: musicArtwork.right; right: parent.right; top: parent.top; leftMargin: 10; rightMargin: 10; topMargin: 34 }
                    font.pixelSize: 10
                }
                Rectangle {
                    height: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.28)
                    anchors { left: musicArtwork.right; right: parent.right; bottom: parent.bottom; leftMargin: 10; rightMargin: 10; bottomMargin: 15 }
                    Rectangle { width: parent.width * 0.42; height: parent.height; radius: parent.radius; color: "#eaa5a4" }
                    Text {
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.top; bottomMargin: 8 }
                        text: "◀   " + (DockMprisService.activePlayer?.isPlaying ? "❚❚" : "▶") + "   ▶"
                        color: "white"
                        font { pixelSize: 13; weight: Font.DemiBold }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: DockMprisService.togglePlayPause()
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: card.modelData.id === "shortcuts"
                Row {
                    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 18; rightMargin: 18; topMargin: 44 }
                    spacing: 10
                    Repeater {
                        model: ["应用库", "刷新天气", "媒体"]
                        delegate: Rectangle {
                            required property var modelData
                            width: (parent.width - parent.spacing * 2) / 3
                            height: 58
                            radius: 15
                            color: Qt.rgba(1, 1, 1, 0.14)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.15)
                            Text { anchors.centerIn: parent; text: modelData; color: "white"; font { pixelSize: 12; weight: Font.DemiBold } }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData === "应用库")
                                        AppLauncherService.show()
                                    else if (modelData === "刷新天气")
                                        WeatherService.refresh()
                                    else
                                        DockMprisService.togglePlayPause()
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: calendarContent
                anchors.fill: parent
                visible: card.modelData.id === "calendar"
                readonly property int year: clock.date.getFullYear()
                readonly property int month: clock.date.getMonth()
                // Monday-first month layout: 星期一 is the first column and
                // 星期日 is the final column, matching the requested reading order.
                readonly property int firstWeekday: (new Date(year, month, 1).getDay() + 6) % 7
                readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()
                // Do not reserve a sixth, empty week: five-week months use
                // the whole panel height instead of ending with a blank band.
                readonly property int weekCount: Math.ceil((firstWeekday + daysInMonth) / 7)
                readonly property int headerHeight: 38

                Rectangle {
                    // Draw the pale right pane before the header. Its own
                    // rounded lower corner keeps it from covering the card
                    // outline even though QML clipping is rectangular.
                    anchors { top: parent.top; bottom: parent.bottom; right: parent.right; left: parent.left; leftMargin: parent.width * 0.42 }
                    radius: card.radius
                    color: "#fafafa"
                }
                Canvas {
                    id: calendarHeader
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: calendarContent.headerHeight
                    onPaint: {
                        const ctx = getContext("2d")
                        const corner = Math.min(card.radius, height)
                        ctx.reset()
                        ctx.fillStyle = "#ff5d66"
                        ctx.beginPath()
                        ctx.moveTo(0, height)
                        ctx.lineTo(0, corner)
                        ctx.quadraticCurveTo(0, 0, corner, 0)
                        ctx.lineTo(width - corner, 0)
                        ctx.quadraticCurveTo(width, 0, width, corner)
                        ctx.lineTo(width, height)
                        ctx.closePath()
                        ctx.fill()
                    }
                }
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: parent.width * 0.42; topMargin: calendarContent.headerHeight; bottomMargin: 8 }
                    width: 1
                    color: Qt.rgba(0, 0, 0, 0.10)
                }

                Text {
                    anchors.centerIn: calendarHeader
                    text: Qt.formatDateTime(clock.date, "yyyy年M月")
                    horizontalAlignment: Text.AlignHCenter
                    color: "white"
                    font { pixelSize: 15; weight: Font.Bold }
                }
                Text {
                    anchors { left: parent.left; top: parent.top; leftMargin: 15; topMargin: calendarContent.headerHeight + 7 }
                    text: Qt.formatDateTime(clock.date, "d日")
                    color: "#15151a"
                    font { family: "SF Pro Display"; pixelSize: 32; weight: Font.DemiBold }
                }
                Text {
                    anchors { left: parent.left; top: parent.top; leftMargin: 16; topMargin: calendarContent.headerHeight + 46 }
                    text: Qt.formatDateTime(clock.date, "ddd") + " · " + root.lunarDate(clock.date)
                    color: "#4d4d55"
                    font { pixelSize: 10; weight: Font.DemiBold }
                }
                Item {
                    id: monthGrid
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: parent.width * 0.42 + 10; rightMargin: 10; topMargin: calendarContent.headerHeight + 6; bottomMargin: 7 }
                    Row {
                        width: parent.width
                        height: 15
                        Repeater {
                            model: ["一", "二", "三", "四", "五", "六", "日"]
                            delegate: Text {
                                required property var modelData
                                required property int index
                                width: parent.width / 7
                                text: modelData
                                horizontalAlignment: Text.AlignHCenter
                                color: index >= 5 ? "#e95a63" : "#5d5d65"
                                font { pixelSize: 10; weight: Font.Bold }
                            }
                        }
                    }
                    Grid {
                        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 15 }
                        columns: 7
                        Repeater {
                            model: calendarContent.weekCount * 7
                            delegate: Item {
                                required property int index
                                width: parent.width / 7
                                height: parent.height / calendarContent.weekCount
                                readonly property int day: index - calendarContent.firstWeekday + 1
                                readonly property bool today: day === clock.date.getDate()
                                    && calendarContent.month === clock.date.getMonth()
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: parent.today ? "#ef5661" : "transparent"
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: parent.day > 0 && parent.day <= calendarContent.daysInMonth
                                    text: parent.day
                                    color: parent.today ? "white" : "#29292f"
                                    font { pixelSize: 10; weight: parent.today ? Font.Bold : Font.DemiBold }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
