// DockCornerShape.mjs — one corner policy for every rounded shape the Dock
// draws: the glass silhouette itself and the selection plates sitting inside
// it. Pure ES module, no QML dependencies, so the rules are unit-testable.
//
// Two user choices feed the policy:
//
//   shape      "default" keeps what the active shell style has always drawn --
//              a proportional cap (0.5 of the height, i.e. a capsule) with the
//              Dock's softened 2.35 corner.
//              "g2" is the rounded rectangle: the cap ratio comes from the
//              curvature below and the corner sweeps the continuous-curvature
//              profile (AppearanceTokens.shape.cornerExponent, 3.0), which is
//              what makes the corner read as G2 rather than as a circular arc.
//   curvature  the G2 corner radius as a fraction of the Dock height. It is the
//              "curvature" control: smaller values keep more straight edge and
//              turn the corner harder, 0.5 closes the cap back into a capsule.
//              0.30 is macOS-dock-like; the range keeps the shape a rectangle.
//
// The inner plates reuse the *same ratio*, so the selection/hover corner and
// the silhouette corner are one family instead of two independently tuned
// numbers. Their continuity stays circular on purpose: they are plain Rectangles
// whose design note forbids a masked layer (shared/qml/controls/
// SelectionHighlight.qml), and at ~13px the cap difference is sub-pixel.
//
// A taskbar is the exception in both directions: it fills the screen edge, so
// its own corners are square (DockWindow already zeroes the radius) and its
// plates keep the style's ratio -- a rounder plate under a square bar would
// read as the odd one out.

export const MIN_CURVATURE = 0.12
export const MAX_CURVATURE = 0.50
// macOS-dock-like: enough straight edge that the silhouette reads as a rounded
// rectangle, and the same number the macOS style already used for its plates,
// so switching to G2 does not move the inner plates at all.
export const DEFAULT_CURVATURE = 0.30

export const SHAPE_DEFAULT = "default"
export const SHAPE_G2 = "g2"

export function isValidShape(value) {
    return value === SHAPE_DEFAULT || value === SHAPE_G2
}

// Anything unusable falls back to the default rather than throwing: this runs
// inside QML bindings and inside the config loader, where a thrown error would
// blank a surface or refuse a user's saved file.
export function normalizeCurvature(value) {
    const number = Number(value)
    if (!Number.isFinite(number))
        return DEFAULT_CURVATURE
    return Math.min(MAX_CURVATURE, Math.max(MIN_CURVATURE, number))
}

// `style` carries what the active shell style would use on its own:
//   radiusRatio       the silhouette cap / height  (0.5 = capsule, 0.2 = taskbar)
//   innerRadiusRatio  the selection plate / icon   (AppearanceTokens.dock)
//   exponent          the silhouette's continuity when the policy is off
//   g2Exponent        the continuous-curvature exponent (shape token)
//   stretched         true when the Dock fills the screen edge (taskbar)
export function cornerPolicy(shape, curvature, style = {}) {
    const g2 = shape === SHAPE_G2
    const stretched = style.stretched === true
    const roundedRectangle = g2 && !stretched
    const curvatureValue = normalizeCurvature(curvature)
    return {
        g2,
        // The glass silhouette: a taskbar keeps its own square/flat profile.
        radiusRatio: roundedRectangle ? curvatureValue : style.radiusRatio,
        exponent: g2 ? style.g2Exponent : style.exponent,
        // The plates inside it follow the silhouette's rounding.
        innerRadiusRatio: roundedRectangle
            ? curvatureValue : style.innerRadiusRatio,
    }
}
