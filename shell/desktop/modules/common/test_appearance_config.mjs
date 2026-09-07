import assert from "node:assert/strict";

function normalize(value, fallback = NaN) {
    const number = Number(value);
    return Number.isFinite(number) ? Math.max(0, Math.min(1, number)) : fallback;
}

function compositorBlurLevel(strength) {
    const value = normalize(strength);
    return Number.isFinite(value)
        ? Math.round(1 + Math.pow(value, 1.5) * 14) : 1;
}

function computeEffective(state) {
    const globalBlur = normalize(state.globalBlurStrength ?? state.blurStrength, 0.42);
    const globalLiquid = normalize(state.globalLiquidStrength ?? state.liquidStrength, 1.0);

    const dockInherit = state.dockBlurInherit !== undefined ? Boolean(state.dockBlurInherit) : true;
    const barInherit = state.barBlurInherit !== undefined ? Boolean(state.barBlurInherit) : true;
    const controlCenterInherit = state.controlCenterBlurInherit !== undefined ? Boolean(state.controlCenterBlurInherit) : true;
    const launcherInherit = state.launcherBlurInherit !== undefined ? Boolean(state.launcherBlurInherit) : true;

    return {
        dockBlur: dockInherit ? globalBlur : normalize(state.dockBlurStrength, globalBlur),
        dockLiquid: dockInherit ? globalLiquid : normalize(state.dockLiquidStrength, globalLiquid),
        barBlur: barInherit ? globalBlur : normalize(state.barBlurStrength, globalBlur),
        barLiquid: barInherit ? globalLiquid : normalize(state.barLiquidStrength, globalLiquid),
        controlCenterBlur: controlCenterInherit ? globalBlur : normalize(state.controlCenterBlurStrength, globalBlur),
        controlCenterLiquid: controlCenterInherit ? globalLiquid : normalize(state.controlCenterLiquidStrength, globalLiquid),
        launcherBlur: launcherInherit ? globalBlur : normalize(state.launcherBlurStrength, globalBlur),
        launcherLiquid: launcherInherit ? globalLiquid : normalize(state.launcherLiquidStrength, globalLiquid),
    };
}

function migrate(previous = {}) {
    const globalBlur = normalize(previous.globalBlurStrength ?? previous.blurStrength
        ?? previous.dockBlurStrength, 0.42);
    const globalLiquid = normalize(previous.globalLiquidStrength ?? previous.liquidStrength
        ?? previous.dockLiquidStrength, 1.0);

    return {
        version: 10,
        globalBlurStrength: globalBlur,
        globalLiquidStrength: globalLiquid,
        dockBlurInherit: previous.dockBlurInherit !== undefined ? Boolean(previous.dockBlurInherit) : true,
        dockBlurStrength: normalize(previous.dockBlurStrength, globalBlur),
        dockLiquidStrength: normalize(previous.dockLiquidStrength, globalLiquid),
        barBlurInherit: previous.barBlurInherit !== undefined ? Boolean(previous.barBlurInherit) : true,
        barBlurStrength: normalize(previous.barBlurStrength, globalBlur),
        barLiquidStrength: normalize(previous.barLiquidStrength, globalLiquid),
        controlCenterBlurInherit: previous.controlCenterBlurInherit !== undefined ? Boolean(previous.controlCenterBlurInherit) : true,
        controlCenterBlurStrength: normalize(previous.controlCenterBlurStrength, globalBlur),
        controlCenterLiquidStrength: normalize(previous.controlCenterLiquidStrength, globalLiquid),
        launcherBlurInherit: previous.launcherBlurInherit !== undefined ? Boolean(previous.launcherBlurInherit) : true,
        launcherBlurStrength: normalize(previous.launcherBlurStrength, globalBlur),
        launcherLiquidStrength: normalize(previous.launcherLiquidStrength, globalLiquid),
        shellStyle: previous.shellStyle ?? "macos",
        barIntegratedWithDock: previous.barIntegratedWithDock ?? false,
        barVisibilityMode: previous.barVisibilityMode ?? "always",
        barLayoutMode: previous.barLayoutMode ?? "transparent",
        dockWindowAnimationStyle: previous.dockWindowAnimationStyle ?? "scale",
    };
}

{
    assert.equal(compositorBlurLevel(0), 1);
    assert.equal(compositorBlurLevel(0.42), 5);
    assert.equal(compositorBlurLevel(0.454), 5);
    assert.equal(compositorBlurLevel(1), 15);
    console.log("ok: compositor blur uses a clear perceptual response");
}

{
    assert.deepEqual(computeEffective({}), {
        dockBlur: 0.42, dockLiquid: 1,
        barBlur: 0.42, barLiquid: 1,
        controlCenterBlur: 0.42, controlCenterLiquid: 1,
        launcherBlur: 0.42, launcherLiquid: 1,
    });
    console.log("ok: global defaults apply to every surface when inherit is true");
}

{
    assert.deepEqual(computeEffective({ globalBlurStrength: 0.18, globalLiquidStrength: 0.73 }), {
        dockBlur: 0.18, dockLiquid: 0.73,
        barBlur: 0.18, barLiquid: 0.73,
        controlCenterBlur: 0.18, controlCenterLiquid: 0.73,
        launcherBlur: 0.18, launcherLiquid: 0.73,
    });
    console.log("ok: global update propagates to inherited surfaces");
}

{
    const effective = computeEffective({
        globalBlurStrength: 0.26, globalLiquidStrength: 0.61,
        dockBlurInherit: false, dockBlurStrength: 0.95, dockLiquidStrength: 0.80,
        barBlurInherit: true,
        controlCenterBlurInherit: false, controlCenterBlurStrength: 0.50, controlCenterLiquidStrength: 0.30,
        launcherBlurInherit: false, launcherLiquidStrength: 0.11,
    });
    assert.equal(effective.dockBlur, 0.95);
    assert.equal(effective.dockLiquid, 0.80);
    assert.equal(effective.barBlur, 0.26);
    assert.equal(effective.barLiquid, 0.61);
    assert.equal(effective.controlCenterBlur, 0.50);
    assert.equal(effective.controlCenterLiquid, 0.30);
    assert.equal(effective.launcherBlur, 0.26); // inherit is false, but blurStrength is unset so falls back to global
    assert.equal(effective.launcherLiquid, 0.11);
    console.log("ok: independent component overrides take effect when inherit is false");
}

{
    const v10 = migrate({ dockBlurStrength: 0.31, dockLiquidStrength: 0.82 });
    assert.equal(v10.version, 10);
    assert.equal(v10.globalBlurStrength, 0.31);
    assert.equal(v10.globalLiquidStrength, 0.82);
    assert.equal(v10.dockBlurInherit, true);
    assert.equal(v10.dockBlurStrength, 0.31);
    assert.equal(v10.barBlurInherit, true);
    assert.equal(v10.controlCenterBlurInherit, true);
    assert.equal(v10.launcherBlurInherit, true);
    console.log("ok: legacy configuration smoothly migrates to schema v10");
}

console.log("ALL TESTS PASS");
