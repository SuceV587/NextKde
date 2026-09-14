uniform vec3 tintColor;
uniform float tintGray;
uniform float tintStrength;
uniform int autoTintAlpha;
uniform vec3 glowColor;
uniform float glowStrength;
uniform int edgeLighting;

uniform float edgeSizePixels;
uniform float highlightWidthPx;
uniform float highlightAngle;
uniform float surfaceScale;
// Optical distortion belongs to small, directly manipulated controls.  Large
// persistent surfaces keep the material treatment but use a quieter lens.
uniform float lensStrengthScale;
uniform float refractionStrength;
uniform float refractionNormalPow;
uniform float refractionRGBFringing;
uniform float refractionOffsetStrength;
uniform float refractionBevelIntensity;
uniform int physicallyBasedRefraction;

// ── Bionic light-field (HyperOS 4 soft-glass / MaterialMode$Bionics) ──
// The 37-float DEFAULT_GLASS_TOKEN recipe from MiBackgroundStyle, now with
// the field<->value alignment re-verified against three independent
// sources: the BionicsToken constructor iput sequence, the
// toBionicsParams() array order, and the sibling GlassToken.create()
// parameter layout (luminanceValues / darkerRange / inner.color /
// shape.edge / reflect.lighten / blurBg.*). Consumed by bionicGlass().
uniform int bionicMode;
uniform float bionicFlowTime;           // 流动时间（秒）
uniform float bionicFlowAmp;            // 流动幅度（0=静止）
uniform float bionicLumValue0;         // luminanceValue0   0.67
uniform float bionicLumValue1;         // luminanceValue1   0.16
uniform float bionicLumValue2;         // luminanceValue2   0.09
uniform float bionicLumValue3;         // luminanceValue3   0.0
uniform float bionicLumAmount;         // luminanceAmount   0.24
uniform float bionicBrightness;        // brightness       -0.02
uniform float bionicHsvvBoost;         // rou guang ti liang qiang du 1.0
uniform float bionicDarker;            // darker            0.3
uniform float bionicDarkerRange0;      // darkerRange[0]    0.6
uniform float bionicDarkerRange1;      // darkerRange[1]    1.0
uniform float bionicInnerBottom;       // inner.bottom      0.03
uniform float bionicInnerColorWhite;   // inner.colorWhite  0.2
uniform float bionicInnerColorMix;     // inner.colorMix    0.3
uniform float bionicColorPow;          // inner.colorPow    1.0
uniform float bionicAlpha;             // inner.color alpha 0.1
uniform float bionicOverallAlpha;      // overallAlpha      1.0
uniform float bionicShapeEdgePx;       // shape.edge        72.0
uniform float bionicShapeEdgePow;      // shape.edgePow     3.8
uniform float bionicShapeThicknessPx;  // shape.thicknessPx 80.0
uniform float bionicShapeReflectOffsetPx; // shape.reflectOffsetPx 800.0
uniform float bionicReflLighten;       // reflect.lighten   1.2
uniform float bionicReflStrength;      // reflect.strength  1.0
uniform float bionicDirX;              // directionalLight x -0.4
uniform float bionicDirY;              // directionalLight y  0.6
uniform float bionicDirZ;              // directionalLight z -0.8
uniform float bionicDirIntensity;      // directionalLight intensity 1.4
uniform float bionicDirOppositeIntensity; // oppositeIntensity 0.7
uniform float bionicDirAngleRange;     // angleRange        0.8
uniform float bionicDirEdgePow;        // edgePow           1.15
uniform float bionicIOR;               // refract.ior (visual calibration kept at 1.2)
uniform float bionicBgColorSaturation; // blurBg.saturation 2.0
uniform float bionicBgColorBrightness; // blurBg.brightness 0.0

// ── Classic (HyperOS "light frosted glass") ───────────────────────────
// Model: blur + stacked colour-blend layers + bloom stroke, from the
// miuix ColorBlendToken / BloomStrokeToken tables (see apply_classic.py).
uniform int classicMode;
uniform vec4 classicDark0;    // rgba layer 0 (dark scene)
uniform vec4 classicDark1;
uniform vec4 classicDark2;
uniform vec4 classicLight0;   // rgba layer 0 (light scene)
uniform vec4 classicLight1;
uniform vec4 classicLight2;
uniform vec4 classicStroke;   // x=size(24) y=strength(0.1) z=w unused w unused
uniform float classicRefractIOR;     // GlassToken$Refract.ior 1.5
uniform float classicReflLighten;    // GlassToken$Reflect.lighten 2.0
uniform float classicReflStrength;   // GlassToken$Reflect.strength 0.6
uniform float classicMaskSoft;       // shape mask feather px (native setMaskBlur 20)

float roundedRectangleDist(vec2 p, vec2 b, vec4 cornerRadius)
{
    float r = p.x > 0.0
        ? (p.y > 0.0 ? cornerRadius.y : cornerRadius.w)
        : (p.y > 0.0 ? cornerRadius.x : cornerRadius.z);
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

struct GlassFragment {
    vec4 color;
    float dist;
    float edgeFactor;
    float concaveFactor;
    vec3 normal;
    float ior;
};

#include "snells-glass.glsl"

vec4 roundedRectangle(vec2 fragCoord, vec3 color, vec4 cornerRadius)
{
    vec2 halfblurSize = blurSize * 0.5;
    vec2 p = fragCoord - halfblurSize;
    float dist = roundedRectangleDist(p, halfblurSize, cornerRadius);

    if (dist <= 0.0) {
        return vec4(color, 1.0);
    }

    float s = smoothstep(0.0, 1.0, dist);
    return vec4(color, mix(1.0, 0.0, s));
}

// ── Kyant0 lens profile (circleMap) ───────────────────────────────────
// Refraction in iOS glass is confined to a band near the edge and falls off
// along a circular-arc profile: 1.0 at the rim, 0.0 at the inner edge of the
// band. This is what makes the edge bend while the interior stays flat.
// Replaces the pow() approximation in concaveFactor for the refraction zone.
float circleMap(float x)
{
    return 1.0 - sqrt(1.0 - clamp(x, 0.0, 1.0) * x);
}

// Analytic gradient of the rounded-box SDF (Kyant0 gradSdRoundedRect). One
// exact normal sample replaces the finite-difference pair, and the gradient
// radius is widened so the normal field stays continuous across the corner
// transition instead of picking up the per-corner radius discontinuity.
vec2 gradSdRoundedBox(vec2 p, vec2 b, float r)
{
    vec2 q = abs(p) - b + r;
    vec2 sgn = sign(p);
    vec2 outside = max(q, 0.0);
    float lenOut = length(outside);
    if (lenOut > 1e-5) {
        return sgn * outside / lenOut;
    }
    return (q.x > q.y) ? vec2(sgn.x, 0.0) : vec2(0.0, sgn.y);
}

GlassFragment glassRefraction(vec2 position, vec2 halfBlurSize, vec4 cornerRadius, float dist, float edgeFactor, float concaveFactor)
{
    // Analytic SDF normal (Kyant0): one exact sample instead of the
    // finite-difference pair. The gradient radius is widened to keep the
    // normal field smooth through the corners.
    float minHalfSize = min(halfBlurSize.x, halfBlurSize.y);
    float minR = min(min(cornerRadius.x, cornerRadius.y), min(cornerRadius.z, cornerRadius.w));
    float gradRadius = min(minR * 1.5, minHalfSize);
    vec2 gradient = gradSdRoundedBox(position, halfBlurSize, gradRadius);

    vec2 normal = length(gradient) > 1e-5 ? -normalize(gradient) : vec2(0.0, 1.0);

    // The lens band: refraction lives only inside a band of width
    // max(edgeSizePixels, 2px) * 1.5 from the edge. interiorDist grows inward
    // from 0 at the rim; bandT goes 1.0 (rim) -> 0.0 (band inner edge) and
    // circleMap turns that into the circular-arc falloff. Beyond the band the
    // surface is perfectly flat, matching iOS "edge bends, center flat".
    float interiorDist = -dist;
    float bandWidth = max(edgeSizePixels, 2.0) * 1.5;
    float bandT = 1.0 - clamp(interiorDist / bandWidth, 0.0, 1.0);
    float lens = circleMap(bandT);

    // Displacement: the rim peak scales with refractionStrength (kwinrc /20,
    // so 10 -> 0.5) through the original 0.4 coefficient. The lens profile
    // (circleMap) and concaveFactor attenuate it toward the interior. How
    // strong the bend reads is a parameter choice (RefractionStrength), not a
    // shader constant.
    float finalStrength = min(0.4 * concaveFactor * refractionStrength, 1.0)
        * lens * lensStrengthScale;

    // Corner-weighted chromatic aberration (Kyant0): a real rectangular lens
    // fringes most at its corners and not at all on the axes, so the colour
    // split scales with |x*y| across the surface. The corner emphasis is the
    // structural change (parameter-unreachable); the overall amount stays
    // parameter-driven via refractionRGBFringing.
    vec2 centeredNorm = position / halfBlurSize;
    float cornerWeight = abs(centeredNorm.x * centeredNorm.y);
    float fringingFactor = refractionRGBFringing * 0.3
        * (0.3 + 0.7 * cornerWeight) * lensStrengthScale;

    vec2 refractOffsetG = -normal.xy * finalStrength;
    vec2 refractOffsetR = -normal.xy * finalStrength;
    vec2 refractOffsetB = -normal.xy * finalStrength;

    if (fringingFactor > 0.0) {
        // Red bends most
        refractOffsetR = -normal.xy * (finalStrength * (1.0 + fringingFactor));
        // Blue bends least
        refractOffsetB = -normal.xy * (finalStrength * (1.0 - fringingFactor));
    }

    vec2 coordR = clamp(uv - refractOffsetR, 0.0, 1.0);
    vec2 coordG = clamp(uv - refractOffsetG, 0.0, 1.0);
    vec2 coordB = clamp(uv - refractOffsetB, 0.0, 1.0);

    vec4 color = vec4(
        texture(texUnit, coordR).r,
        texture(texUnit, coordG).g,
        texture(texUnit, coordB).b,
        texture(texUnit, coordG).a
    );
    return GlassFragment(color, dist, edgeFactor, concaveFactor, vec3(0.0, 0.0, 1.0), 1.0);
}

// ── Bidirectional tint ────────────────────────────────────────────────
// Tint strength scales with how far the backdrop brightness is from the
// mid-point (0.5): a near-white or near-black background gets the full
// configured strength, a mid-grey background gets almost none, and the
// result is hard-capped at 15% so the glass never turns into painted
// plastic. The tint *colour* flips from dark (configured tintColor) on
// bright backgrounds to white on dark backgrounds, so the glass always
// retains material depth instead of turning into a flat black slab.
// These must be declared before glassOutline() because glassOutline applies
// the tint to the backdrop.
float adjustedTintStrength(float baseTintStrength, vec3 backgroundColor)
{
    float strength = clamp(baseTintStrength, 0.0, 1.0);

    // Bright backdrops may deepen up to 28% so white text stays readable on
    // white backgrounds; dark backdrops stay at 15% so the glass keeps its
    // transparent liquid-glass look.
    const vec3 grayscaleWeights = vec3(0.299, 0.587, 0.114);
    float backgroundGray = dot(backgroundColor, grayscaleWeights);

    float cap = mix(0.15, 0.28, smoothstep(0.70, 0.80, backgroundGray));

    float useLocal = step(0.5, float(autoTintAlpha)) * step(0.001, strength);
    if (useLocal < 0.5)
        return min(strength, cap);

    float deviation = abs(backgroundGray - 0.5) * 2.0;
    float scale = mix(0.05, 1.0, deviation);

    return min(strength * scale, cap);
}

vec3 bidirectionalTintColor(vec3 backgroundColor, vec3 darkTint)
{
    float useLocal = step(0.5, float(autoTintAlpha)) * step(0.001, tintStrength);
    if (useLocal < 0.5)
        return darkTint;

    const vec3 grayscaleWeights = vec3(0.299, 0.587, 0.114);
    float backgroundGray = dot(backgroundColor, grayscaleWeights);

    float t = smoothstep(0.35, 0.65, backgroundGray);
    return mix(vec3(1.0), darkTint, t);
}

// Rim highlight colour from the iOS render shader: on a dark backdrop the
// rim is white for contrast; on a bright or colourful backdrop it keeps the
// backdrop's own hue, brightened — the "vibrancy at the edge" that makes the
// rim read as glass catching light instead of a painted white stripe.
vec3 getHighlightColor(vec3 backgroundColor, float targetBrightness)
{
    const vec3 grayscaleWeights = vec3(0.299, 0.587, 0.114);
    float luminance = dot(backgroundColor, grayscaleWeights);
    float maxComponent = max(max(backgroundColor.r, backgroundColor.g), backgroundColor.b);
    float lumFactor = (luminance * 2.5) / (1.0 + luminance * 2.5);
    float satFactor = (maxComponent * 2.5) / (1.0 + maxComponent * 2.5);
    float colorInfluence = lumFactor * satFactor;
    vec3 tinted = (backgroundColor / max(luminance, 0.001)) * targetBrightness;
    return mix(vec3(targetBrightness), tinted, colorInfluence);
}

// Luminosity-preserving bidirectional tint with a content-adaptive
// saturation lift. A plain mix() toward black/white darkens the backdrop's
// luminance, which is what makes glass read as painted plastic. Keeping the
// backdrop's own luminance and only nudging its chroma (the essence of iOS
// "vibrancy") keeps the material transparent — and the chroma nudging scales
// with the backdrop: dark surfaces get a richer boost (1.18), bright ones a
// subtle dip (0.9), so the glass visibly reacts to what is behind it.
vec3 applyGlassTint(vec3 backdrop)
{
    const vec3 grayscaleWeights = vec3(0.299, 0.587, 0.114);
    float luma = dot(backdrop, grayscaleWeights);
    // Keep the background recognisable rather than globally increasing its
    // saturation. Dark backdrops receive only a small chroma recovery after
    // blur; bright backdrops are very slightly restrained for legibility.
    float adaptive = mix(1.10, 0.96, luma);
    vec3 lifted = mix(vec3(luma), backdrop, adaptive);
    float strength = adjustedTintStrength(tintStrength, lifted);
    vec3 tintCol = bidirectionalTintColor(lifted, tintColor);
    return mix(lifted, tintCol, strength);
}

// ── Edge-confined liquid reflection ───────────────────────────────────
// Keep the material body untouched. These reflections are short, white
// glints on the straight portions of the contour, not an all-around Fresnel
// outline and not a dark inner bevel. Their centre is wider than their ends,
// matching the shared QML glass component.
vec3 applyLiquidGlints(vec3 rgb, vec2 position, vec2 halfBlurSize,
    vec4 cornerRadius, float dist, float edgeAntialiasWidth)
{
    float topRadius = max(cornerRadius.x, cornerRadius.y);
    float bottomRadius = max(cornerRadius.z, cornerRadius.w);
    float leftRadius = max(cornerRadius.x, cornerRadius.z);
    float rightRadius = max(cornerRadius.y, cornerRadius.w);
    float horizontalHalfLength = max(halfBlurSize.x
        - max(topRadius, bottomRadius) - 5.0, 0.0);
    float verticalHalfLength = max(halfBlurSize.y
        - max(leftRadius, rightRadius) - 12.0, 0.0);

    float horizontalEnvelope = (1.0 - smoothstep(0.64, 1.0,
        abs(position.x) / max(horizontalHalfLength, 1.0)))
        * step(1.0, horizontalHalfLength);
    float verticalEnvelope = (1.0 - smoothstep(0.56, 1.0,
        abs(position.y) / max(verticalHalfLength, 1.0)))
        * step(1.0, verticalHalfLength);
    float widthScale = clamp(highlightWidthPx / 3.0, 0.80, 1.20);
    float topSigma = max(edgeAntialiasWidth * 0.52,
        mix(0.43, 0.76, horizontalEnvelope) * widthScale);
    float bottomSigma = max(edgeAntialiasWidth * 0.48,
        mix(0.40, 0.64, horizontalEnvelope) * widthScale);
    float sideSigma = max(edgeAntialiasWidth * 0.48,
        mix(0.42, 0.62, verticalEnvelope) * widthScale);

    float topGlint = exp(-0.5 * pow((halfBlurSize.y - position.y - 1.0)
        / topSigma, 2.0)) * horizontalEnvelope;
    float bottomGlint = exp(-0.5 * pow((position.y + halfBlurSize.y - 1.0)
        / bottomSigma, 2.0)) * horizontalEnvelope;
    float sideGlint = (exp(-0.5 * pow((position.x + halfBlurSize.x - 1.0)
        / sideSigma, 2.0)) + exp(-0.5 * pow((halfBlurSize.x - position.x - 1.0)
        / sideSigma, 2.0))) * verticalEnvelope;

    // A capsule has no straight vertical section. Give its two rounded end
    // caps a very small reflection at their horizontal centre only; it fades
    // before reaching the top/bottom joins, so this cannot close into a rim.
    float endcapSurface = 1.0 - smoothstep(0.0, 12.0,
        verticalHalfLength);
    float minRadius = min(min(cornerRadius.x, cornerRadius.y),
        min(cornerRadius.z, cornerRadius.w));
    vec2 gradient = gradSdRoundedBox(position, halfBlurSize,
        max(minRadius, 1.0));
    vec2 outward = length(gradient) > 1e-5 ? normalize(gradient)
        : vec2(0.0, 1.0);
    float sideArcFacing = smoothstep(0.46, 0.98, abs(outward.x));
    float edgeDistance = -dist;
    float sideArcSigma = max(edgeAntialiasWidth * 0.58, 0.72);
    float sideArcGlint = exp(-0.5 * pow((edgeDistance - 1.0)
        / sideArcSigma, 2.0)) * pow(sideArcFacing, 1.8) * endcapSurface;

    float response = smoothstep(0.05, 0.75,
        clamp(refractionStrength, 0.0, 1.0)) * surfaceScale;
    rgb = mix(rgb, vec3(0.965, 0.982, 1.0), clamp(
        (topGlint * 0.47 + bottomGlint * 0.30) * response, 0.0, 0.49));
    rgb = mix(rgb, vec3(0.86, 0.90, 0.95), clamp(
        (sideGlint * 0.17 + sideArcGlint * 0.14) * response, 0.0, 0.18));
    return rgb;
}

vec4 bionicGlass(vec4 sum, vec4 cornerRadius)
{
    vec2 halfBlurSize = blurSize * 0.5;
    float minHalfSize = min(halfBlurSize.x, halfBlurSize.y);

    vec2 position = uv * blurSize - halfBlurSize.xy;
    float dist = roundedRectangleDist(position, halfBlurSize, cornerRadius);
    if (dist >= 0.0) {
        return sum;
    }

    // Rim normals (shared by refraction and rim lighting).
    float minR = min(min(cornerRadius.x, cornerRadius.y), min(cornerRadius.z, cornerRadius.w));
    float gradRadius = min(minR * 1.5, minHalfSize);
    vec2 gradient = gradSdRoundedBox(position, halfBlurSize, gradRadius);
    vec2 n2d = length(gradient) > 1e-5 ? -normalize(gradient) : vec2(0.0, 1.0);

    float interiorDist = -dist;   // 0 at the rim, grows inward
    const vec3 lumaW = vec3(0.299, 0.587, 0.114);

    // 1) Refraction — IOR-driven gentle lens inside the edge band.
    //    shapeThicknessPx drives the band width (native thicknessPx, the
    //    *30 scaling was the value-domain of the previous alignment).
    float refractAmp = clamp((bionicIOR - 1.0) * 0.15, 0.0, 0.4);
    float bandW = clamp(bionicShapeThicknessPx * 0.3, 8.0, 60.0);
    float bandT = 1.0 - clamp(interiorDist / bandW, 0.0, 1.0);
    float lens = circleMap(bandT);
    vec2 refrUv = clamp(uv + n2d * (refractAmp * lens), 0.0, 1.0);

    // 1.5) Liquid edge lens — 边缘带内的"液态拉伸"（原生折射域：IOR + edgeScale）：
    //      在靠近边缘的区域，背景 UV 以边缘权重做缩放变形——模拟液体的
    //      边缘透镜拉伸感（中心区域不变，避免整体模糊化）。
    //      edgeScale 系数对齐原生参数（refract 域 = 2.0 时的量级）。
    // 1.4) Liquid flow — 时间驱动的背景微流动（液态感）
    if (bionicFlowAmp > 0.0001) {
        float ft = bionicFlowTime;
        vec2 flow = vec2(
            sin(ft * 1.1 + refrUv.y * 7.0),
            cos(ft * 0.9 + refrUv.x * 7.0));
        refrUv = clamp(refrUv + flow * bionicFlowAmp, 0.0, 1.0);
    }
    {
        float edgeRefract = clamp((bionicIOR - 1.0) * 0.06, 0.0, 0.24);
        float edgeLensW = clamp(bionicShapeThicknessPx * 0.5, 6.0, 60.0);
        float lensT = 1.0 - clamp(interiorDist / edgeLensW, 0.0, 1.0);
        // 平滑的边缘权重（平方衰减，越靠边越强）
        float lensW = lensT * lensT;
        vec2 centered = refrUv - 0.5;
        refrUv = clamp(0.5 + centered * (1.0 - edgeRefract * lensW), 0.0, 1.0);
    }
    vec3 base = texture(texUnit, refrUv).rgb;

    // 2) Backdrop treatment — NATIVE ONLY.
    //    The single backdrop transform with a native formula is `darker`
    //    (verbatim from bloom_stroke.sksl):
    //      mix(col, vec3(0.07874,0.02848,0.09278),
    //          mix(0., darker, smoothstep(range.x, range.y, luma)))
    //    Saturation / brightness / luminance-step passes were OUR
    //    approximations and are removed — the native pipeline owns its own
    //    chroma & luma handling; we must not double-apply or invent one.
    const vec3 kBionicDarkTint = vec3(0.07874, 0.02848, 0.09278);
    float darkW = smoothstep(bionicDarkerRange0, bionicDarkerRange1, dot(base, lumaW));
    base = mix(base, kBionicDarkTint, mix(0.0, bionicDarker, darkW));

    vec3 rgb = base;

    // 3) Rim lighting — ported from bloom_stroke.sksl (calculateLighting /
    //    dynamicAdd / processLighting / hsvv).
    //    IMPORTANT: edgeK (rim-band mask) multiplies rawLight — the native
    //    processLighting only runs OUTSIDE the inner box; applying the lift
    //    across the whole surface floods the glass (overexposed + flat).
    float zR = clamp(bionicShapeThicknessPx * 0.15, 2.5, 12.0);
    float edgeK = 1.0 - clamp(interiorDist / zR, 0.0, 1.0);
    vec3 dirL = normalize(vec3(bionicDirX, bionicDirY, bionicDirZ));
    vec3 n3 = vec3(n2d.x, -n2d.y, sqrt(max(0.0, 1.0 - dot(n2d, n2d))));
    float ndl1 = max(dot(n3, dirL), 0.0);
    float light1 = ndl1 * max(1.0 - acos(clamp(ndl1, -1.0, 1.0))
                    / (3.14159 * max(bionicDirAngleRange, 0.05)), 0.0) * bionicDirIntensity;
    vec3 dirL2 = dirL * vec3(-1.0, -1.0, 1.0);
    float ndl2 = max(dot(n3, dirL2), 0.0);
    float light2 = ndl2 * max(1.0 - acos(clamp(ndl2, -1.0, 1.0))
                    / (3.14159 * max(bionicDirAngleRange, 0.05)), 0.0) * bionicDirOppositeIntensity;

    // dynamicAdd(color) + rawLight + knee -> lightenParam (verbatim chain,
    // restricted to the rim band so the interior stays untouched).
    float whiteDis = distance(vec3(1.0), rgb);
    whiteDis = smoothstep(0.2, 1.0, whiteDis);
    whiteDis = mix(0.2, 1.0, whiteDis);
    float lumin0 = dot(rgb, lumaW);
    float lightRatio = mix(0.8, whiteDis, lumin0);
    float rawLight = (light1 + light2) * lightRatio * edgeK;
    rawLight = pow(clamp(rawLight, 0.0, 1.0), 0.85);
    float knee = mix(1.0, 0.7, smoothstep(0.0, 0.5, lumin0));
    float lightenParam = rawLight / (rawLight + knee);

    // hsvv(col, lighten): centre-gain lift (native soft-light)
    {
        float v = dot(rgb, lumaW);
        float w = smoothstep(0.0, 0.5, v);
        float k = mix(1.0 - v, v, w);
        float g = 1.0 + smoothstep(0.0, 1.0, lightenParam) * mix(0.75, 0.4, w) * max(bionicHsvvBoost, 0.0);
        rgb = (rgb + vec3(k)) * g - vec3(k);
    }
    // clamp (native renderGlassShape does clamp(col, 0, 1) after colorPow)
    rgb = clamp(rgb, 0.0, 1.0);


    // Reflection pair / inner-surface passes removed — they were OUR
    // approximations (no native formula available); keeping them made the
    // material diverge from OS4.

    // 4) colorPow — native `pow(color, uColorPow)` (bloom_stroke.sksl).
    rgb = pow(max(rgb, vec3(0.0)), vec3(max(bionicColorPow, 0.05)));

    // 5) transparency (BionicOverallAlpha) — glass-layer opacity multiplier:
    //    lower = more see-through (background shows); no longer darkens rgb.
    float alphaScale = clamp(bionicOverallAlpha, 0.0, 1.0);

    // 6) shape.edge — soft edge transition width, clamped to 25 as in the
    //    native renderer. Applied at a reduced scale (0.2) so the Qt-side
    //    surfaces keep a crisp inner edge.
    // Soft edge width: edgePx maps to pixels at 1:5 scale, clamped to the
    // native 25px ceiling (72 -> 14.4px... too soft; 25 -> 5px; 125 -> 25px).
    float edgeSoft = clamp(bionicShapeEdgePx / 5.0, 0.1, 25.0);
    float edgeT = clamp(-dist / max(edgeSoft, 0.1), 0.0, 1.0);
    return vec4(rgb, smoothstep(0.0, 1.0, edgeT) * alphaScale);
}

// ── HyperOS light-frosted (Classic) render path ───────────────────────
// Native composition: the three colour layers are composited with the
// *blend modes* from the miuix ColorBlendToken tables instead of plain
// alpha stacking (the alpha stack read as a grey film).
//   Pured_Thin_Glass Dark : [PLUS_DARKER, LUMINOSITY, OVERLAY]
//   Pured_Thin_Glass Light: [PLUS_DARKER, SOFT_LIGHT, HARD_LIGHT]
float blendSoftLight(float a, float b)
{
    return (1.0 - 2.0 * b) * a * a + 2.0 * b * a;
}
vec3 blendSoftLight(vec3 a, vec3 b)
{
    return vec3(blendSoftLight(a.r, b.r), blendSoftLight(a.g, b.g), blendSoftLight(a.b, b.b));
}
vec3 blendOverlay(vec3 a, vec3 b)
{
    return mix(2.0 * a * b, 1.0 - 2.0 * (1.0 - a) * (1.0 - b), step(0.5, a));
}
vec3 blendHardLight(vec3 a, vec3 b)
{
    return blendOverlay(b, a);
}
vec3 blendPlusDarker(vec3 a, vec3 b)
{
    return max(vec3(0.0), a + b - 1.0);
}
vec3 blendLuminosity(vec3 a, vec3 b)
{
    // Keep the backdrop's chroma, take the layer's luminance.
    float lb = dot(b, vec3(0.299, 0.587, 0.114));
    float la = dot(a, vec3(0.299, 0.587, 0.114));
    return clamp(a + (lb - la), 0.0, 1.0);
}

vec3 classicDarkLayers(vec3 c, vec4 l0, vec4 l1, vec4 l2)
{
    c = mix(c, blendPlusDarker(c, l0.rgb), l0.a);
    c = mix(c, blendLuminosity(c, l1.rgb), l1.a);
    c = mix(c, blendOverlay(c, l2.rgb), l2.a);
    return c;
}
vec3 classicLightLayers(vec3 c, vec4 l0, vec4 l1, vec4 l2)
{
    c = mix(c, blendPlusDarker(c, l0.rgb), l0.a);
    c = mix(c, blendSoftLight(c, l1.rgb), l1.a);
    c = mix(c, blendHardLight(c, l2.rgb), l2.a);
    return c;
}

vec4 classicGlass(vec4 sum, vec4 cornerRadius)
{
    vec2 halfBlurSize = blurSize * 0.5;
    float minHalfSize = min(halfBlurSize.x, halfBlurSize.y);

    vec2 position = uv * blurSize - halfBlurSize.xy;
    float dist = roundedRectangleDist(position, halfBlurSize, cornerRadius);
    if (dist >= 0.0) {
        return sum;
    }

    float interiorDist = -dist;

    // Rim normal (used by refraction and the bloom-stroke gradient).
    float minR = min(min(cornerRadius.x, cornerRadius.y), min(cornerRadius.z, cornerRadius.w));
    float gradRadius = min(minR * 1.5, minHalfSize);
    vec2 gradient2 = gradSdRoundedBox(position, halfBlurSize, gradRadius);
    vec2 n2d = length(gradient2) > 1e-5 ? -normalize(gradient2) : vec2(0.0, 1.0);

    // 1) Refraction — GlassToken$Refract.ior (1.5, thin-glass family):
    //    gentle lens inside the edge band (band ~= shape.thickness 60 * 0.3).
    float clRefAmp = clamp((classicRefractIOR - 1.0) * 0.15, 0.0, 0.4);
    float clBandW = 18.0;
    float clBandT = 1.0 - clamp(interiorDist / clBandW, 0.0, 1.0);
    float clLens = circleMap(clBandT);
    vec2 clRefrUv = clamp(uv + n2d * (clRefAmp * clLens), 0.0, 1.0);
    vec3 base = texture(texUnit, clRefrUv).rgb;

    // Scene-dependent layer stack (dark scene vs light scene).
    float bgLum = dot(base, vec3(0.299, 0.587, 0.114));
    vec3 darkSide = classicDarkLayers(base, classicDark0, classicDark1, classicDark2);
    vec3 lightSide = classicLightLayers(base, classicLight0, classicLight1, classicLight2);
    vec3 rgb = mix(darkSide, lightSide, smoothstep(0.25, 0.55, bgLum));

    // ── Bloom stroke (Glass_Stroke_Middle_Light / _Dark, native recipe) ──
    //   line: width 0.8dp (~2px), colour white @ 10%, 24-degree gradient.
    //   The previous build mistook the gradient angle (24) for the width,
    //   which painted a 24px white band -> the halo.
    float strokePx = max(classicStroke.x, 0.5);
    float lineT = 1.0 - clamp(interiorDist / strokePx, 0.0, 1.0);
    float line = lineT * lineT;                       // crisp, thin falloff
    float gradA = radians(classicStroke.z);
    vec2 gradDir = normalize(vec2(cos(gradA), -sin(gradA)));
    float gradFace = 0.5 + 0.5 * dot(-n2d, gradDir);  // 0..1 along rim
    float grad = mix(0.35, 1.0, gradFace);
    rgb += vec3(1.0) * line * grad * classicStroke.y;

    // ── Double light sources (BloomStrokeToken native values) ───────────
    // Light preset:  src1 rgb(1.0,0.5,0.7) a0.8 @(0.2,0.5,0)
    //                src2 rgb(1,1,1)      a0.3 @(0,1,1)
    // Dark preset:   src1 rgb(1.0,0.4,0.7) a0.8
    //                src2 rgb(1,1,1)      a0.2
    // Scene blend mirrors the colour-layer stack above; positions are the
    // native XY (screen y down), raking the stroke from the upper side.
    float srcScene = smoothstep(0.25, 0.55, bgLum);
    vec3 src1Col = mix(vec3(1.0, 0.4, 0.7), vec3(1.0, 0.5, 0.7), srcScene);
    float src1A = 0.8;
    vec3 src2Col = vec3(1.0);
    float src2A = mix(0.2, 0.3, srcScene);
    vec2 src1Dir = normalize(vec2(0.2, -0.5));   // native position (0.2, 0.5)
    vec2 src2Dir = normalize(vec2(0.0, -1.0));   // native position (0.0, 1.0)
    float beam1 = pow(clamp(dot(-n2d, src1Dir), 0.0, 1.0), 2.0);
    float beam2 = pow(clamp(dot(-n2d, src2Dir), 0.0, 1.0), 2.0);
    rgb += (src1Col * (beam1 * src1A) + src2Col * (beam2 * src2A)) * line * 0.35;

    // 2) Reflection — GlassToken$Reflect (lighten 2.0 / strength 0.6):
    //    the rim brightens where it faces the light.
    float clFace = max(n2d.y, 0.0) + max(-n2d.y, 0.0) * 0.35;
    // Gate the reflection to the stroke band: n2d is only meaningful near the
    // rim; in the flat interior it carries SDF-gradient quantization that the
    // ×lighten boost amplified into raster lines.
    float clReflK = clamp(clFace * classicReflStrength * 0.24, 0.0, 1.0) * line;
    rgb = mix(rgb, rgb * max(classicReflLighten, 0.0), clReflK);

    // ── maskBlur (native setMaskBlur(0x14 = 20)): feather the shape mask ─
    float maskSoft = max(classicMaskSoft, 0.1);
    float maskT = clamp(-dist / maskSoft, 0.0, 1.0);
    return vec4(rgb, smoothstep(0.0, 1.0, maskT));
}

vec4 glass(vec4 sum, vec4 cornerRadius)
{
    if (bionicMode == 1) {
        // Soft glass (HyperOS): fully independent of the KOS material.
        return bionicGlass(sum, cornerRadius);
    }
    if (classicMode == 1) {
        // Light frosted (HyperOS Classic): blur + colour layers + stroke.
        return classicGlass(sum, cornerRadius);
    }

    vec2 halfBlurSize = blurSize * 0.5;
    float minHalfSize = min(halfBlurSize.x, halfBlurSize.y);

    vec2 position = uv * blurSize - halfBlurSize.xy;
    float dist = roundedRectangleDist(position, halfBlurSize, cornerRadius);
    // Evaluate derivatives before the early return: doing so only in the
    // inside branch is undefined along the exact contour on some GPUs.
    float edgeAntialiasWidth = max(fwidth(dist), 0.75);

    if (dist >= 0.0) {
        return sum;
    }

    float minEsp = clamp(edgeSizePixels, 0.1, minHalfSize * 0.9);
    float edgeFactor = 1.0 - clamp(abs(dist) / minEsp, 0.0, 1.0);
    float concaveFactor = 1.0 - sqrt(1.0 - pow(smoothstep(0.0, 1.0, edgeFactor), refractionNormalPow));

    GlassFragment s;
    if (refractionStrength > 0.0) {
        vec4 r = clamp(cornerRadius * 2.0, min(64.0, minHalfSize), min(128.0, minHalfSize));
        s = physicallyBasedRefraction == 0
            ? glassRefraction(position, halfBlurSize, r, dist, edgeFactor, concaveFactor)
            : snellsRefraction(position, halfBlurSize, r, minHalfSize, dist, edgeFactor, concaveFactor);
    } else {
        s = GlassFragment(sum, dist, edgeFactor, concaveFactor, vec3(0.0, 0.0, 1.0), 1.0);
    }

    vec3 rgb = applyGlassTint(s.color.rgb);
    rgb = applyLiquidGlints(rgb, position, halfBlurSize, cornerRadius, dist,
        edgeAntialiasWidth);

    return roundedRectangle(uv * blurSize, rgb, cornerRadius);
}
