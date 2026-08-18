#!/usr/bin/env python3
"""Re-generate src/generated/onscreen_rounded.frag from source shaders.

Mirrors CMake's generate_shader_variants() exactly so editing glass.glsl
takes effect without a full CMake re-configure:

  GLASS_SHADER = glass.glsl with #include "snells-glass.glsl" expanded
  SHADER_SRC   = onscreen_rounded.glsl
  output       = COMPAT_CORE + SHADER_SRC with oklab.glsl + glass.glsl expanded
                 (#include "sdf.glsl" is kept for the runtime KWin include)
"""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent / "src" / "shaders"
GEN = pathlib.Path(__file__).resolve().parent.parent / "src" / "generated"

def read(name):
    return (ROOT / name).read_text()

compat_core = read("compat_core.glsl")
oklab = read("oklab.glsl")
snells = read("snells-glass.glsl")

glass = read("glass.glsl")
glass = glass.replace('#include "snells-glass.glsl"', snells)

src = read("onscreen_rounded.glsl")
expanded = src.replace('#include "oklab.glsl"', oklab)
expanded = expanded.replace('#include "glass.glsl"', glass)

out = GEN / "onscreen_rounded.frag"
out.write_text(compat_core + "\n" + expanded)
print(f"wrote {out} ({len(compat_core + expanded)} bytes)")

# Sanity checks
checks = {
    "circleMap lens profile": "circleMap" in expanded,
    "analytic gradient gradSdRoundedBox": "gradSdRoundedBox" in expanded,
    "corner-weighted dispersion": "cornerWeight" in expanded,
    "snells include expanded (no bare include)": '#include "snells' not in expanded,
    "glass.glsl expanded (no bare include)": '#include "glass' not in expanded,
    "sdf.glsl include kept": '#include "sdf.glsl"' in expanded,
}
for name, ok in checks.items():
    print(f"  [{'OK' if ok else 'FAIL'}] {name}")
if not all(checks.values()):
    raise SystemExit(1)
print("all checks passed")
