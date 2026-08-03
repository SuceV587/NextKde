import QtQuick
import qs.modules.weather

// A single fixed-size Dock slot shared by music and weather. Keeping both
// pages inside this item means carousel changes never reflow Dock icons.
Item {
    id: carousel
    property int iconSize: 44
    property int dockHeight: 60
    property int widthUnits: 4
    readonly property bool hasMusic: DockMprisService.hasPlayingPlayer
    readonly property bool hasWeather: WeatherService.available
    property int page: 0 // 0 music, 1 weather
    // +1 moves the incoming page in from the right; -1 from the left.
    property int transitionDirection: 1
    readonly property bool showMusic: hasMusic && (!hasWeather || page === 0)

    width: iconSize * widthUnits + iconSize * 0.2
    // Both child cards extend 0.1 icon-size beyond their content vertically
    // for their rounded glass background. Include those edges in the slide
    // viewport so `clip` never squares off their corners.
    height: iconSize * 1.2
    clip: true
    // Row lays out horizontal coordinates only. Its height is the full Dock
    // height, so this icon-height slot must explicitly opt into vertical
    // centring just as the original DockMusicPlayer did.
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    onHasMusicChanged: if (!hasMusic && page === 0) page = 1
    onHasWeatherChanged: if (!hasWeather && page === 1) page = 0

    function switchPage(resetTimer, requestedDirection) {
        if (!hasMusic || !hasWeather)
            return
        transitionDirection = requestedDirection === undefined
            ? (page === 0 ? 1 : -1) : requestedDirection
        page = page === 0 ? 1 : 0
        if (resetTimer)
            carouselTimer.restart()
    }

    Timer {
        id: carouselTimer
        interval: 30000
        running: carousel.hasMusic && carousel.hasWeather
        repeat: true
        onTriggered: carousel.switchPage(false)
    }

    // A MouseArea receives wheel events before the nested music controls. It
    // uses no mouse buttons, so all existing player clicks keep working.
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
            const verticalDelta = Math.abs(wheel.angleDelta.y) + Math.abs(wheel.pixelDelta.y)
            if (verticalDelta <= 0 || wheelCooldown.running)
                return
            carousel.switchPage(true, wheel.angleDelta.y + wheel.pixelDelta.y >= 0 ? 1 : -1)
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
        enabled: carousel.showMusic
        x: carousel.showMusic ? 0 : -carousel.transitionDirection * width
        opacity: carousel.showMusic ? 1 : 0
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }
    DockWeatherWidget {
        anchors.verticalCenter: parent.verticalCenter
        iconSize: carousel.iconSize
        dockHeight: carousel.dockHeight
        widthUnits: carousel.widthUnits
        visible: carousel.hasWeather
        enabled: !carousel.showMusic && carousel.hasWeather
        x: carousel.showMusic ? carousel.transitionDirection * width : 0
        opacity: carousel.showMusic ? 0 : 1
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }
}
