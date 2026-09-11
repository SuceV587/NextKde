uniform vec3 tintColor;
uniform float tintGray;
uniform float tintStrength;
uniform int autoTintAlpha;
uniform vec3 glowColor;
uniform float glowStrength;
uniform int edgeLighting;

uniform float edgeSizePixels;
uniform float highlightWidthPx;
uniform float surfaceScale;
// Semantic high-information surfaces may use a deeper material only when the
// real framebuffer behind them is nearly white. This is deliberately not a
// generic opacity/tint knob: normal glass (including Dock) keeps transmission.
uniform float brightMaterialDarkStyle;
// Optical distortion belongs to small, directly manipulated controls.  Large
// persistent surfaces keep the material treatment but use a quieter lens.
uniform float lensStrengthScale;
uniform float refractionStrength;
uniform float refractionNormalPow;
uniform float refractionRGBFringing;
uniform float refractionOffsetStrength;
uniform float refractionBevelIntensity;
uniform int physicallyBasedRefraction;

// Cheap cubic approximation of the sRGB transfer function. Brightness
// classification happens in linear light without three per-pixel pow() calls.
vec3 srgbToLinearApprox(vec3 color)
{
    vec3 c = clamp(color, 0.0, 1.0);
    return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
}

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
    float backdropComplexity;
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

struct GlassBevel {
    float depth;
    float height;
    float slope;
    vec2 outward;
    vec3 normal;
};

GlassBevel evaluateGlassBevel(vec2 position, vec2 halfSize,
    vec4 cornerRadius, float dist, float width)
{
    float minHalfSize = min(halfSize.x, halfSize.y);
    float minR = min(min(cornerRadius.x, cornerRadius.y),
        min(cornerRadius.z, cornerRadius.w));
    float gradRadius = min(max(minR * 1.5, 1.0), minHalfSize);
    vec2 gradient = gradSdRoundedBox(position, halfSize, gradRadius);
    vec2 outward = length(gradient) > 1e-5
        ? normalize(gradient) : vec2(0.0, 1.0);

    float depth = clamp((-dist) / max(width, 1e-4), 0.0, 1.0);
    float rimT = 1.0 - depth;
    float height = circleMap(rimT);
    // Analytic derivative of circleMap, clamped at the physical rim where an
    // ideal lens tends to infinity. One profile now drives all optical layers.
    float denominator = sqrt(max(1.0 - rimT * rimT, 0.015));
    float slope = min(rimT / denominator, 3.2);
    vec3 normal = normalize(vec3(outward * slope, 1.0));
    return GlassBevel(depth, height, slope, outward, normal);
}

GlassFragment glassRefraction(vec2 position, vec2 halfBlurSize,
    vec4 cornerRadius, float dist, float edgeFactor,
    float concaveFactor, GlassBevel bevel)
{
    // Kyant0 lens: circleMap supplies a pixel-space displacement along the
    // rounded-rectangle SDF gradient. Keep it in pixels until the texture
    // lookup so wide surfaces do not bend farther merely because their UVs
    // cover a larger window.
    vec2 centeredDirection = position / max(halfBlurSize, vec2(1.0));
    vec2 lensDirection = normalize(bevel.outward
        + centeredDirection * refractionOffsetStrength * 0.18);
    // Preserve the peak at the rim but let lensing settle sooner toward the
    // content-bearing interior. This follows the edge-confined Kyant profile
    // without lowering the configured peak strength.
    float opticalHeight = pow(bevel.height, 1.35);
    float displacementPx = opticalHeight * edgeSizePixels
        * refractionStrength * lensStrengthScale;
    vec2 refractOffsetG = lensDirection * displacementPx / blurSize;

    // Corner-weighted chromatic aberration (Kyant0): a real rectangular lens
    // fringes most at its corners and not at all on the axes, so the colour
    // split scales with signed x*y across the surface. The corner emphasis is the
    // structural change (parameter-unreachable); the overall amount stays
    // parameter-driven via refractionRGBFringing.
    vec2 centeredNorm = position / halfBlurSize;
    float dispersionIntensity = refractionRGBFringing
        * centeredNorm.x * centeredNorm.y;
    vec2 dispersedOffset = refractOffsetG * dispersionIntensity;
    vec2 refractedUv = uv + refractOffsetG;

    // Kyant0-style seven-band dispersion. The previous three-channel
    // approximation shifted each channel by only a fraction of a pixel after
    // all scale factors, so its colour separation vanished under compositor
    // blur. These weights reconstruct a smooth visible spectrum at the rim.
    vec4 color;
    if (abs(dispersionIntensity) > 0.001) {
        vec4 red = texture(texUnit, clamp(refractedUv + dispersedOffset, 0.0, 1.0));
        vec4 orange = texture(texUnit, clamp(refractedUv + dispersedOffset * (2.0 / 3.0), 0.0, 1.0));
        vec4 yellow = texture(texUnit, clamp(refractedUv + dispersedOffset * (1.0 / 3.0), 0.0, 1.0));
        vec4 green = texture(texUnit, clamp(refractedUv, 0.0, 1.0));
        vec4 cyan = texture(texUnit, clamp(refractedUv - dispersedOffset * (1.0 / 3.0), 0.0, 1.0));
        vec4 blue = texture(texUnit, clamp(refractedUv - dispersedOffset * (2.0 / 3.0), 0.0, 1.0));
        vec4 purple = texture(texUnit, clamp(refractedUv - dispersedOffset, 0.0, 1.0));
        color = vec4(
            red.r / 3.5 + orange.r / 3.5 + yellow.r / 3.5 + purple.r / 7.0,
            orange.g / 7.0 + yellow.g / 3.5 + green.g / 3.5 + cyan.g / 3.5,
            cyan.b / 3.0 + blue.b / 3.0 + purple.b / 3.0,
            green.a
        );
    } else {
        color = texture(texUnit, clamp(refractedUv, 0.0, 1.0));
    }
    return GlassFragment(color, dist, edgeFactor, concaveFactor,
        bevel.normal, 1.0, 0.0);
}

// ── White-ink adaptive tint ───────────────────────────────────────────
// Shell chrome uses white foreground content in both themes. Tint therefore
// responds in one direction only: bright framebuffer content is darkened,
// while already-dark content is preserved.
float adjustedTintStrength(float baseTintStrength, vec3 backgroundColor)
{
    float strength = clamp(baseTintStrength, 0.0, 1.0);
    const vec3 grayscaleWeights = vec3(0.2126, 0.7152, 0.0722);
    float backgroundGray = dot(srgbToLinearApprox(backgroundColor),
        grayscaleWeights);
    float backgroundChroma = max(max(backgroundColor.r, backgroundColor.g),
        backgroundColor.b) - min(min(backgroundColor.r, backgroundColor.g),
        backgroundColor.b);
    // Low-chroma whites and greys need protection before blur pulls their
    // measured luminance down. Saturated middle tones such as pink remain in
    // the chromatic branch, while genuinely intense highlights always darken.
    float neutralBright = smoothstep(0.260, 0.500, backgroundGray)
        * (1.0 - smoothstep(0.070, 0.220, backgroundChroma));
    float absoluteBright = smoothstep(0.500, 0.720, backgroundGray);
    float brightMask = max(neutralBright, absoluteBright);
    // Bright documents need only a small chroma/tint correction. A larger
    // cap pre-darkens the framebuffer before the readability budget below can
    // account for it, making transparent cards look like grey scrims.
    return min(strength * brightMask, 0.08);
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
    return mix(lifted, tintColor, strength);
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

vec4 glass(vec4 sum, vec4 cornerRadius)
{
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
    float bevelWidth = clamp(minEsp, 2.0, minHalfSize * 0.9);
    GlassBevel bevel = evaluateGlassBevel(position, halfBlurSize,
        cornerRadius, dist, bevelWidth);

    GlassFragment s;
    if (refractionStrength > 0.0) {
        vec4 r = clamp(cornerRadius * 2.0, min(64.0, minHalfSize), min(128.0, minHalfSize));
        s = physicallyBasedRefraction == 0
            ? glassRefraction(position, halfBlurSize, r, dist, edgeFactor,
                concaveFactor, bevel)
            : snellsRefraction(position, halfBlurSize, r, minHalfSize, dist, edgeFactor, concaveFactor);
    } else {
        s = GlassFragment(sum, dist, edgeFactor, concaveFactor,
            vec3(0.0, 0.0, 1.0), 1.0, 0.0);
    }

    vec3 rgb = applyGlassTint(s.color.rgb);
    rgb = applyLiquidGlints(rgb, position, halfBlurSize, cornerRadius, dist,
        edgeAntialiasWidth);

    return roundedRectangle(uv * blurSize, rgb, cornerRadius);
}
