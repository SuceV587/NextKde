import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.desktop.modules.common
import qs.desktop.modules.dock

// Focusable full-screen layer with a compact, centered window switcher.
PanelWindow {
    id: root

    // Distinguish this surface from other quickshell panels so the glass
    // plugin can give it its own highlight direction (kwin reads the
    // layer-shell namespace as the window class).
    WlrLayershell.namespace: "quickshell-quicksearch"

    property bool open: false
    property string mode: "window"
    property string viewMode: "list"
    property string query: ""
    property int selectedIndex: 0
    // Keep this deliberately minimal: QuickSearch is a high-frequency
    // shortcut surface, so a brief fade is clearer and faster than a sheet
    // transition or scale animation.
    property real revealProgress: open ? 1.0 : 0.0

    Behavior on revealProgress {
        NumberAnimation {
            duration: 90
            easing.type: Easing.OutCubic
        }
    }

    signal closeRequested
    signal modeCycleRequested
    signal viewModeToggleRequested

    readonly property string modeTitle: mode === "app" ? "应用" : (mode === "clipboard" ? "剪贴板" : "窗口")
    readonly property string placeholder: mode === "app" ? "搜索已安装的应用" : (mode === "clipboard" ? "搜索剪贴板历史" : "搜索已打开的窗口")

    readonly property var windowResults: {
        // Explicitly depend on the service revision so title, activation, and
        // window lifecycle changes immediately refresh the search results.
        WindowService.revision;
        const needle = query.trim().toLowerCase();
        const matches = [];
        const records = WindowService.records || [];
        for (let i = 0; i < records.length; i++) {
            const record = records[i];
            const haystack = (record.title + " " + (record.identity?.name ?? "") + " " + (record.identity?.desktopId ?? "")).toLowerCase();
            if (!needle || haystack.includes(needle))
                matches.push({
                    kind: "window",
                    title: record.title,
                    subtitle: record.identity?.name ?? record.identity?.desktopId ?? "",
                    icon: record.iconSource ?? "",
                    windowId: record.windowId
                });
        }
        matches.sort((left, right) => left.title.localeCompare(right.title));
        return matches;
    }
    readonly property var appResults: {
        AppPresentationService.catalogRevision;
        AppPresentationService.revision;
        const needle = query.trim().toLowerCase();
        const matches = [];
        const catalogue = AppPresentationService.catalog();
        for (let i = 0; i < catalogue.length; i++) {
            const presentation = catalogue[i];
            const title = presentation.displayName;
            const haystack = (title + " " + presentation.desktopId).toLowerCase();
            if (!needle || haystack.includes(needle)) {
                matches.push({
                    kind: "app",
                    title: title,
                    subtitle: presentation.desktopId,
                    icon: presentation.iconSource,
                    entry: presentation.entry
                });
            }
        }
        return matches;
    }
    readonly property var clipboardResults: {
        ClipboardService.revision;
        const needle = query.trim().toLowerCase();
        const matches = [];
        const entries = ClipboardService.entries || [];
        for (let i = 0; i < entries.length; i++) {
            const entry = entries[i];
            if (!needle || entry.preview.toLowerCase().includes(needle)) {
                matches.push({
                    kind: "clipboard",
                    title: entry.isImage ? "图片" : entry.preview,
                    subtitle: entry.isImage ? "图片剪贴板 · " + entry.preview.slice(2, -2) : "文本剪贴板 · 回车复制",
                    icon: Quickshell.iconPath(entry.isImage ? "image-x-generic" : "edit-paste", true) || "",
                    isImage: entry.isImage,
                    selectionRecord: entry.record
                });
            }
        }
        return matches;
    }
    readonly property var results: mode === "app" ? appResults : (mode === "clipboard" ? clipboardResults : windowResults)
    readonly property int resultCount: results.length
    readonly property int visibleResultCount: Math.min(6, resultCount)
    readonly property int gridColumnCount: 5
    readonly property int visibleGridRowCount: Math.min(3, Math.ceil(resultCount / gridColumnCount))

    visible: open
    color: "transparent"
    focusable: true
    // Blur only the compact search card; the rest of the screen remains an
    // untouched, transparent Spotlight-style surface.
    BackgroundEffect.blurRegion: RoundedBlurRegion {
        item: dialog
        radius: dialog.radius
    }
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // iOS App-Library style liquid header band, mirroring the launcher's
    // LiquidSearchBar. The whole top strip is one continuous frosted lens over
    // the result view: it captures the region directly beneath the band and
    // blurs whatever entries scroll under it, so the entire top flows with
    // content. The capture rect tracks the view's contentY so the lens always
    // shows the live content below. The search field floats centered on this
    // band as a liquid-glass capsule, so there is no seam between the field
    // and its flanks.
    component LiquidSearchBand: Item {
        id: searchBand
        // The result view (ListView or GridView) whose scrolling content this
        // lens frosts over. Both are Flickables, so a Flickable reference
        // exposes contentY and lets the band follow whichever viewMode is
        // active.
        required property Flickable sourceView
        // The band spans the header's full width; only its height is fixed.
        height: 49

        // Region of the result view directly beneath this band, in the view's
        // own (viewport) coordinates. A Flickable is captured as its rendered
        // viewport - the visible window already reflects contentY - so the
        // source rect must NOT add contentY again.
        //
        // The band floats above the view's top edge, so mapping it into the
        // view gives a negative y: the band sits over the view's empty top
        // margin. That is exactly what we want to frost. Before any scrolling
        // the slice over the view is empty, so the band rests on clean glass;
        // as entries scroll up they slide into the band's slice and become its
        // flowing background. Pixels outside the view's bounds capture as
        // transparent, which simply shows the dialog's blurred backdrop.
        readonly property rect _lensRect: {
            if (!sourceView)
                return Qt.rect(0, 0, 0, 0)
            const topLeft = searchBand.mapToItem(sourceView, 0, 0)
            return Qt.rect(topLeft.x, topLeft.y,
                searchBand.width, searchBand.height)
        }

        ShaderEffectSource {
            id: lensSource
            visible: false
            sourceItem: searchBand.sourceView
            sourceRect: searchBand._lensRect
            live: true
            hideSource: false
            smooth: true
        }
        FastBlur {
            id: lensBlur
            anchors.fill: parent
            source: lensSource
            radius: 16
            transparentBorder: true
            cached: true
        }
        // Clip the blur to the card's own top corners and let the bottom fade
        // out, so the band reads as the card's top edge itself rather than a
        // separate rounded pill floating over it. The mask is a vertical
        // gradient: fully opaque at the top, transparent at the bottom.
        OpacityMask {
            anchors.fill: parent
            source: lensBlur
            maskSource: lensFade
        }
        Item {
            id: lensFade
            anchors.fill: parent
            visible: false
            layer.enabled: true
            // Rounded only at the top corners (matching the card radius) so
            // the band's upper edge merges with the card outline.
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                height: parent.height
                radius: 20
                // Extend below the band so only the top corners stay rounded;
                // the bottom edge is handled by the fade, not a hard corner.
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: "white" }
                    GradientStop { position: 0.55; color: "white" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }

    function reset() {
        query = "";
        // Window mode opens with the most recently used window selected (the
        // first MRU result); Alt+Tab proposes the previous window immediately.
        selectedIndex = 0;
        focusTimer.restart();
        if (mode === "clipboard")
            clipboardTopTimer.restart();
    }

    function moveSelection(delta) {
        if (resultCount === 0)
            return;
        selectedIndex = (selectedIndex + delta + resultCount) % resultCount;
        if (viewMode === "grid")
            gridView.positionViewAtIndex(selectedIndex, GridView.Contain);
        else
            resultView.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function activateSelection() {
        if (selectedIndex < 0 || selectedIndex >= resultCount)
            return;
        const result = results[selectedIndex];
        if (result.kind === "window") {
            // Use the Dock facade so its shared active indicator can begin
            // travelling before this focusable search layer closes.
            DockModelService.activateWindow(result.windowId);
        } else if (result.kind === "clipboard") {
            ClipboardService.copy(result.selectionRecord);
        } else {
            AppActionService.launch(result.entry);
        }
        closeRequested();
    }

    onOpenChanged: {
        if (open) {
            reset();
            if (mode === "clipboard")
                ClipboardService.refresh();
        }
    }
    onModeChanged: {
        if (open)
            reset();
    }
    onResultsChanged: {
        if (selectedIndex >= resultCount)
            selectedIndex = Math.max(0, resultCount - 1);
    }
    Timer {
        id: focusTimer
        interval: 1
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    // ListView/GridView retain their previous content position when their
    // model stays alive. Clipboard mode should always reveal the newest entry
    // as soon as it is opened or selected with Tab.
    Timer {
        id: clipboardTopTimer
        interval: 1
        repeat: false
        onTriggered: {
            if (root.mode !== "clipboard")
                return;
            if (root.viewMode === "grid")
                gridView.positionViewAtBeginning();
            else
                resultView.positionViewAtBeginning();
        }
    }

    // A copy can arrive while the palette is already open. Refreshing the
    // light-weight cliphist index here makes it appear without reopening.
    Timer {
        interval: 800
        repeat: true
        running: root.open && root.mode === "clipboard"
        onTriggered: ClipboardService.refresh()
    }

    // There is intentionally no dimmed visual overlay. This transparent input
    // catcher preserves the natural Spotlight behaviour: a click outside the
    // compact search card simply dismisses it.
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.closeRequested()
    }

    Rectangle {
        id: dialog
        width: 580
        height: root.resultCount > 0
            ? 14 + (root.viewMode === "grid" ? gridView.height : resultView.height) + 8
            : searchHeader.height + 46
        // Shared readability outline so white/foreground text stays legible on
        // light wallpapers where KWin tint alone isn't enough. Mirrors the
        // notification card's textOutlineColor convention.
        readonly property color textOutlineColor: Qt.rgba(0.05, 0.08, 0.12, 0.38)
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: Math.round(parent.height * 0.16)
        }
        radius: 28
        color: "transparent"
        opacity: root.revealProgress

        // LiquidGlassSurface temporarily disabled to isolate KWin effect rendering.
        // LiquidGlassSurface {
        //     anchors.fill: parent
        //     radius: dialog.radius
        //     baseColor: ThemeService.backgroundColor
        //     surfaceOpacity: 1.0
        //     ambientPrimary: WallpaperPaletteService.primary
        //     ambientSecondary: WallpaperPaletteService.secondary
        //     ambientStrength: 0.82
        //     materialDepth: 0.0
        // }

        // Rectangle {
        //     anchors.fill: parent
        //     radius: dialog.radius
        //     color: "transparent"
        //     border.width: 0
        //     border.color: Qt.rgba(1, 1, 1, 0.36)
        // }

        Item {
            id: searchHeader
            width: parent.width
            height: 49
            // Float above the result views so the liquid band frosts over them
            // instead of pushing them down in the layout.
            z: 1

            // The liquid band is the header's background: it blurs whatever
            // result content scrolls beneath it.
            LiquidSearchBand {
                id: searchBand
                anchors.fill: parent
                sourceView: root.viewMode === "grid" ? gridView : resultView
            }

            // The editable search field: a liquid-glass capsule resting in the
            // flowing band. The base stays faint so the band's own blur shows
            // through the body, keeping the capsule translucent and in tune
            // with the flowing strip instead of reading as a solid dark plate.
            // The bottom shade is dropped (it is what made the pill look
            // heavy); the specular top reflection and wallpaper tint keep the
            // liquid finish. A faint focus ring marks it as editable.
            LiquidGlassSurface {
                id: fieldPill
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 14
                    rightMargin: 14
                    top: parent.top
                    topMargin: 9
                }
                height: 35
                radius: height / 2
                baseColor: Qt.rgba(1, 1, 1, 0.07)
                surfaceOpacity: 1.0
                materialDepth: 1.0
                bottomShadeVisible: false
                ambientPrimary: WallpaperPaletteService.primary
                ambientSecondary: WallpaperPaletteService.secondary
                ambientStrength: 0.8

                // Inner top-edge glow: a thin bright line hugging the capsule's
                // upper rim, the hallmark of iOS liquid components.
                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        leftMargin: fieldPill.radius * 0.7
                        rightMargin: fieldPill.radius * 0.7
                    }
                    height: 1
                    radius: 0.5
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
                        GradientStop { position: 0.25; color: Qt.rgba(1, 1, 1, 0.28) }
                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.4) }
                        GradientStop { position: 0.75; color: Qt.rgba(1, 1, 1, 0.28) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                    }
                }

                // Focus ring over the glass body.
                Rectangle {
                    anchors.fill: parent
                    radius: fieldPill.radius
                    color: "transparent"
                    border.width: searchInput.activeFocus ? 1 : 0
                    border.color: Qt.rgba(1, 1, 1, 0.4)
                }
            }

            Text {
                anchors {
                    left: fieldPill.left
                    leftMargin: 14
                    verticalCenter: fieldPill.verticalCenter
                }
                text: "⌕"
                color: Qt.rgba(1, 1, 1, 0.72)
                font.pixelSize: 20
                style: Text.Outline
                styleColor: dialog.textOutlineColor
            }

            TextInput {
                id: searchInput
                anchors {
                    left: fieldPill.left
                    leftMargin: 44
                    right: fieldPill.right
                    rightMargin: 130
                    verticalCenter: fieldPill.verticalCenter
                }
                color: "white"
                font {
                    family: "Noto Sans CJK SC"
                    pixelSize: 15
                }
                clip: true
                selectByMouse: true
                text: root.query
                onTextEdited: {
                    root.query = text;
                    root.selectedIndex = 0;
                }
                Keys.onPressed: function (event) {
                    const control = (event.modifiers & Qt.ControlModifier) !== 0;
                    if (event.key === Qt.Key_Down || (control && event.key === Qt.Key_N)) {
                        root.moveSelection(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up || (control && event.key === Qt.Key_P)) {
                        root.moveSelection(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.activateSelection();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        root.closeRequested();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Tab) {
                        root.modeCycleRequested();
                        event.accepted = true;
                    }
                }

                Text {
                    anchors.fill: parent
                    visible: !searchInput.text
                    text: root.placeholder
                    color: Qt.rgba(1, 1, 1, 0.54)
                    font: searchInput.font
                    verticalAlignment: Text.AlignVCenter
                    style: Text.Outline
                    styleColor: dialog.textOutlineColor
                }
            }

            Row {
                anchors {
                    right: fieldPill.right
                    rightMargin: 12
                    verticalCenter: fieldPill.verticalCenter
                }
                spacing: 8

                Text {
                    text: root.modeTitle + (root.mode === "clipboard" ? " · 最新优先" : "") + " · Tab"
                    color: Qt.rgba(1, 1, 1, 0.46)
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                    style: Text.Outline
                    styleColor: dialog.textOutlineColor
                }

                Item {
                    width: 24
                    height: 24

                    Rectangle {
                        anchors.fill: parent
                        radius: 7
                        color: viewToggle.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        // The button advertises the layout selected by a click.
                        text: root.viewMode === "list" ? "▦" : "☷"
                        color: Qt.rgba(1, 1, 1, 0.76)
                        font.pixelSize: 18
                        style: Text.Outline
                        styleColor: dialog.textOutlineColor
                    }

                    MouseArea {
                        id: viewToggle
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.viewModeToggleRequested()
                    }
                }
            }
        }

        ListView {
            id: resultView
            visible: root.viewMode === "list"
            // Align the view's top with the liquid band's top so the band's
            // capture rect (y = 0) always lands inside the view's bounds - a
            // stable, flicker-free lens. The Flickable topMargin offsets the
            // first entry to just below the band (the same on-screen spot it
            // had before), so the band frosts the empty margin at rest and
            // frosts entries as they scroll up under it.
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 14
                leftMargin: 8
                rightMargin: 8
            }
            topMargin: 49
            height: 49 + root.visibleResultCount * 52
            clip: true
            model: root.results
            currentIndex: root.selectedIndex

            delegate: Item {
                id: resultItem
                required property var modelData
                required property int index
                width: resultView.width
                height: 52

                Rectangle {
                    anchors.fill: parent
                    radius: 20
                    color: resultItem.index === root.selectedIndex ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                }

                Rectangle {
                    width: 30
                    height: 30
                    radius: 8
                    anchors {
                        left: parent.left
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    visible: resultItem.modelData.isImage ?? false
                    color: Qt.rgba(0.30, 0.56, 0.94, 0.34)
                    border.width: 1
                    border.color: Qt.rgba(0.66, 0.82, 1, 0.42)
                }

                AppIcon {
                    width: resultItem.modelData.isImage ? 20 : 30
                    height: width
                    anchors {
                        left: parent.left
                        leftMargin: resultItem.modelData.isImage ? 17 : 12
                        verticalCenter: parent.verticalCenter
                    }
                    source: resultItem.modelData.icon ?? ""
                }

                Column {
                    anchors {
                        left: parent.left
                        leftMargin: 54
                        right: parent.right
                        rightMargin: root.mode === "clipboard" && resultItem.index === 0 ? 62 : 12
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 1

                    Text {
                        width: parent.width
                        text: resultItem.modelData.title
                        color: "white"
                        elide: Text.ElideRight
                        font {
                            pixelSize: 14
                            weight: Font.DemiBold
                        }
                        style: Text.Outline
                        styleColor: dialog.textOutlineColor
                    }

                    Text {
                        width: parent.width
                        text: resultItem.modelData.subtitle
                        color: Qt.rgba(1, 1, 1, 0.68)
                        elide: Text.ElideRight
                        font.pixelSize: 11
                        style: Text.Outline
                        styleColor: dialog.textOutlineColor
                    }
                }

                Rectangle {
                    visible: root.mode === "clipboard" && resultItem.index === 0
                    width: 38
                    height: 18
                    radius: 9
                    anchors {
                        right: parent.right
                        rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    color: Qt.rgba(0.30, 0.56, 0.94, 0.32)
                    border.width: 1
                    border.color: Qt.rgba(0.66, 0.82, 1, 0.40)

                    Text {
                        anchors.centerIn: parent
                        text: "最新"
                        color: Qt.rgba(0.84, 0.93, 1, 0.94)
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        style: Text.Outline
                        styleColor: dialog.textOutlineColor
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.selectedIndex = resultItem.index
                    onClicked: {
                        root.selectedIndex = resultItem.index;
                        root.activateSelection();
                    }
                }
            }
        }

        GridView {
            id: gridView
            visible: root.viewMode === "grid"
            // Same alignment as the list view: the view's top matches the
            // liquid band's top, and the Flickable topMargin offsets the first
            // row just below the band so the lens is stable and flicker-free.
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 14
                leftMargin: 8
                rightMargin: 8
            }
            topMargin: 49
            height: 49 + root.visibleGridRowCount * 94
            cellWidth: width / root.gridColumnCount
            cellHeight: 94
            clip: true
            model: root.results
            currentIndex: root.selectedIndex

            delegate: Item {
                id: gridResultItem
                required property var modelData
                required property int index
                width: gridView.cellWidth
                height: gridView.cellHeight

                Rectangle {
                    anchors {
                        fill: parent
                        margins: 3
                    }
                    radius: 11
                    color: gridResultItem.index === root.selectedIndex ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                }

                Rectangle {
                    visible: root.mode === "clipboard" && gridResultItem.index === 0
                    width: 34
                    height: 17
                    radius: 8.5
                    anchors {
                        right: parent.right
                        rightMargin: 7
                        top: parent.top
                        topMargin: 7
                    }
                    color: Qt.rgba(0.30, 0.56, 0.94, 0.36)

                    Text {
                        anchors.centerIn: parent
                        text: "最新"
                        color: Qt.rgba(0.84, 0.93, 1, 0.96)
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                        style: Text.Outline
                        styleColor: dialog.textOutlineColor
                    }
                }

                Rectangle {
                    width: 50
                    height: 50
                    radius: 13
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.top
                        topMargin: 5
                    }
                    visible: gridResultItem.modelData.isImage ?? false
                    color: Qt.rgba(0.30, 0.56, 0.94, 0.34)
                    border.width: 1
                    border.color: Qt.rgba(0.66, 0.82, 1, 0.42)
                }

                AppIcon {
                    width: gridResultItem.modelData.isImage ? 34 : 42
                    height: width
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.top
                        topMargin: gridResultItem.modelData.isImage ? 13 : 9
                    }
                    source: gridResultItem.modelData.icon ?? ""
                }

                Text {
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: 7
                        rightMargin: 7
                        top: parent.top
                        topMargin: 56
                    }
                    text: gridResultItem.modelData.title
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    font {
                        pixelSize: 11
                        weight: Font.DemiBold
                    }
                    style: Text.Outline
                    styleColor: dialog.textOutlineColor
                }

                Text {
                    visible: gridResultItem.modelData.isImage ?? false
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: 6
                        rightMargin: 6
                        top: parent.top
                        topMargin: 71
                    }
                    text: gridResultItem.modelData.subtitle.replace("图片剪贴板 · ", "")
                    color: Qt.rgba(1, 1, 1, 0.54)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    font.pixelSize: 9
                    style: Text.Outline
                    styleColor: dialog.textOutlineColor
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.selectedIndex = gridResultItem.index
                    onClicked: {
                        root.selectedIndex = gridResultItem.index;
                        root.activateSelection();
                    }
                }
            }
        }

        Text {
            visible: root.resultCount === 0
            anchors {
                top: parent.top
                topMargin: 49
                left: parent.left
                right: parent.right
            }
            height: 40
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.mode === "app" ? "未找到匹配的应用" : (root.mode === "clipboard" ? "剪贴板历史为空" : "未找到匹配的窗口")
            color: Qt.rgba(1, 1, 1, 0.52)
            font.pixelSize: 13
            style: Text.Outline
            styleColor: dialog.textOutlineColor
        }
    }
}
