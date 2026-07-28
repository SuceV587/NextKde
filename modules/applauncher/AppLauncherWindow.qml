import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.modules.common

// Output-bound application-launcher surface. The panel itself spans the
// output only to make centering reliable. The visible glass card follows Dock
// once it is large enough, but keeps a usable minimum at initial/small sizes.
PanelWindow {
    id: root

    // The module root passes this state explicitly (as QuickSearch does) so
    // every output-bound variant shares one reliable visibility binding.
    property bool open: false
    Component.onCompleted: console.log("[AppLauncherWindow] created")
    onOpenChanged: console.log("[AppLauncherWindow] received open=" + open)
    onScreenChanged: console.log("[AppLauncherWindow] screen changed=" + !!screen)
    readonly property real minimumLauncherWidth: 600
    readonly property real minimumLauncherHeight: 500
    readonly property bool usesMinimumSize:
        AppLauncherService.dockWidth < minimumLauncherWidth
    // A fresh Dock can be narrow before windows/pinned apps appear. Do not let
    // that transient Dock state make the independent app launcher unusable.
    readonly property real launcherWidth: usesMinimumSize
        ? minimumLauncherWidth : AppLauncherService.dockWidth
    readonly property real launcherHeight: usesMinimumSize
        ? minimumLauncherHeight : Math.round(screen.height * 0.50)
    // DesktopEntries is the authoritative installed-app source. Keep this
    // module independent from Dock identity/window services: folders, search,
    // and launcher-specific personalization will build on this raw catalog.
    property int appCatalogRevision: 0
    // Resolving every themed icon again after one app edit can stall a large
    // launcher grid for seconds. Cache by requested source; a new custom icon
    // naturally uses a new key and resolves once without blocking the UI.
    property var _iconSourceCache: ({})
    function resolveApplicationIcon(appId, requestedIcon) {
        const value = String(requestedIcon ?? "")
        const key = String(appId ?? "") + "\u0000" + value
        if (_iconSourceCache[key] !== undefined)
            return _iconSourceCache[key]
        const resolved = Quickshell.iconPath(value, true) || value
        _iconSourceCache[key] = resolved
        return resolved
    }
    readonly property var applications: {
        // This window stays instantiated while hidden. Do not enumerate every
        // desktop entry or resolve its icon until the launcher is actually
        // opened; otherwise DesktopEntries updates rebuild the hidden grid and
        // stall the whole shell.
        if (!root.open)
            return []
        appCatalogRevision
        const entries = DesktopEntries.applications?.values ?? []
        const apps = []
        for (let i = 0; i < entries.length; i++) {
            const entry = entries[i]
            if (!entry || entry.noDisplay)
                continue
            const appId = entry.id ?? ""
            if (!appId || AppLauncherConfigService.hiddenAppIds.indexOf(appId) >= 0)
                continue
            const defaultName = entry.name ?? appId ?? "应用程序"
            const iconName = entry.icon ?? ""
            const defaultIcon = Quickshell.iconPath(iconName, true) || iconName
            const override = AppLauncherConfigService.appOverrides[appId] || ({})
            const requestedIcon = override.icon || defaultIcon
            apps.push({
                id: appId,
                name: override.name || defaultName,
                icon: root.resolveApplicationIcon(appId, requestedIcon),
                defaultName: defaultName,
                defaultIcon: defaultIcon,
                entry: entry,
            })
        }
        apps.sort((left, right) => left.name.localeCompare(right.name))
        return apps
    }
    property string query: ""
    property int selectedIndex: 0
    // Long press enters an iPadOS-like editing state. This is launcher-local:
    // it never changes the Dock's separate pinned-app edit mode.
    property bool editMode: false
    readonly property var orderedApplications:
        AppLauncherConfigService.orderedApplications(applications)
    readonly property var rootGridItems:
        AppLauncherConfigService.rootGridItems(applications)
    property var openFolder: null
    // Keep a stable snapshot during the close animation. `openFolder` remains
    // the live persistence target; `displayedFolder` is only presentation.
    property var displayedFolder: null
    property bool folderDialogOpen: false
    property bool folderRenameActive: false
    property string folderRenameText: ""
    property var editingApplication: null
    property string editorName: ""
    property string editorIcon: ""
    property string editorIconStatus: ""
    // Native file choosers are ordinary toplevel dialogs. Temporarily lower
    // this layer-shell surface and release its keyboard focus so the chooser
    // can sit above it and receive input on Hyprland.
    property bool externalDialogOpen: false
    // Folder editing is intentionally independent from root edit mode: the
    // root grid must not start wiggling behind an open folder dialog.
    property bool folderEditMode: false
    // Reordering updates the GridView model asynchronously. Preserve its
    // viewport across that update so a drag release never looks like the
    // launcher panel itself has jumped vertically.
    property real pendingGridContentY: -1
    // Root-grid drag preview is presentation-only. The persisted model changes
    // once on release; these indices make neighboring tiles smoothly reserve
    // the prospective slot while the pointer is moving.
    property int rootDragSourceIndex: -1
    property int rootDragTargetIndex: -1
    // Folder creation is intentionally a slower gesture than sorting. A tile
    // only becomes a merge target after the dragged app rests on it briefly.
    property string folderMergeTargetKey: ""
    property bool folderMergeArmed: false
    readonly property var filteredApplications: {
        const needle = query.trim().toLowerCase()
        if (!needle)
            return rootGridItems
        return orderedApplications.filter(function(app) {
            return (app.name + " " + app.id).toLowerCase().includes(needle)
        }).map(function(app) { return { type: "app", app: app } })
    }

    function launchApplication(app) {
        try {
            dismissApplicationMenu()
            app.entry.execute()
            // Launching an app completes this first-stage launcher flow.
            // Future settings can make this behavior configurable.
            AppLauncherService.hide()
        } catch (error) {
            console.warn("[AppLauncher] failed to launch " + app.id + ": " + error)
        }
    }

    function showApplicationMenu(app, anchorItem) {
        if (!app || !anchorItem)
            return
        // PopupWindow calculates its Wayland anchor when it becomes visible.
        // Reassigning `anchor.item` while visible leaves many compositors at
        // the old position, so always close then reopen on the next frame.
        if (appContextMenu.visible
                && appContextMenu.application
                && appContextMenu.application.id === app.id) {
            dismissApplicationMenu()
            return
        }
        appContextMenu.visible = false
        appContextMenu.application = app
        appContextMenu.anchorItem = anchorItem
        applicationMenuOpenTimer.restart()
        console.log("[AppLauncher] menu request app=" + app.id)
    }

    function dismissApplicationMenu() {
        applicationMenuOpenTimer.stop()
        if (appContextMenu.visible)
            console.log("[AppLauncher] menu dismiss app="
                + (appContextMenu.application?.id || ""))
        appContextMenu.visible = false
    }

    function showApplicationEditor(app) {
        if (!app)
            return
        dismissApplicationMenu()
        editingApplication = app
        editorName = app.name
        // Store the editable source form, not the resolved theme path, so an
        // icon theme change can still resolve a user-entered icon name.
        editorIcon = (AppLauncherConfigService.appOverrides[app.id] || ({})).icon
            || app.defaultIcon
        editorIconStatus = ""
        appEditorNameFocusTimer.restart()
    }

    function closeApplicationEditor() {
        editingApplication = null
        editorName = ""
        editorIcon = ""
        editorIconStatus = ""
    }

    function saveApplicationEditor() {
        if (!editingApplication)
            return
        console.log("[AppLauncher] save editor app=" + editingApplication.id
            + " icon=" + editorIcon)
        AppLauncherConfigService.updateAppOverride(editingApplication.id,
            editorName, editorIcon, editingApplication.defaultName,
            editingApplication.defaultIcon)
        closeApplicationEditor()
    }

    function hideEditedApplication() {
        if (!editingApplication)
            return
        AppLauncherConfigService.hideApplication(editingApplication.id)
        closeApplicationEditor()
    }

    function chooseCustomIcon() {
        if (editingApplication) {
            editorIconStatus = ""
            customIconFileDialog.open()
        }
    }

    function pasteClipboardIcon() {
        if (!editingApplication)
            return
        editorIconStatus = "正在从剪贴板导入 PNG…"
        AppLauncherConfigService.importClipboardPngIcon(editingApplication.id)
    }

    function showFolder(folder) {
        dismissApplicationMenu()
        displayedFolder = folder
        openFolder = folder
        // Opening a folder from root edit mode continues the same editing
        // session, so its children are immediately sortable/removable.
        folderEditMode = editMode
        folderRenameActive = false
        folderRenameText = folder.name
        // Let the modal be constructed at its collapsed state first; the next
        // event-loop turn then drives the visible opening transition.
        folderDialogOpen = false
        folderOpenTimer.restart()
    }

    function closeFolder() {
        if (!displayedFolder)
            return
        folderEditMode = false
        folderRenameActive = false
        folderDialogOpen = false
        folderCloseTimer.restart()
    }

    function beginFolderRename() {
        if (!openFolder)
            return
        folderRenameText = openFolder.name
        folderRenameActive = true
        folderRenameFocusTimer.restart()
    }

    function commitFolderRename() {
        if (!openFolder)
            return
        const name = folderRenameText.trim() || "文件夹"
        AppLauncherConfigService.renameFolder(openFolder.id, name)
        const refreshed = rootGridItems.find(function(item) {
            return item.type === "folder" && item.id === root.openFolder.id
        })
        if (refreshed) {
            openFolder = refreshed
            displayedFolder = refreshed
            folderRenameText = refreshed.name
        }
        folderRenameActive = false
    }

    function moveSelection(delta) {
        const count = filteredApplications.length
        if (count === 0)
            return
        selectedIndex = (selectedIndex + delta + count) % count
        appGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
    }

    function activateSelected() {
        const item = filteredApplications[selectedIndex]
        if (!item)
            return
        if (item.type === "folder")
            showFolder(item)
        else
            launchApplication(item.app)
    }

    function dragTargetIndex(delegate) {
        const centerX = delegate.x + delegate.width / 2 + delegate.lastDragX
        const centerY = delegate.y + delegate.height / 2 + delegate.lastDragY
        const column = Math.max(0, Math.min(appGrid.columnCount - 1,
            Math.floor(centerX / appGrid.cellWidth)))
        const row = Math.max(0, Math.floor(centerY / appGrid.cellHeight))
        return Math.max(0, Math.min(filteredApplications.length - 1,
            row * appGrid.columnCount + column))
    }

    function rootPreviewOffset(index) {
        const source = rootDragSourceIndex
        const target = rootDragTargetIndex
        if (source < 0 || target < 0 || source === target)
            return { x: 0, y: 0 }
        let previewIndex = index
        if (target > source && index > source && index <= target)
            previewIndex = index - 1
        else if (target < source && index >= target && index < source)
            previewIndex = index + 1
        if (previewIndex === index)
            return { x: 0, y: 0 }
        const originalX = (index % appGrid.columnCount) * appGrid.cellWidth
        const originalY = Math.floor(index / appGrid.columnCount) * appGrid.cellHeight
        const previewX = (previewIndex % appGrid.columnCount) * appGrid.cellWidth
        const previewY = Math.floor(previewIndex / appGrid.columnCount) * appGrid.cellHeight
        return { x: previewX - originalX, y: previewY - originalY }
    }

    function _itemKey(item) {
        return item && item.type === "folder"
            ? "folder:" + item.id
            : (item && item.type === "app" ? "app:" + item.app.id : "")
    }

    function potentialFolderDropTarget(appId, delegate) {
        const target = dragTargetIndex(delegate)
        const candidate = filteredApplications[target]
        if (!candidate || (candidate.type === "app" && candidate.app.id === appId))
            return null
        const targetColumn = target % appGrid.columnCount
        const targetRow = Math.floor(target / appGrid.columnCount)
        const targetX = targetColumn * appGrid.cellWidth + appGrid.cellWidth / 2
        const targetY = targetRow * appGrid.cellHeight + appGrid.cellHeight / 2
        const dragX = delegate.x + delegate.width / 2 + delegate.lastDragX
        const dragY = delegate.y + delegate.height / 2 + delegate.lastDragY
        // Match the actual 82×96px icon card rather than using a tiny radial
        // threshold. A drop visually over the target icon must never fall
        // through to the ordinary reorder path.
        const insideTargetCard = Math.abs(dragX - targetX)
                <= Math.min(41, appGrid.cellWidth * 0.42)
            && Math.abs(dragY - targetY)
                <= Math.min(48, appGrid.cellHeight * 0.42)
        return insideTargetCard ? candidate : null
    }

    function updateFolderMergeCandidate(appId, delegate) {
        const candidate = potentialFolderDropTarget(appId, delegate)
        const key = _itemKey(candidate)
        if (key === folderMergeTargetKey)
            return
        folderMergeTargetKey = key
        folderMergeArmed = false
        folderMergeTimer.stop()
        if (key)
            folderMergeTimer.restart()
    }

    function clearFolderMergeCandidate() {
        folderMergeTimer.stop()
        folderMergeTargetKey = ""
        folderMergeArmed = false
    }

    function folderDropTarget(appId, delegate) {
        const candidate = potentialFolderDropTarget(appId, delegate)
        return folderMergeArmed && _itemKey(candidate) === folderMergeTargetKey
            ? candidate : null
    }

    function commitApplicationDrag(appId, delegate) {
        // Reordering a filtered search result would make target indices
        // ambiguous in the complete persisted catalog. Exit search first.
        if (query.length > 0)
            return
        const preservedGridContentY = appGrid.contentY
        const folderTarget = folderDropTarget(appId, delegate)
        const changed = folderTarget
            ? (folderTarget.type === "folder"
                ? AppLauncherConfigService.addApplicationToFolder(
                    appId, folderTarget.id, applications)
                : AppLauncherConfigService.createFolder(
                    appId, folderTarget.app.id, applications))
            : AppLauncherConfigService.moveApplication(
                appId, dragTargetIndex(delegate), applications)
        if (changed) {
            pendingGridContentY = preservedGridContentY
            gridScrollRestore.restart()
            console.log(folderTarget
                ? (folderTarget.type === "folder"
                    ? "[AppLauncher] added app=" + appId
                        + " folder=" + folderTarget.id
                    : "[AppLauncher] created folder source=" + appId
                        + " target=" + folderTarget.app.id)
                : "[AppLauncher] reordered app=" + appId)
        }
    }

    function commitRootItemDrag(item, delegate) {
        if (item.type === "app") {
            commitApplicationDrag(item.app.id, delegate)
        } else if (!query.length) {
            const preservedGridContentY = appGrid.contentY
            const changed = AppLauncherConfigService.moveRootItem(
                "folder", item.id, dragTargetIndex(delegate), applications)
            if (changed) {
                pendingGridContentY = preservedGridContentY
                gridScrollRestore.restart()
                console.log("[AppLauncher] reordered folder=" + item.id)
            }
        }
        rootDragSourceIndex = -1
        rootDragTargetIndex = -1
        clearFolderMergeCandidate()
    }

    function folderDragTargetIndex(delegate) {
        const centerX = delegate.x + delegate.width / 2 + delegate.lastDragX
        const centerY = delegate.y + delegate.height / 2 + delegate.lastDragY
        const column = Math.max(0, Math.min(folderGrid.columnCount - 1,
            Math.floor(centerX / folderGrid.cellWidth)))
        const row = Math.max(0, Math.floor(centerY / folderGrid.cellHeight))
        return Math.max(0, Math.min(folderGrid.count - 1,
            row * folderGrid.columnCount + column))
    }

    function commitFolderApplicationDrag(appId, delegate) {
        if (!openFolder)
            return
        const changed = AppLauncherConfigService.moveApplicationWithinFolder(
            appId, openFolder.id, folderDragTargetIndex(delegate))
        if (!changed)
            return
        // The projection is regenerated from persisted data immediately after
        // every mutation; retain the dialog identity by its stable folder id.
        const refreshed = rootGridItems.find(function(item) {
            return item.type === "folder" && item.id === root.openFolder.id
        })
        openFolder = refreshed || null
        displayedFolder = refreshed || displayedFolder
        console.log("[AppLauncher] reordered folder app=" + appId)
    }

    function removeFolderApplication(appId) {
        if (!openFolder)
            return
        const folderId = openFolder.id
        if (!AppLauncherConfigService.removeApplicationFromFolder(appId, folderId))
            return
        const refreshed = rootGridItems.find(function(item) {
            return item.type === "folder" && item.id === folderId
        })
        openFolder = refreshed || null
        if (!openFolder) {
            folderEditMode = false
            closeFolder()
        } else {
            displayedFolder = refreshed
        }
    }

    visible: root.open && AppLauncherService.dockWidth > 0
    onVisibleChanged: {
        console.log("[AppLauncherWindow] visible=" + visible
            + " card=" + launcherWidth + "x" + launcherHeight)
        if (visible) {
            selectedIndex = 0
            searchFocusTimer.restart()
        } else {
            dismissApplicationMenu()
            editMode = false
            folderEditMode = false
            openFolder = null
            displayedFolder = null
            folderDialogOpen = false
        }
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    // A layer-shell Overlay is above ordinary xdg dialogs. Lower this one
    // only for the native icon chooser, then restore the launcher overlay.
    aboveWindows: !externalDialogOpen
    focusable: !externalDialogOpen
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            if (editingApplication) {
                closeApplicationEditor()
            } else if (openFolder) {
                if (folderRenameActive)
                    folderRenameActive = false
                else if (folderEditMode)
                    folderEditMode = false
                else
                    closeFolder()
            }
            else if (editMode)
                editMode = false
            else
                AppLauncherService.hide()
            event.accepted = true
        }
    }

    Timer {
        id: searchFocusTimer
        interval: 1
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    Timer {
        id: gridScrollRestore
        interval: 1
        repeat: false
        onTriggered: {
            if (root.pendingGridContentY < 0)
                return
            const maxContentY = Math.max(0, appGrid.contentHeight - appGrid.height)
            appGrid.contentY = Math.max(0, Math.min(maxContentY, root.pendingGridContentY))
            root.pendingGridContentY = -1
        }
    }

    Timer {
        id: folderMergeTimer
        interval: 450
        repeat: false
        onTriggered: {
            if (root.folderMergeTargetKey) {
                root.folderMergeArmed = true
                console.log("[AppLauncher] folder merge armed target="
                    + root.folderMergeTargetKey)
            }
        }
    }

    Timer {
        id: folderOpenTimer
        interval: 1
        repeat: false
        onTriggered: root.folderDialogOpen = true
    }

    Timer {
        id: folderRenameFocusTimer
        interval: 1
        repeat: false
        onTriggered: folderNameInput.forceActiveFocus()
    }

    Timer {
        id: appEditorNameFocusTimer
        interval: 1
        repeat: false
        onTriggered: appEditorNameInput.forceActiveFocus()
    }

    Timer {
        id: folderCloseTimer
        interval: 160
        repeat: false
        onTriggered: {
            root.openFolder = null
            root.displayedFolder = null
        }
    }

    Timer {
        id: applicationMenuOpenTimer
        interval: 1
        repeat: false
        onTriggered: {
            if (appContextMenu.application && appContextMenu.anchorItem) {
                appContextMenu.visible = true
                console.log("[AppLauncher] menu show app="
                    + appContextMenu.application.id)
            }
        }
    }

    AppLauncherContextMenu {
        id: appContextMenu
        onVisibleChanged: console.log("[AppLauncher] menu visible=" + visible
            + " app=" + (application?.id || ""))
        onAction: function(name) {
            const app = application
            if (!app)
                return
            if (name === "open")
                root.launchApplication(app)
            else if (name === "edit")
                root.showApplicationEditor(app)
            else if (name === "pin")
                AppLauncherService.requestPinToDock(app.id)
        }
    }

    Connections {
        target: AppLauncherConfigService
        function onCustomIconImportFinished(appId, path, success) {
            if (!root.editingApplication || root.editingApplication.id !== appId)
                return
            root.editorIconStatus = success
                ? "图标已导入，点击保存生效"
                : "导入失败：请确认已复制 PNG 图片，且安装了 wl-clipboard"
            if (success)
                root.editorIcon = path
        }
    }

    FileDialog {
        id: customIconFileDialog
        title: "选择应用图标"
        fileMode: FileDialog.OpenFile
        nameFilters: ["图片和 SVG (*.svg *.png *.jpg *.jpeg *.webp)", "所有文件 (*)"]
        // Bind to the actual layer-shell window rather than an editor item,
        // and make the native chooser own application input while it is open.
        parentWindow: root
        modality: Qt.ApplicationModal
        onVisibleChanged: {
            root.externalDialogOpen = visible
            console.log("[AppLauncher] icon file dialog visible=" + visible)
            if (!visible && root.editingApplication)
                appEditorNameFocusTimer.restart()
        }
        onAccepted: {
            if (!root.editingApplication)
                return
            const importedPath = AppLauncherConfigService.importCustomIcon(
                root.editingApplication.id, selectedFile)
            if (importedPath)
                root.editorIconStatus = "正在导入图标…"
        }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            // A later open reads the current DesktopEntries model directly,
            // so hidden launchers do not need to eagerly rebuild their grid.
            if (root.open)
                root.appCatalogRevision++
        }
    }

    anchors {
        left: true
        right: true
        bottom: true
    }
    // Dock is 5px above the output edge. Leave a 10px gap above its true
    // height without asking this module to reimplement Dock measurements.
    margins.bottom: AppLauncherService.dockHeight + 15
    implicitHeight: launcherHeight

    Item {
        id: launcherCard
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            bottom: parent.bottom
        }
        width: root.launcherWidth

        LiquidGlassSurface {
            id: background
            anchors.fill: parent
            radius: 18
            // Keep the launcher and Dock in one material family. The only
            // intentional visual difference is the launcher's larger radius.
            baseColor: AppLauncherService.dockBackgroundColor
            ambientPrimary: AppLauncherService.dockAmbientPrimary
            ambientSecondary: AppLauncherService.dockAmbientSecondary
            ambientStrength: 0.82

            Item {
                id: header
                enabled: root.editingApplication === null
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 22
                }
                height: 30

                Text {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    text: "应用程序"
                    color: AppLauncherService.dockForegroundColor
                    opacity: 0.90
                    font {
                        family: "SF Pro Display"
                        pixelSize: 18
                        weight: Font.DemiBold
                    }
                }

                Rectangle {
                    id: searchField
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    width: Math.min(260, Math.max(180, parent.width * 0.30))
                    height: 30
                    radius: 15
                    color: Qt.rgba(0, 0, 0, 0.16)
                    border.width: searchInput.activeFocus ? 1 : 0
                    border.color: Qt.rgba(1, 1, 1, 0.34)

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 11
                            verticalCenter: parent.verticalCenter
                        }
                        text: "⌕"
                        color: AppLauncherService.dockForegroundColor
                        opacity: 0.65
                        font.pixelSize: 17
                    }

                    TextInput {
                        id: searchInput
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 32
                            rightMargin: 10
                        }
                        color: AppLauncherService.dockForegroundColor
                        selectionColor: Qt.rgba(1, 1, 1, 0.30)
                        selectedTextColor: AppLauncherService.dockForegroundColor
                        font.pixelSize: 12
                        clip: true
                        enabled: !root.editMode && !root.openFolder
                        onTextEdited: {
                            root.dismissApplicationMenu()
                            root.query = text
                            root.selectedIndex = 0
                        }
                        Keys.onPressed: function(event) {
                            const columns = appGrid.columnCount
                            if (event.key === Qt.Key_Left) {
                                root.moveSelection(-1)
                            } else if (event.key === Qt.Key_Right) {
                                root.moveSelection(1)
                            } else if (event.key === Qt.Key_Up) {
                                root.moveSelection(-columns)
                            } else if (event.key === Qt.Key_Down) {
                                root.moveSelection(columns)
                            } else if (event.key === Qt.Key_Return
                                    || event.key === Qt.Key_Enter) {
                                root.activateSelected()
                            } else if (event.key === Qt.Key_Escape) {
                                if (root.openFolder)
                                    root.closeFolder()
                                else if (root.editMode)
                                    root.editMode = false
                                else
                                    AppLauncherService.hide()
                            } else {
                                return
                            }
                            event.accepted = true
                        }
                    }

                    Text {
                        anchors {
                            left: searchInput.left
                            verticalCenter: parent.verticalCenter
                        }
                        visible: searchInput.text.length === 0
                        text: "搜索应用"
                        color: AppLauncherService.dockForegroundColor
                        opacity: 0.45
                        font.pixelSize: 12
                    }
                }

                Text {
                    anchors {
                        right: searchField.left
                        rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    visible: root.editMode
                    text: "完成"
                    color: AppLauncherService.dockForegroundColor
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.38)
                    font {
                        pixelSize: 13
                        weight: Font.Bold
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.editMode = false
                    }
                }
            }

            GridView {
                id: appGrid
                enabled: root.editingApplication === null
                anchors {
                    top: header.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: 18
                    topMargin: 10
                }
                clip: true
                // Fill the launcher width with equal columns instead of
                // leaving a fixed-cell remainder at the right edge. The
                // minimum keeps the 600px launcher comfortably five-wide.
                readonly property int columnCount: Math.max(5,
                    Math.floor(width / 96))
                cellWidth: width > 0 ? width / columnCount : 96
                cellHeight: Math.max(106, Math.round(cellWidth * 1.06))
                model: root.open ? root.filteredApplications : []
                onMovementStarted: root.dismissApplicationMenu()

                delegate: Item {
                    id: appDelegate
                    required property var modelData
                    required property int index
                    property bool dragging: reorderDrag.active && dragReorderStarted
                    property bool heldForEdit: false
                    property bool dragReorderStarted: false
                    property real lastDragX: 0
                    property real lastDragY: 0
                    width: appGrid.cellWidth
                    height: appGrid.cellHeight
                    z: dragging ? 10 : 0
                    scale: dragging ? 1.10 : 1.0
                    opacity: dragging ? 0.90 : 1.0
                    transform: Translate {
                        x: appDelegate.dragging ? reorderDrag.translation.x
                            : root.rootPreviewOffset(index).x
                        y: appDelegate.dragging ? reorderDrag.translation.y
                            : root.rootPreviewOffset(index).y
                        Behavior on x {
                            enabled: !appDelegate.dragging
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }
                        Behavior on y {
                            enabled: !appDelegate.dragging
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        id: appCard
                        anchors.centerIn: parent
                        width: 82
                        height: 96
                        radius: 13
                        color: root.folderMergeArmed
                                && root.folderMergeTargetKey === root._itemKey(modelData)
                            ? Qt.rgba(0.36, 0.68, 1, 0.30)
                            : (index === root.selectedIndex
                                ? Qt.rgba(1, 1, 1, 0.18)
                                : (appMouse.containsMouse
                                    ? Qt.rgba(1, 1, 1, 0.12) : "transparent"))
                        rotation: 0
                        SequentialAnimation {
                            id: editWiggle
                            running: root.editMode && !appDelegate.dragging
                            loops: Animation.Infinite
                            NumberAnimation {
                                target: appCard
                                property: "rotation"
                                from: -2.2; to: 2.2; duration: 110
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                target: appCard
                                property: "rotation"
                                from: 2.2; to: -2.2; duration: 110
                                easing.type: Easing.InOutSine
                            }
                            onRunningChanged: {
                                if (!running)
                                    appCard.rotation = 0
                            }
                        }

                        IconImage {
                            visible: modelData.type === "app"
                            width: 52
                            height: 52
                            anchors {
                                top: parent.top
                                horizontalCenter: parent.horizontalCenter
                                topMargin: 8
                            }
                            source: modelData.type === "app" ? modelData.app.icon : ""
                            smooth: true
                            asynchronous: true
                        }

                        // Folder artwork is a compact 3×3 preview of its first
                        // nine apps. It intentionally stays within the same
                        // icon footprint as ordinary root applications.
                        Rectangle {
                            visible: modelData.type === "folder"
                            width: 52
                            height: 52
                            anchors {
                                top: parent.top
                                horizontalCenter: parent.horizontalCenter
                                topMargin: 8
                            }
                            radius: 12
                            color: Qt.rgba(1, 1, 1, 0.14)

                            Grid {
                                anchors.centerIn: parent
                                columns: 3
                                // 13×3 + 2×2 leaves a clear 4.5px inset
                                // inside the 52px folder tile on every side.
                                spacing: 2
                                Repeater {
                                    model: modelData.type === "folder"
                                        ? modelData.apps.slice(0, 9) : []
                                    delegate: IconImage {
                                        required property var modelData
                                        width: 13
                                        height: 13
                                        source: modelData.icon
                                        smooth: true
                                        asynchronous: true
                                    }
                                }
                            }
                        }

                        // Preserve the uninterrupted glass surface. A subtle
                        // dark outline gives the white label contrast over
                        // changing wallpaper colours without a visible plate.
                        Text {
                            id: appName
                            anchors {
                                top: parent.top
                                topMargin: 65
                                horizontalCenter: parent.horizontalCenter
                            }
                            width: Math.min(72, implicitWidth)
                            text: modelData.type === "folder"
                                ? modelData.name : modelData.app.name
                            color: AppLauncherService.dockForegroundColor
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.38)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            font {
                                pixelSize: 11
                                weight: Font.Bold
                            }
                        }

                        MouseArea {
                            id: appMouse
                            anchors.fill: parent
                            enabled: root.editingApplication === null
                            hoverEnabled: true
                            preventStealing: !root.editMode
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onPressed: appDelegate.heldForEdit = false
                            onPressAndHold: {
                                // Long press is spatial editing: it enables
                                // drag sorting and app-to-app folder creation.
                                // App settings remain a deliberate right-click
                                // menu action so the two gestures never clash.
                                appDelegate.heldForEdit = true
                                root.dismissApplicationMenu()
                                root.editMode = true
                            }
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton
                                        && modelData.type === "app") {
                                    root.showApplicationMenu(modelData.app, appDelegate)
                                } else if (!appDelegate.heldForEdit) {
                                    root.dismissApplicationMenu()
                                    if (modelData.type === "folder")
                                        root.showFolder(modelData)
                                    else if (!root.editMode)
                                        root.launchApplication(modelData.app)
                                }
                            }
                        }
                    }

                    // GridView owns delegate geometry. The handler moves only
                    // the visual transform, then commits a durable order on
                    // release; it never fights GridView's layout bindings.
                    DragHandler {
                        id: reorderDrag
                        // Stay armed before the hold completes so the same
                        // press can transition directly into a drag. Visual
                        // movement and persistence remain gated by edit mode.
                        enabled: root.editingApplication === null
                        target: null
                        acceptedButtons: Qt.LeftButton
                        onActiveChanged: {
                            if (active) {
                                appDelegate.dragReorderStarted = root.editMode
                                if (appDelegate.dragReorderStarted) {
                                    appDelegate.lastDragX = 0
                                    appDelegate.lastDragY = 0
                                    root.rootDragSourceIndex = index
                                    root.rootDragTargetIndex = index
                                    root.clearFolderMergeCandidate()
                                }
                            } else if (appDelegate.dragReorderStarted) {
                                root.commitRootItemDrag(modelData, appDelegate)
                                appDelegate.dragReorderStarted = false
                                appDelegate.heldForEdit = false
                            }
                        }
                        onTranslationChanged: {
                            if (active && appDelegate.dragReorderStarted) {
                                appDelegate.lastDragX = translation.x
                                appDelegate.lastDragY = translation.y
                                root.rootDragTargetIndex = root.dragTargetIndex(appDelegate)
                                if (modelData.type === "app")
                                    root.updateFolderMergeCandidate(
                                        modelData.app.id, appDelegate)
                                else
                                    root.clearFolderMergeCandidate()
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !root.openFolder && root.filteredApplications.length === 0
                text: root.applications.length === 0
                    ? "正在加载应用程序…" : "未找到匹配的应用"
                color: AppLauncherService.dockForegroundColor
                opacity: 0.55
                font.pixelSize: 14
            }

            // Folder contents live in a centered modal rather than replacing
            // the root grid. This preserves spatial context and keeps its
            // membership/order mutations isolated from root ordering.
            Item {
                id: folderPage
                anchors.fill: parent
                z: 100
                visible: root.displayedFolder !== null
                enabled: root.folderDialogOpen && root.editingApplication === null

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.11)
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.closeFolder()
                    }
                }

                Rectangle {
                    id: folderDialog
                    // The dialog is a true square whose side follows 80% of
                    // launcher height. Launcher width is always >= 600px,
                    // so this remains safely inside the surface.
                    width: root.launcherHeight * 0.80
                    height: width
                    anchors.centerIn: parent
                    opacity: root.folderDialogOpen ? 1 : 0
                    scale: root.folderDialogOpen ? 1 : 0.92
                    radius: 22
                    color: Qt.rgba(0.06, 0.07, 0.10, 0.76)

                    Behavior on opacity {
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }

                    Item {
                        id: folderHeader
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            margins: 20
                        }
                        height: 28

                        Text {
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }
                            text: "‹"
                            color: AppLauncherService.dockForegroundColor
                            font {
                                pixelSize: 28
                                weight: Font.DemiBold
                            }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closeFolder()
                            }
                        }

                        Text {
                            id: folderTitle
                            anchors.centerIn: parent
                            visible: !root.folderRenameActive
                            text: root.displayedFolder ? root.displayedFolder.name : "文件夹"
                            color: AppLauncherService.dockForegroundColor
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.38)
                            font {
                                pixelSize: 16
                                weight: Font.DemiBold
                            }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                // The title is deliberately visually quiet.
                                // Double-click is the only edit affordance.
                                onDoubleClicked: root.beginFolderRename()
                            }
                        }

                        TextInput {
                            id: folderNameInput
                            anchors.centerIn: parent
                            visible: root.folderRenameActive
                            width: Math.min(180, parent.width - 100)
                            horizontalAlignment: Text.AlignHCenter
                            color: AppLauncherService.dockForegroundColor
                            selectionColor: Qt.rgba(1, 1, 1, 0.30)
                            selectedTextColor: AppLauncherService.dockForegroundColor
                            text: root.folderRenameText
                            font {
                                pixelSize: 16
                                weight: Font.DemiBold
                            }
                            onTextEdited: root.folderRenameText = text
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Return
                                        || event.key === Qt.Key_Enter) {
                                    root.commitFolderRename()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Escape) {
                                    root.folderRenameActive = false
                                    event.accepted = true
                                }
                            }
                        }

                        // Only the active rename field receives an underline;
                        // the resting folder title remains visually minimal.
                        Rectangle {
                            visible: root.folderRenameActive
                            width: folderNameInput.width
                            height: 1
                            anchors {
                                horizontalCenter: folderNameInput.horizontalCenter
                                top: folderNameInput.bottom
                                topMargin: 3
                            }
                            color: Qt.rgba(1, 1, 1, 0.68)
                        }

                        Text {
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }
                            visible: root.folderEditMode
                            text: "完成"
                            color: AppLauncherService.dockForegroundColor
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.38)
                            font {
                                pixelSize: 13
                                weight: Font.Bold
                            }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.commitFolderRename()
                                    root.folderEditMode = false
                                }
                            }
                        }
                    }

                    GridView {
                        id: folderGrid
                        anchors {
                            top: folderHeader.bottom
                            topMargin: 10
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            margins: 18
                        }
                        clip: true
                        readonly property int columnCount: Math.max(3,
                            Math.floor(width / 96))
                        cellWidth: width > 0 ? width / columnCount : 96
                        cellHeight: Math.max(100, Math.round(cellWidth * 1.08))
                        model: root.displayedFolder ? root.displayedFolder.apps : []
                        onMovementStarted: root.dismissApplicationMenu()

                        delegate: Item {
                            id: folderAppDelegate
                            required property var modelData
                            property bool dragging: folderReorderDrag.active
                            property bool heldForEdit: false
                            property bool dragReorderStarted: false
                            property real lastDragX: 0
                            property real lastDragY: 0
                            width: folderGrid.cellWidth
                            height: folderGrid.cellHeight
                            z: dragging ? 10 : 0
                            scale: dragging ? 1.10 : 1.0
                            transform: Translate {
                                x: folderAppDelegate.dragging
                                    ? folderReorderDrag.translation.x : 0
                                y: folderAppDelegate.dragging
                                    ? folderReorderDrag.translation.y : 0
                            }
                            Behavior on scale {
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }

                            Rectangle {
                                id: folderAppCard
                                anchors.centerIn: parent
                                width: 82
                                height: 92
                                // Keep the remove button above the delegate's
                                // full-card MouseArea, otherwise that area
                                // consumes its click before the button sees it.
                                z: 1
                                radius: 13
                                color: folderAppMouse.containsMouse
                                    ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                rotation: 0
                                SequentialAnimation {
                                    id: folderEditWiggle
                                    running: root.folderEditMode
                                        && !folderAppDelegate.dragging
                                    loops: Animation.Infinite
                                    NumberAnimation {
                                        target: folderAppCard
                                        property: "rotation"
                                        from: -2.2; to: 2.2; duration: 110
                                        easing.type: Easing.InOutSine
                                    }
                                    NumberAnimation {
                                        target: folderAppCard
                                        property: "rotation"
                                        from: 2.2; to: -2.2; duration: 110
                                        easing.type: Easing.InOutSine
                                    }
                                    onRunningChanged: {
                                        if (!running)
                                            folderAppCard.rotation = 0
                                    }
                                }

                                IconImage {
                                    width: 52
                                    height: 52
                                    anchors {
                                        top: parent.top
                                        horizontalCenter: parent.horizontalCenter
                                        topMargin: 8
                                    }
                                    source: modelData.icon
                                    smooth: true
                                    asynchronous: true
                                }

                                Text {
                                    anchors {
                                        top: parent.top
                                        topMargin: 65
                                        horizontalCenter: parent.horizontalCenter
                                    }
                                    width: Math.min(72, implicitWidth)
                                    text: modelData.name
                                    color: AppLauncherService.dockForegroundColor
                                    style: Text.Outline
                                    styleColor: Qt.rgba(0, 0, 0, 0.38)
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                    font {
                                        pixelSize: 11
                                        weight: Font.Bold
                                    }
                                }

                                Rectangle {
                                    visible: root.folderEditMode
                                    width: 21
                                    height: 21
                                    radius: width / 2
                                    anchors {
                                        top: parent.top
                                        right: parent.right
                                        topMargin: -5
                                        rightMargin: -5
                                    }
                                    color: Qt.rgba(0.95, 0.27, 0.25, 0.96)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "−"
                                        color: "white"
                                        font {
                                            pixelSize: 17
                                            weight: Font.Bold
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.removeFolderApplication(modelData.id)
                                    }
                                }
                            }

                            MouseArea {
                                id: folderAppMouse
                                anchors.fill: parent
                                enabled: root.editingApplication === null
                                hoverEnabled: true
                                preventStealing: !root.folderEditMode
                                cursorShape: Qt.PointingHandCursor
                                onPressed: folderAppDelegate.heldForEdit = false
                                onPressAndHold: {
                                    folderAppDelegate.heldForEdit = true
                                    root.folderEditMode = true
                                }
                                onClicked: {
                                    if (!root.folderEditMode
                                            && !folderAppDelegate.heldForEdit)
                                        root.launchApplication(modelData)
                                }
                            }

                            DragHandler {
                                id: folderReorderDrag
                                enabled: root.folderEditMode
                                    && root.editingApplication === null
                                target: null
                                acceptedButtons: Qt.LeftButton
                                onActiveChanged: {
                                    if (active) {
                                        folderAppDelegate.dragReorderStarted = true
                                        folderAppDelegate.lastDragX = 0
                                        folderAppDelegate.lastDragY = 0
                                    } else if (folderAppDelegate.dragReorderStarted) {
                                        root.commitFolderApplicationDrag(
                                            modelData.id, folderAppDelegate)
                                        folderAppDelegate.dragReorderStarted = false
                                        folderAppDelegate.heldForEdit = false
                                    }
                                }
                                onTranslationChanged: {
                                    if (active) {
                                        folderAppDelegate.lastDragX = translation.x
                                        folderAppDelegate.lastDragY = translation.y
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Application presentation editor. It owns only launcher-local
            // metadata (name/icon/hidden state), never the desktop entry.
            Item {
                id: appEditorOverlay
                anchors.fill: parent
                // This is a real modal layer: it must sit above every
                // launcher child and the underlying models are disabled while
                // visible, so no DragHandler can receive pointer input.
                z: 1000
                visible: root.editingApplication !== null
                focus: visible

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.18)
                    MouseArea {
                        anchors.fill: parent
                        // Consume every button before lower delegate handlers
                        // can observe it. This is the modal input barrier.
                        acceptedButtons: Qt.AllButtons
                        preventStealing: true
                        onClicked: root.closeApplicationEditor()
                    }
                }

                Rectangle {
                    id: appEditorDialog
                    width: Math.min(420, parent.width - 80)
                    height: 400
                    anchors.centerIn: parent
                    focus: true
                    radius: 18
                    color: Qt.rgba(0.08, 0.09, 0.12, 0.82)

                    Column {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 12

                        Item {
                            width: parent.width
                            height: 30
                            Text {
                                anchors {
                                    left: parent.left
                                    verticalCenter: parent.verticalCenter
                                }
                                text: "编辑应用"
                                color: AppLauncherService.dockForegroundColor
                                style: Text.Outline
                                styleColor: Qt.rgba(0, 0, 0, 0.38)
                                font {
                                    pixelSize: 17
                                    weight: Font.DemiBold
                                }
                            }
                            Text {
                                anchors {
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }
                                text: "×"
                                color: AppLauncherService.dockForegroundColor
                                font.pixelSize: 22
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closeApplicationEditor()
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            height: 56
                            spacing: 12
                            IconImage {
                                width: 52
                                height: 52
                                source: Quickshell.iconPath(root.editorIcon, true)
                                    || root.editorIcon || "application-x-executable"
                                asynchronous: true
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.chooseCustomIcon()
                                }
                            }
                            Text {
                                width: parent.width - 64
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.editingApplication
                                    ? root.editingApplication.id : ""
                                color: AppLauncherService.dockForegroundColor
                                opacity: 0.52
                                elide: Text.ElideRight
                                font.pixelSize: 11
                            }
                        }

                        Row {
                            width: parent.width
                            height: 24
                            spacing: 8

                            Repeater {
                                model: [
                                    { name: "file", label: "选择图片文件" },
                                    { name: "clipboard", label: "粘贴剪贴板图片" },
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    width: implicitWidth + 18
                                    implicitWidth: actionLabel.implicitWidth
                                    height: 24
                                    radius: 7
                                    color: iconActionMouse.containsMouse
                                        ? Qt.rgba(1, 1, 1, 0.20)
                                        : Qt.rgba(1, 1, 1, 0.10)
                                    Behavior on color {
                                        ColorAnimation { duration: 120 }
                                    }
                                    Text {
                                        id: actionLabel
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: AppLauncherService.dockForegroundColor
                                        font.pixelSize: 10
                                    }
                                    MouseArea {
                                        id: iconActionMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData.name === "file")
                                                root.chooseCustomIcon()
                                            else
                                                root.pasteClipboardIcon()
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            height: 12
                            visible: root.editorIconStatus.length > 0
                            text: root.editorIconStatus
                            color: AppLauncherService.dockForegroundColor
                            opacity: 0.62
                            elide: Text.ElideRight
                            font.pixelSize: 10
                        }

                        Text {
                            text: "显示名称"
                            color: AppLauncherService.dockForegroundColor
                            opacity: 0.72
                            font.pixelSize: 11
                        }
                        Rectangle {
                            width: parent.width
                            height: 34
                            radius: 8
                            color: Qt.rgba(0, 0, 0, 0.20)
                            // TextInput does not elide on its own; keep user
                            // supplied names inside the dialog bounds.
                            clip: true
                            TextInput {
                                id: appEditorNameInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: Text.AlignVCenter
                                color: AppLauncherService.dockForegroundColor
                                selectionColor: Qt.rgba(1, 1, 1, 0.30)
                                selectedTextColor: AppLauncherService.dockForegroundColor
                                text: root.editorName
                                onTextEdited: root.editorName = text
                                Keys.onReturnPressed: root.saveApplicationEditor()
                            }
                        }

                        Text {
                            text: "图标名称或本地路径"
                            color: AppLauncherService.dockForegroundColor
                            opacity: 0.72
                            font.pixelSize: 11
                        }
                        Rectangle {
                            width: parent.width
                            height: 34
                            radius: 8
                            color: Qt.rgba(0, 0, 0, 0.20)
                            // A managed icon path can be long. Clip it here
                            // while preserving TextInput's native horizontal
                            // scrolling when the user edits the value.
                            clip: true
                            TextInput {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: Text.AlignVCenter
                                color: AppLauncherService.dockForegroundColor
                                selectionColor: Qt.rgba(1, 1, 1, 0.30)
                                selectedTextColor: AppLauncherService.dockForegroundColor
                                text: root.editorIcon
                                onTextEdited: root.editorIcon = text
                            }
                        }

                        Item { width: 1; height: 2 }

                        Row {
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: [
                                    { name: "reset", label: "恢复默认" },
                                    { name: "hide", label: "隐藏应用" },
                                    { name: "save", label: "保存" },
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    width: (appEditorDialog.width - 40 - 16) / 3
                                    height: 32
                                    radius: 8
                                    color: editorButtonMouse.containsMouse
                                        ? (modelData.name === "save"
                                            ? Qt.rgba(1, 1, 1, 0.34)
                                            : Qt.rgba(1, 1, 1, 0.20))
                                        : (modelData.name === "save"
                                            ? Qt.rgba(1, 1, 1, 0.22)
                                            : Qt.rgba(1, 1, 1, 0.10))
                                    Behavior on color {
                                        ColorAnimation { duration: 120 }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: AppLauncherService.dockForegroundColor
                                        font {
                                            pixelSize: 12
                                            weight: Font.Medium
                                        }
                                    }
                                    MouseArea {
                                        id: editorButtonMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData.name === "save") {
                                                root.saveApplicationEditor()
                                            } else if (modelData.name === "hide") {
                                                root.hideEditedApplication()
                                            } else if (root.editingApplication) {
                                                AppLauncherConfigService.updateAppOverride(
                                                    root.editingApplication.id,
                                                    root.editingApplication.defaultName,
                                                    root.editingApplication.defaultIcon,
                                                    root.editingApplication.defaultName,
                                                    root.editingApplication.defaultIcon)
                                                root.closeApplicationEditor()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // A passive handler on the launcher background observes left
            // clicks without stealing them from icon cards, text inputs, or
            // GridView. Any click away from a context menu dismisses it.
            TapHandler {
                enabled: root.editingApplication === null
                target: null
                acceptedButtons: Qt.LeftButton
                onPressedChanged: {
                    if (pressed)
                        root.dismissApplicationMenu()
                }
            }
        }

    }

    // BackgroundEffect is a Wayland window attachment, so it belongs to this
    // PanelWindow root. Use the direct child `launcherCard` as its geometry
    // source, matching Dock's pattern; a nested surface item can map to a
    // narrower blur region on some compositors.
    BackgroundEffect.blurRegion: RoundedBlurRegion {
        item: launcherCard
        radius: background.radius
    }
}
