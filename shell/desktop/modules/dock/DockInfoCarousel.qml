import QtQuick
import qs.desktop.modules.weather

// One Dock slot shared by music, weather, clock and metrics.
//
// Two layouts over the same four cards:
//   carousel — the historical fixed-size slot; the enabled pages rotate
//     through it and the width never follows the content.
//   expanded — every enabled card takes its own place in the row, sized by
//     what it actually draws (clock 3 icon units, the rest 4), and nothing
//     rotates any more.
//
// Hovering either layout asks DockInfoPopup for the full read-out of the card
// under the pointer. Music keeps its own popup and is skipped here.
Item {
    id: carousel

    readonly property int musicPage: 0
    readonly property int weatherPage: 1
    readonly property int clockPage: 2
    readonly property int temperaturePage: 3
    readonly property var pageOrder: [musicPage, weatherPage, clockPage,
        temperaturePage]

    property int iconSize: 44
    property int dockHeight: 60
    property int widthUnits: 4
    property bool showClock: false
    property bool showTemperature: true

    // ── Dock 组件 settings ──
    property bool expanded: false
    property bool cardMusic: true
    property bool cardWeather: true
    property bool cardClock: true
    property bool cardMetrics: true
    property bool clockSeconds: true
    property bool clockDate: true
    property bool clockSolar: true
    property bool metricAverage: true
    property bool metricPeak: true
    property bool metricCpu: true
    property bool metricMemory: true
    property bool metricStorage: true

    readonly property bool hasMusic: DockMprisService.hasPlayingPlayer
    readonly property bool hasWeather: WeatherService.available
    readonly property real cardGap: iconSize * 0.2
    // Visible seam between neighbouring expanded cards. Each card's painted
    // background already extends cardGap/2 past its content, so without this
    // extra step two adjacent cards touch edge to edge.
    readonly property real cardSpacing: Math.max(4, Math.round(iconSize * 0.14))

    // Prefer the clock when Bar has just moved into Dock. This preserves the
    // information users previously saw at the leading edge of the Dock.
    property int page: clockPage
    property int previousPage: -1
    property int transitionDirection: 1
    property int hoveredPage: -1

    width: expanded ? expandedWidth : iconSize * widthUnits + iconSize * 0.2
    height: iconSize * 1.2
    clip: !expanded
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    function cardVisible(candidate) {
        if (candidate === musicPage)
            return hasMusic && cardMusic
        if (candidate === weatherPage)
            return hasWeather && cardWeather
        if (candidate === clockPage)
            return showClock && cardClock
        return showTemperature && cardMetrics
    }

    function unitsFor(candidate) {
        // The clock draws two rows of text and needs three icon units; every
        // other card keeps the four it always reserved.
        return candidate === clockPage ? 3 : 4
    }

    function cardWidth(candidate) {
        return iconSize * (expanded ? unitsFor(candidate) : widthUnits)
            + cardGap * 2
    }

    readonly property int availablePageCount: {
        let count = 0
        for (const candidate of pageOrder) {
            if (cardVisible(candidate))
                count++
        }
        return count
    }

    readonly property real expandedWidth: {
        let total = 0
        for (const candidate of pageOrder) {
            if (!cardVisible(candidate))
                continue
            total += iconSize * unitsFor(candidate) + cardGap + cardSpacing
        }
        return total
    }

    function pageAvailable(candidate) {
        return cardVisible(candidate)
    }

    function availablePages() {
        const pages = []
        for (const candidate of pageOrder) {
            if (cardVisible(candidate))
                pages.push(candidate)
        }
        return pages
    }

    function ensureValidPage(preferClock) {
        if (preferClock && showClock && cardClock) {
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

    // Expanded mode stacks the cards left to right in page order, skipping
    // the ones that are off; carousel mode keeps the sliding viewport.
    function layoutX(candidate) {
        if (!expanded)
            return pageX(candidate, cardWidth(candidate))
        let offset = 0
        for (const other of pageOrder) {
            if (other === candidate)
                return offset
            if (cardVisible(other))
                offset += iconSize * unitsFor(other) + cardGap + cardSpacing
        }
        return offset
    }

    function isShown(candidate) {
        return expanded || page === candidate
    }

    // Which card the pointer is over. In carousel mode only one card is ever
    // on screen, so the answer is simply the current page.
    function hoveredPageAt(x) {
        if (!expanded)
            return page
        let start = 0
        for (const candidate of pageOrder) {
            if (!cardVisible(candidate))
                continue
            const span = iconSize * unitsFor(candidate) + cardGap + cardSpacing
            if (x >= start && x < start + span)
                return candidate
            start += span
        }
        return page
    }

    Component.onCompleted: ensureValidPage(showClock)
    onHasMusicChanged: ensureValidPage(false)
    onHasWeatherChanged: ensureValidPage(false)
    onShowClockChanged: ensureValidPage(showClock)
    onShowTemperatureChanged: ensureValidPage(false)
    onCardMusicChanged: ensureValidPage(false)
    onCardWeatherChanged: ensureValidPage(false)
    onCardClockChanged: ensureValidPage(showClock)
    onCardMetricsChanged: ensureValidPage(false)
    onExpandedChanged: ensureValidPage(false)

    Timer {
        id: carouselTimer
        interval: 30000
        // Nothing rotates once every card has its own place.
        running: !carousel.expanded && carousel.availablePageCount > 1
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
            if (carousel.expanded)
                return
            const delta = wheel.angleDelta.y + wheel.pixelDelta.y
            if (delta === 0 || wheelCooldown.running)
                return
            carousel.switchPage(true, delta >= 0 ? -1 : 1)
            wheelCooldown.restart()
            wheel.accepted = true
        }
    }

    // Zero-width anchor that tracks the card under the pointer, so the popup
    // opens above that card rather than above the middle of the whole slot.
    Item {
        id: infoAnchor
        visible: false
        y: 0
        height: carousel.height
        x: carousel.hoveredPage >= 0 ? carousel.layoutX(carousel.hoveredPage) : 0
        width: carousel.hoveredPage >= 0
            ? carousel.cardWidth(carousel.hoveredPage) : carousel.width
    }

    // Which card the pointer is over, tracked continuously: moving sideways
    // while the popup is open must swap its content at once, not close it and
    // start the open delay again.
    readonly property int pointerPage: infoHover.hovered
        ? carousel.hoveredPageAt(infoHover.point.position.x) : -1

    onPointerPageChanged: {
        if (pointerPage < 0)
            return
        if (pointerPage === carousel.musicPage) {
            // Music owns a richer popup of its own; leave it alone.
            if (infoPopup.visible)
                infoPopup.requestClose()
            return
        }
        carousel.hoveredPage = pointerPage
    }

    HoverHandler {
        id: infoHover
        onHoveredChanged: {
            if (hovered) {
                infoPopupCloseDelay.stop()
                infoPopupOpenDelay.restart()
            } else if (!infoPopup.pointerInside) {
                infoPopupOpenDelay.stop()
                infoPopupCloseDelay.restart()
            }
        }
    }

    Timer {
        id: infoPopupOpenDelay
        interval: 420
        repeat: false
        onTriggered: {
            if (!infoHover.hovered)
                return
            if (carousel.pointerPage < 0
                || carousel.pointerPage === carousel.musicPage)
                return
            DockModelService.openDockPopup(infoPopup)
        }
    }

    Timer {
        id: infoPopupCloseDelay
        interval: 260
        repeat: false
        onTriggered: {
            if (!infoHover.hovered && !infoPopup.pointerInside)
                infoPopup.requestClose()
        }
    }

    DockInfoPopup {
        id: infoPopup
        anchorItem: infoAnchor
        page: carousel.hoveredPage
        onVisibleChanged: if (!visible) DockModelService.releaseDockPopup(infoPopup)
    }

    DockMusicPlayer {
        anchors.verticalCenter: parent.verticalCenter
        iconSize: carousel.iconSize
        dockHeight: carousel.dockHeight
        widthUnits: carousel.expanded
            ? carousel.unitsFor(carousel.musicPage) : carousel.widthUnits
        visible: carousel.cardVisible(carousel.musicPage)
        enabled: carousel.isShown(carousel.musicPage)
        pageActive: carousel.isShown(carousel.musicPage)
        x: carousel.layoutX(carousel.musicPage)
        opacity: carousel.isShown(carousel.musicPage) ? 1 : 0
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    DockWeatherWidget {
        anchors.verticalCenter: parent.verticalCenter
        iconSize: carousel.iconSize
        dockHeight: carousel.dockHeight
        widthUnits: carousel.expanded
            ? carousel.unitsFor(carousel.weatherPage) : carousel.widthUnits
        visible: carousel.cardVisible(carousel.weatherPage)
        enabled: carousel.isShown(carousel.weatherPage)
        pageActive: carousel.isShown(carousel.weatherPage)
        x: carousel.layoutX(carousel.weatherPage)
        opacity: carousel.isShown(carousel.weatherPage) ? 1 : 0
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    DockClockWidget {
        anchors.verticalCenter: parent.verticalCenter
        iconSize: carousel.iconSize
        dockHeight: carousel.dockHeight
        widthUnits: carousel.expanded
            ? carousel.unitsFor(carousel.clockPage) : carousel.widthUnits
        visible: carousel.cardVisible(carousel.clockPage)
        enabled: carousel.isShown(carousel.clockPage)
        pageActive: carousel.isShown(carousel.clockPage)
        x: carousel.layoutX(carousel.clockPage)
        opacity: carousel.isShown(carousel.clockPage) ? 1 : 0
        showSeconds: carousel.clockSeconds
        showDate: carousel.clockDate
        showSolar: carousel.clockSolar
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    DockTemperatureWidget {
        anchors.verticalCenter: parent.verticalCenter
        iconSize: carousel.iconSize
        dockHeight: carousel.dockHeight
        widthUnits: carousel.expanded
            ? carousel.unitsFor(carousel.temperaturePage) : carousel.widthUnits
        visible: carousel.cardVisible(carousel.temperaturePage)
        enabled: carousel.isShown(carousel.temperaturePage)
        pageActive: carousel.isShown(carousel.temperaturePage)
        x: carousel.layoutX(carousel.temperaturePage)
        opacity: carousel.isShown(carousel.temperaturePage) ? 1 : 0
        showAverage: carousel.metricAverage
        showPeak: carousel.metricPeak
        showCpu: carousel.metricCpu
        showMemory: carousel.metricMemory
        showStorage: carousel.metricStorage
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }
}
