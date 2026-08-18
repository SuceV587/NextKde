// AdaptiveMath.mjs — Proportional scaling layout for the dock.
// Pure ES module, no QML dependencies.
//
// Core principle: iconSize is the single independent variable.
// All spacing (item gaps, divider margins, horizontal/vertical padding)
// derives from iconSize via proportion constants, so small icons get
// proportionally small gaps — visual harmony at every scale.

// ── Proportion constants ──
const DEFAULT_PROPORTIONS = {
    vpad:       0.20,   // vertical padding / iconSize   (44→9,  24→5)
    hpad:       0.4,    // horizontal padding / iconSize (44→18, 24→10)
    spacing:    0.09,   // inter-icon gap / iconSize     (44→4,  24→2)
    divmargin:  0.20,   // divider side margin / iconSize(44→9,  24→5)
    radius:     0.45,   // pill radius / dockHeight
    dividerWidth: 1,    // the ONLY fixed pixel value — a 1px hairline
}
const MUSIC_UNITS = 4       // music player width ≡ 4 icon squares
const MIN_ICON_SIZE = 24
// This matches the Settings slider range. PanelWindow does not impose a
// height cap; keeping the cap here makes the layout calculation authoritative.
const MAX_DOCK_HEIGHT = 100
const MAX_WIDTH_RATIO = 0.98
const ACTIVE_BG_GAP_RATIO = 0.1 // icon/background gap as a fraction of iconSize

// ── Clamp utility ──
function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value))
}

// ── Core layout calculator ──
//
// Parameters:
//   baseHeight  — user-configured ideal dock height (e.g. 60)
//   pinnedCount — number of pinned launcher icons
//   windowCount — number of open (non-pinned) window icons
//   hasPlayer   — whether the right-side information slot is occupied
//   screenWidth — current screen width in pixels
//
// Returns: {
//   dockHeight, iconSize, dockWidth,
//   itemSpacing, hPadding, vPadding, dividerMargin,
//   iconUnits, musicUnits, dividerCount
// }
// The Dock width remains content-driven, but it must never exceed 98% of the
// current screen. Only spacing proportions remain configurable.
export function computeLayout(
    baseHeight,
    pinnedCount,
    windowCount,
    hasPlayer,
    screenWidth,
    proportions = {}
) {
    const p = {
        vpad:    Number.isFinite(Number(proportions?.vpad))    ? Number(proportions.vpad)    : DEFAULT_PROPORTIONS.vpad,
        hpad:    Number.isFinite(Number(proportions?.hpad))    ? Number(proportions.hpad)    : DEFAULT_PROPORTIONS.hpad,
        spacing: Number.isFinite(Number(proportions?.spacing)) ? Number(proportions.spacing) : DEFAULT_PROPORTIONS.spacing,
        divmargin: Number.isFinite(Number(proportions?.divmargin)) ? Number(proportions.divmargin) : DEFAULT_PROPORTIONS.divmargin,
    }

    const maxWidth = screenWidth * MAX_WIDTH_RATIO

    // ── Determine right-side information section ──
    const musicUnits   = hasPlayer ? MUSIC_UNITS : 0
    const dividerCount = hasPlayer ? 2 : 1

    // ── Item counts ──
    const appIconCount = pinnedCount + windowCount
    const iconUnits = appIconCount + musicUnits
    const itemCount = pinnedCount + windowCount + dividerCount + (hasPlayer ? 1 : 0)

    // Guard: nothing to show
    if (iconUnits <= 0) {
        return {
            dockHeight: 0, iconSize: 0, dockWidth: 0,
            itemSpacing: 0, hPadding: 0, vPadding: 0, dividerMargin: 0,
            pillRadius: 0, iconUnits: 0, musicUnits: 0, dividerCount: 0
        }
    }

    // ── Scale factor — multiplies iconSize to yield total width ──
    //   iconUnits        : total width from icon bodies
    //   appIconCount    : every app icon reserves an invisible outer slot for
    //                      the active background, so it will not move siblings
    //                      when focus changes. The music widget has one outer
    //                      background slot of its own.
    //   (itemCount-1)    : gaps between adjacent items in the Row
    //   2*dividerCount   : margin on each side of each divider
    //   2                : left + right edge padding
    const scaleFactor =
          iconUnits
        + (appIconCount + (hasPlayer ? 1 : 0)) * 2 * ACTIVE_BG_GAP_RATIO
        + (itemCount - 1) * p.spacing
        + 2 * dividerCount * p.divmargin
        + 2 * p.hpad

    const fixedOverhead = dividerCount * DEFAULT_PROPORTIONS.dividerWidth

    // ── Icon size bounds derived from height bounds ──
    const maxIconSize  = MAX_DOCK_HEIGHT / (1 + 2 * p.vpad)
    const baseIconSize = baseHeight     / (1 + 2 * p.vpad)

    // ── Choose icon size ──
    let iconSize
    if (baseIconSize * scaleFactor + fixedOverhead <= maxWidth) {
        // Fits comfortably — use the user's preferred size
        iconSize = Math.floor(baseIconSize)
    } else {
        // Overflow — solve for the exact iconSize that fills maxWidth
        iconSize = Math.floor((maxWidth - fixedOverhead) / scaleFactor)
    }

    iconSize = clamp(iconSize, MIN_ICON_SIZE, maxIconSize)

    // ── Derive everything from iconSize ──
    const dockHeight    = Math.round(iconSize * (1 + 2 * p.vpad))
    const itemSpacing   = Math.round(iconSize * p.spacing)
    const hPadding      = Math.round(iconSize * p.hpad)
    const vPadding      = Math.round(iconSize * p.vpad)
    const dividerMargin = Math.round(iconSize * p.divmargin)
    const pillRadius    = Math.round(dockHeight * DEFAULT_PROPORTIONS.radius)

    const contentWidth  = iconSize * scaleFactor + fixedOverhead
    const dockWidth     = Math.min(contentWidth, maxWidth)
    const activeBackgroundGap = iconSize * ACTIVE_BG_GAP_RATIO

    return {
        dockHeight,
        iconSize,
        dockWidth,
        itemSpacing,
        hPadding,
        vPadding,
        dividerMargin,
        pillRadius,
        activeBackgroundGap,
        iconUnits,
        musicUnits,
        dividerCount,
    }
}

// ── Convenience: quick-fit without full layout ──
export function quickIconSize(baseHeight, pinnedCount, windowCount, hasPlayer, screenWidth) {
    return computeLayout(baseHeight, pinnedCount, windowCount, hasPlayer, screenWidth).iconSize
}
