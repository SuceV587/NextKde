// Test harness for AdaptiveMath.mjs — run with: node test_adaptive.mjs
import { computeLayout } from "./AdaptiveMath.mjs";

const cases = [
    [60, 5, 3, false, 1920, 'few icons, no music'],
    [60, 5, 3, true,  1920, 'few icons, with music'],
    [60, 15, 18, false, 1920, 'medium icons, no music'],
    [60, 15, 18, true,  1920, 'medium icons, with music'],
    [60, 30, 30, false, 1920, 'many icons, no music'],
    [60, 30, 30, true,  1920, 'many icons, with music'],
    [60, 0, 0, false,   1920, 'empty dock'],
    [60, 0, 0, true,    1920, 'music only'],
];

let errors = 0;
for (const [bh, pc, wc, hp, sw, desc] of cases) {
    const r = computeLayout(bh, pc, wc, hp, sw);
    const issues = [];
    if (r.iconUnits > 0) {
        if (r.dockHeight > 60) issues.push('dockHeight exceeds max: ' + r.dockHeight);
        if (r.iconSize < 24 && r.iconSize !== 0) issues.push('iconSize below min');
        if (r.dockWidth > sw * 0.9 + 2) issues.push('dockWidth > 90%');
        if (r.musicUnits !== (hp ? 4 : 0)) issues.push('wrong musicUnits');
        if (r.activeBackgroundGap <= 0) issues.push('missing active background gap');
    } else {
        if (r.dockHeight !== 0 || r.iconSize !== 0) issues.push('empty dock non-zero');
    }
    if (issues.length) {
        console.log('FAIL:', desc, issues.join(', ')); errors++;
    } else {
        console.log('OK:  ', desc.padEnd(25), 'H=' + r.dockHeight, 'icon=' + r.iconSize, 'W=' + r.dockWidth);
    }
}

// Configuration must actually affect the calculation. This guards against
// accidentally reintroducing hard-coded width ratios or spacing constants.
const configured = computeLayout(60, 5, 3, false, 1920, 0.5, {
    vpad: 0.2, hpad: 0.3, spacing: 0.1, divmargin: 0.25,
});
if (configured.dockWidth > 1920 * 0.5 + 2)
    errors++, console.log('FAIL: configured maxWidthRatio ignored');
if (configured.vPadding !== Math.round(configured.iconSize * 0.2))
    errors++, console.log('FAIL: configured vpad ignored');
if (configured.hPadding !== Math.round(configured.iconSize * 0.3))
    errors++, console.log('FAIL: configured hpad ignored');

const normal = computeLayout(60, 1, 1, false, 1920);
if (Math.abs(normal.activeBackgroundGap - normal.iconSize * 0.1) > 0.001)
    errors++, console.log('FAIL: active background gap is not proportional');
console.log(errors ? '\n' + errors + ' FAILED' : '\nAll ' + cases.length + ' passed');
process.exit(errors ? 1 : 0);
