import QtQuick
import Quickshell.Widgets

// Shared renderer for small shell/status/menu icons. Layout chooses its size;
// this component guarantees that icon selection goes through the semantic
// system-theme resolver.
Item {
    id: root

    property string role: ""
    property string state: ""
    property var candidateNames: []
    property string fallbackName: "image-missing"
    property bool asynchronous: true
    property bool smooth: true
    // Optional appearance projection. Defaults preserve every existing
    // non-Dock consumer; Dock-hosted status controls opt in explicitly.
    property real opacityMultiplier: 1.0
    property real saturation: 1.0
    property real tintEnabled: 0.0
    property color tintColor: "#a855f7"
    readonly property string iconSource: candidateNames && candidateNames.length > 0
        ? SystemIconResolver.sourceFromCandidates(candidateNames, fallbackName)
        : SystemIconResolver.sourceFromCandidates(
            SystemIconResolver.candidates(role, state), fallbackName)

    implicitWidth: 16
    implicitHeight: 16

    AppIcon {
        anchors.fill: parent
        source: root.iconSource
        opacityMultiplier: root.opacityMultiplier
        saturation: root.saturation
        tintEnabled: root.tintEnabled
        tintColor: root.tintColor
        asynchronous: root.asynchronous
        smooth: root.smooth
    }
}
