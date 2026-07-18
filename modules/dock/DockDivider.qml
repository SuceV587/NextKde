import QtQuick

// ────────────────────────────────────────────────────────────────
// DockDivider — Hairline separator between dock sections.
// Height is a fraction of the dock height (centred vertically).
// Can be toggled visible (e.g. second divider hides with music).
// ────────────────────────────────────────────────────────────────

Rectangle {
    id: divider

    // ── Inputs ──
    property int dockHeight:   60
    property int dividerWidth: 1
    property int sideMargin:   8

    // ── Layout ──
    width: dividerWidth + sideMargin * 2   // total slot width including margins
    height: dockHeight
    color: "transparent"
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    // The visible line (centered in the slot)
    Rectangle {
        width:  divider.dividerWidth
        height: divider.dockHeight * 0.45          // 45% of dock height
        radius: divider.dividerWidth / 2
        anchors.centerIn: parent
        color: ThemeService.dividerColor
        opacity: 0.55
    }

    // ── Visibility animation ──
    Behavior on width {
        enabled: divider.visible
        NumberAnimation {
            duration: DockAnimation.musicExpandDuration
            easing.type: DockAnimation.musicExpandEasing
        }
    }
}
