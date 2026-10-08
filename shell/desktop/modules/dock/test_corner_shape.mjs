// Test harness for DockCornerShape.mjs — run with: node test_corner_shape.mjs
import { cornerPolicy, isValidShape, normalizeCurvature, DEFAULT_CURVATURE,
    MAX_CURVATURE, MIN_CURVATURE } from "./DockCornerShape.mjs";

let errors = 0;
function check(condition, message) {
    if (condition) {
        console.log('OK:  ', message);
    } else {
        console.log('FAIL:', message);
        errors++;
    }
}

// What AppearanceTokens would hand in for the macOS/glass style.
const style = {
    radiusRatio: 0.50,
    innerRadiusRatio: 0.30,
    exponent: 2.35,
    g2Exponent: 3.0,
    stretched: false,
};
const taskbarStyle = { ...style, radiusRatio: 0.20, innerRadiusRatio: 0.18,
    stretched: true };

// ── 默认 keeps today's Dock ──
const legacy = cornerPolicy("default", 0.30, style);
check(legacy.g2 === false, "默认 is not the G2 profile");
check(legacy.radiusRatio === 0.50, "默认 keeps the capsule cap");
check(legacy.exponent === 2.35, "默认 keeps the Dock's softened corner");
check(legacy.innerRadiusRatio === 0.30, "默认 keeps the style's plate ratio");

// ── G2 is the rounded rectangle ──
const g2 = cornerPolicy("g2", 0.30, style);
check(g2.g2 === true, "G2 selects the continuous-corner profile");
check(g2.radiusRatio === 0.30, "G2 takes the cap from the curvature");
check(g2.exponent === 3.0, "G2 sweeps the continuous-curvature exponent");
check(g2.innerRadiusRatio === g2.radiusRatio,
    "the inner plates share the silhouette's ratio");

// The curvature is the shape dial: smaller is squarer, 0.5 is a capsule again.
const square = cornerPolicy("g2", 0.12, style);
const capsule = cornerPolicy("g2", 0.50, style);
check(square.radiusRatio === 0.12 && capsule.radiusRatio === 0.50,
    "curvature spans squarer corners to a full capsule");
check(square.radiusRatio < g2.radiusRatio && g2.radiusRatio < capsule.radiusRatio,
    "curvature orders the corner size");

// ── A taskbar is the documented exception ──
const taskbarG2 = cornerPolicy("g2", 0.30, taskbarStyle);
check(taskbarG2.radiusRatio === 0.20,
    "a stretched taskbar keeps its own flat profile");
check(taskbarG2.innerRadiusRatio === 0.18,
    "a stretched taskbar keeps its own plate ratio");

// ── Validation ──
check(isValidShape("default") && isValidShape("g2"), "both shapes validate");
check(!isValidShape("squircle") && !isValidShape(undefined),
    "unknown shapes are rejected");
check(normalizeCurvature(9) === MAX_CURVATURE
    && normalizeCurvature(-1) === MIN_CURVATURE, "curvature clamps to its range");
check(normalizeCurvature("0.4") === 0.4, "a numeric string is accepted");
check(normalizeCurvature("wide") === DEFAULT_CURVATURE
    && normalizeCurvature(undefined) === DEFAULT_CURVATURE
    && normalizeCurvature(NaN) === DEFAULT_CURVATURE,
    "unusable curvature falls back to the default");
check(cornerPolicy("g2", 9, style).radiusRatio === MAX_CURVATURE,
    "the policy normalises the curvature it is handed");
check(cornerPolicy("g2", undefined, style).radiusRatio === DEFAULT_CURVATURE,
    "a missing curvature still yields a usable shape");
const unknown = cornerPolicy("squircle", 0.30, style);
check(unknown.g2 === false && unknown.radiusRatio === style.radiusRatio
    && unknown.exponent === style.exponent,
    "an unknown shape falls back to 默认 semantics, not to G2");

console.log(errors ? '\n' + errors + ' FAILED' : '\nAll checks passed');
process.exit(errors ? 1 : 0);
