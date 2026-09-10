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
