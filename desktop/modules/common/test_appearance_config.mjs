import assert from "node:assert/strict";

// Test schema migration and inheritance logic
function normalize(value) {
    const number = Number(value);
    return Number.isFinite(number) ? Math.max(0.0, Math.min(1.0, number)) : NaN;
}

function computeEffective(state) {
    const globalBlur = Number.isFinite(normalize(state.globalBlurStrength ?? state.blurStrength ?? state.dockBlurStrength))
        ? normalize(state.globalBlurStrength ?? state.blurStrength ?? state.dockBlurStrength)
        : 0.42;
    const globalLiquid = Number.isFinite(normalize(state.globalLiquidStrength ?? state.liquidStrength ?? state.dockLiquidStrength))
        ? normalize(state.globalLiquidStrength ?? state.liquidStrength ?? state.dockLiquidStrength)
        : 1.0;

    const dockInherit = state.dockBlurInherit !== false;
    const dockBlur = dockInherit ? globalBlur : (Number.isFinite(normalize(state.dockBlurStrength)) ? normalize(state.dockBlurStrength) : 0.42);
    const dockLiquid = dockInherit ? globalLiquid : (Number.isFinite(normalize(state.dockLiquidStrength)) ? normalize(state.dockLiquidStrength) : 1.0);
    
    const barInherit = state.barBlurInherit !== false && state.barBlurInheritDock !== false;
    const barBlur = barInherit ? globalBlur : (Number.isFinite(normalize(state.barBlurStrength)) ? normalize(state.barBlurStrength) : 0.42);
    const barLiquid = barInherit ? globalLiquid : (Number.isFinite(normalize(state.barLiquidStrength)) ? normalize(state.barLiquidStrength) : 1.0);

    const launcherInherit = state.launcherBlurInherit !== false && state.launcherBlurInheritDock !== false;
    const launcherBlur = launcherInherit ? globalBlur : (Number.isFinite(normalize(state.launcherBlurStrength)) ? normalize(state.launcherBlurStrength) : 0.42);
    const launcherLiquid = launcherInherit ? globalLiquid : (Number.isFinite(normalize(state.launcherLiquidStrength)) ? normalize(state.launcherLiquidStrength) : 1.0);

    return {
        globalBlur, globalLiquid,
        dockInherit, dockBlur, dockLiquid,
        barInherit, barBlur, barLiquid,
        launcherInherit, launcherBlur, launcherLiquid
    };
}

function migrateFromV5(v5) {
    return {
        version: 6,
        globalBlurStrength: v5.globalBlurStrength ?? v5.dockBlurStrength ?? v5.blurStrength ?? 0.42,
        globalLiquidStrength: v5.globalLiquidStrength ?? v5.dockLiquidStrength ?? v5.liquidStrength ?? 1.0,
        dockBlurInherit: v5.dockBlurInherit ?? true,
        dockBlurStrength: v5.dockBlurStrength ?? 0.42,
        dockLiquidStrength: v5.dockLiquidStrength ?? 1.0,
        barBlurInherit: v5.barBlurInherit ?? v5.barBlurInheritDock ?? true,
        barBlurStrength: v5.barBlurStrength ?? 0.42,
        barLiquidStrength: v5.barLiquidStrength ?? 1.0,
        launcherBlurInherit: v5.launcherBlurInherit ?? v5.launcherBlurInheritDock ?? true,
        launcherBlurStrength: v5.launcherBlurStrength ?? 0.42,
        launcherLiquidStrength: v5.launcherLiquidStrength ?? 1.0,
        shellStyle: v5.shellStyle ?? "macos",
        barIntegratedWithDock: v5.barIntegratedWithDock ?? false,
        barVisibilityMode: v5.barVisibilityMode ?? "always",
        barLayoutMode: v5.barLayoutMode ?? "full"
    };
}

// 1. Default inheritance (Global -> Dock, Bar, Launcher)
{
    const state = computeEffective({});
    assert.equal(state.globalBlur, 0.42);
    assert.equal(state.globalLiquid, 1.0);
    assert.equal(state.dockInherit, true);
    assert.equal(state.dockBlur, 0.42);
    assert.equal(state.dockLiquid, 1.0);
    assert.equal(state.barInherit, true);
    assert.equal(state.barBlur, 0.42);
    assert.equal(state.barLiquid, 1.0);
    assert.equal(state.launcherInherit, true);
    assert.equal(state.launcherBlur, 0.42);
    assert.equal(state.launcherLiquid, 1.0);
    console.log("ok: default inheritance test passed");
}

// 2. Modifying Global baseline propagates to Dock, Bar, and Launcher
{
    const state = computeEffective({ globalBlurStrength: 0.8, globalLiquidStrength: 0.5 });
    assert.equal(state.globalBlur, 0.8);
    assert.equal(state.dockBlur, 0.8);
    assert.equal(state.barBlur, 0.8);
    assert.equal(state.launcherBlur, 0.8);
    assert.equal(state.globalLiquid, 0.5);
    assert.equal(state.dockLiquid, 0.5);
    assert.equal(state.barLiquid, 0.5);
    assert.equal(state.launcherLiquid, 0.5);
    console.log("ok: global propagation test passed");
}

// 3. Symmetrical custom overrides on Dock, Bar & Launcher
{
    const state = computeEffective({
        globalBlurStrength: 0.8,
        globalLiquidStrength: 0.5,
        dockBlurInherit: false,
        dockBlurStrength: 0.1,
        dockLiquidStrength: 0.9,
        barBlurInherit: false,
        barBlurStrength: 0.2,
        barLiquidStrength: 0.3,
        launcherBlurInherit: false,
        launcherBlurStrength: 0.95,
        launcherLiquidStrength: 0.1
    });
    assert.equal(state.globalBlur, 0.8);
    assert.equal(state.dockBlur, 0.1);
    assert.equal(state.dockLiquid, 0.9);
    assert.equal(state.barBlur, 0.2);
    assert.equal(state.barLiquid, 0.3);
    assert.equal(state.launcherBlur, 0.95);
    assert.equal(state.launcherLiquid, 0.1);
    console.log("ok: independent values test passed");
}

// 4. Migration from v5
{
    const v5 = {
        version: 5,
        dockBlurStrength: 0.6,
        dockLiquidStrength: 0.7,
        barBlurInheritDock: false,
        barBlurStrength: 0.3,
        barLiquidStrength: 0.4,
        launcherBlurInheritDock: true,
        launcherBlurStrength: 0.42,
        launcherLiquidStrength: 1.0,
        shellStyle: "material",
        barIntegratedWithDock: true,
        barVisibilityMode: "smart"
    };
    const v6 = migrateFromV5(v5);
    assert.equal(v6.version, 6);
    assert.equal(v6.globalBlurStrength, 0.6);
    assert.equal(v6.globalLiquidStrength, 0.7);
    assert.equal(v6.dockBlurInherit, true);
    assert.equal(v6.barBlurInherit, false);
    assert.equal(v6.barBlurStrength, 0.3);
    assert.equal(v6.launcherBlurInherit, true);
    assert.equal(v6.shellStyle, "material");
    assert.equal(v6.barIntegratedWithDock, true);
    assert.equal(v6.barVisibilityMode, "smart");
    assert.equal(v6.barLayoutMode, "full");
    console.log("ok: v5 to v6 migration test passed");
}

console.log("ALL TESTS PASS");
