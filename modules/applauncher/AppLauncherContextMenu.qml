import Qt.labs.platform as Platform

// The platform owns context-menu pointer grabs, placement and dismissal.
Platform.Menu {
    id: menu

    property var application: null
    property bool menuOpen: false
    signal action(string name)

    function trigger(name) {
        menu.action(name)
        menu.close()
    }

    Platform.MenuItem { text: "打开应用"; onTriggered: menu.trigger("open") }
    Platform.MenuItem { text: "编辑应用"; onTriggered: menu.trigger("edit") }
    Platform.MenuItem { text: "固定到 Dock"; onTriggered: menu.trigger("pin") }

    onAboutToShow: menuOpen = true
    onAboutToHide: menuOpen = false
}
