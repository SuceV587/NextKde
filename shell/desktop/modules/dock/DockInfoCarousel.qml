import QtQuick
import qs.desktop.modules.weather

// One fixed-size Dock slot shared by music, weather, clock and temperature.
// Pages stay inside this viewport so switching never reflows Dock icons.
Item {
    id: carousel

    readonly property int musicPage: 0
    readonly property int weatherPage: 1
    readonly property int clockPage: 2
    readonly property int temperaturePage: 3

    property int iconSize: 44
    property int dockHeight: 60
    property int widthUnits: 4
    property bool showClock: false
    property bool showTemperature: true
    property string widgetMode: ConfigService.widgetMode
    property string fixedWidget: ConfigService.fixedWidget
    property int carouselInterval: ConfigService.carouselInterval
    readonly property bool hasMusic: ConfigService.isDockWidgetEnabled("music") && DockMprisService.hasPlayingPlayer
    readonly property bool hasWeather: ConfigService.isDockWidgetEnabled("weather") && WeatherService.available
    readonly property bool hasClock: ConfigService.isDockWidgetEnabled("clock") && (showClock || widgetMode === "fixed")
    readonly property bool hasTemperature: ConfigService.isDockWidgetEnabled("temperature") && showTemperature
    readonly property int availablePageCount: Number(hasMusic)
        + Number(hasWeather) + Number(hasClock) + Number(hasTemperature)

    // Prefer the clock when Bar has just moved into Dock. This preserves the
    // information users previously saw at the leading edge of the Dock.
    property int page: clockPage
    property int previousPage: -1
    property int transitionDirection: 1

    width: iconSize * widthUnits + iconSize * 0.2
    height: iconSize * 1.2
    clip: true
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    function fixedPageIndex() {
        if (fixedWidget === "music") return musicPage
        if (fixedWidget === "weather") return weatherPage
        if (fixedWidget === "clock") return clockPage
        if (fixedWidget === "temperature") return temperaturePage
        return weatherPage
    }

    function pageAvailable(candidate) {
        if (widgetMode === "fixed")
            return candidate === fixedPageIndex()
        if (candidate === musicPage)
            return hasMusic
        if (candidate === weatherPage)
            return hasWeather
        if (candidate === clockPage)
            return hasClock
        return candidate === temperaturePage && hasTemperature
    }

    function availablePages() {
        if (widgetMode === "fixed")
            return [fixedPageIndex()]
        const pages = []
        if (hasMusic)
            pages.push(musicPage)
        if (hasWeather)
            pages.push(weatherPage)
        if (hasClock)
            pages.push(clockPage)
        if (hasTemperature)
            pages.push(temperaturePage)
        return pages
    }

    function ensureValidPage(preferClock) {
        if (widgetMode === "fixed") {
            const target = fixedPageIndex()
            previousPage = page
            page = target
            return
        }
        if (preferClock && hasClock) {
            previousPage = page
            page = clockPage
            return
        }
        if (pageAvailable(page))
            return
        const pages = availablePages()
        previousPage = page
        page = pages.length > 0 ? pages[0] : clockPage
    }

    function switchPage(resetTimer, requestedDirection) {
        const pages = availablePages()
        if (pages.length < 2)
            return
        const direction = requestedDirection === undefined
            ? 1 : (requestedDirection >= 0 ? 1 : -1)
        let currentIndex = pages.indexOf(page)
        if (currentIndex < 0)
            currentIndex = 0
        previousPage = page
        transitionDirection = direction
        page = pages[(currentIndex + direction + pages.length) % pages.length]
        if (resetTimer)
            carouselTimer.restart()
    }

    function pageX(pageIndex, pageWidth) {
        if (page === pageIndex)
            return 0
        if (previousPage === pageIndex)
            return -transitionDirection * pageWidth
        return transitionDirection * pageWidth
    }

    Component.onCompleted: ensureValidPage(showClock)
    onHasMusicChanged: ensureValidPage(false)
    onHasWeatherChanged: ensureValidPage(false)
    onHasClockChanged: ensureValidPage(showClock)
    onHasTemperatureChanged: ensureValidPage(false)
    onWidgetModeChanged: ensureValidPage(false)
    onFixedWidgetChanged: ensureValidPage(false)

    Timer {
        id: carouselTimer
        interval: Math.max(5, carousel.carouselInterval) * 1000
        running: carousel.availablePageCount > 1 && carousel.widgetMode === "carousel"
        repeat: true
        onTriggered: carousel.switchPage(false, 1)
    }

    Timer {
        id: wheelCooldown
        interval: 180
        repeat: false
    }
    MouseArea {
        anchors.fill: parent
        z: 20
        acceptedButtons: Qt.NoButton
        onWheel: function(wheel) {
            const delta = wheel.angleDelta.y + wheel.pixelDelta.y
            if (delta === 0 || wheelCooldown.running)
                return
            carousel.switchPage(true, delta >= 0 ? -1 : 1)
            wheelCooldown.restart()
            wheel.accepted = true
        }
    }

    DockMusicPlayer {
        anchors.verticalCenter: parent.verticalCenter
        iconSize: carousel.iconSize
        dockHeight: carousel.dockHeight
        widthUnits: carousel.widthUnits
        visible: carousel.hasMusic
        enabled: carousel.page === carousel.musicPage
        x: carousel.pageX(carousel.musicPage, width)
        opacity: enabled ? 1 : 0
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    DockWeatherWidget {
        anchors.verticalCenter: parent.verticalCenter
        iconSize: carousel.iconSize
        dockHeight: carousel.dockHeight
        widthUnits: carousel.widthUnits
        visible: carousel.hasWeather
        enabled: carousel.page === carousel.weatherPage
        x: carousel.pageX(carousel.weatherPage, width)
        opacity: enabled ? 1 : 0
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    DockClockWidget {
        anchors.verticalCenter: parent.verticalCenter
        iconSize: carousel.iconSize
        dockHeight: carousel.dockHeight
        widthUnits: carousel.widthUnits
        visible: carousel.showClock
        enabled: carousel.page === carousel.clockPage
        x: carousel.pageX(carousel.clockPage, width)
        opacity: enabled ? 1 : 0
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    DockTemperatureWidget {
        anchors.verticalCenter: parent.verticalCenter
        iconSize: carousel.iconSize
        dockHeight: carousel.dockHeight
        widthUnits: carousel.widthUnits
        visible: carousel.showTemperature
        enabled: carousel.page === carousel.temperaturePage
        x: carousel.pageX(carousel.temperaturePage, width)
        opacity: enabled ? 1 : 0
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }
}
