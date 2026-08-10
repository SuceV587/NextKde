uniform vec3 tintColor;
uniform float tintGray;
uniform float tintStrength;
uniform int autoTintAlpha;
uniform vec3 glowColor;
uniform float glowStrength;
uniform int edgeLighting;

uniform float edgeSizePixels;
uniform float highlightWidthPx;
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

GlassFragment glassRefraction(vec2 position, vec2 halfBlurSize, vec4 cornerRadius, float dist, float edgeFactor, float concaveFactor)
{
    const float h = 1.0;
    vec2 gradient = vec2(
            roundedRectangleDist(position + vec2(h, 0), halfBlurSize, cornerRadius) - roundedRectangleDist(position - vec2(h, 0), halfBlurSize, cornerRadius),
            roundedRectangleDist(position + vec2(0, h), halfBlurSize, cornerRadius) - roundedRectangleDist(position - vec2(0, h), halfBlurSize, cornerRadius)
    );

    vec2 normal = length(gradient) > 0.0 ? -normalize(gradient) : vec2(0.0, 1.0);

    float finalStrength = min(0.4 * concaveFactor * refractionStrength, 1.0);

    vec2 refractOffsetG = -normal.xy * finalStrength;
    vec2 refractOffsetR = -normal.xy * finalStrength;
    vec2 refractOffsetB = -normal.xy * finalStrength;

    // Different refraction offsets for each color channel
    float fringingFactor = refractionRGBFringing * 0.3;
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

// Adaptive highlight colour: on a dark background the highlight is pure white
// for maximum contrast; on a bright background it lifts just above the
// backdrop instead of clipping to flat white. This mirrors iOS liquid glass
// where the rim reads as a luminous edge, not a hardcoded white stripe.
vec3 adaptiveHighlightColor(vec3 backgroundColor)
{
    const vec3 grayscaleWeights = vec3(0.299, 0.587, 0.114);
    float backgroundGray = dot(backgroundColor, grayscaleWeights);

    // Dark bg -> white (1.0). Bright bg -> background + 0.35, clamped.
    // smoothstep gives a soft transition through mid-tones.
    float t = smoothstep(0.30, 0.70, backgroundGray);
    float brightHighlight = min(backgroundGray + 0.35, 1.0);
    return mix(vec3(1.0), vec3(brightHighlight), t);
}

// Luminosity-preserving bidirectional tint with a gentle saturation lift.
// A plain mix() toward black/white darkens the backdrop's luminance, which
// is what makes glass read as painted plastic. Keeping the backdrop's own
// luminance and only nudging its chroma (the essence of iOS "vibrancy")
// keeps the material transparent and rich.
vec3 applyGlassTint(vec3 backdrop)
{
    const vec3 grayscaleWeights = vec3(0.299, 0.587, 0.114);
    vec3 lifted = mix(vec3(dot(backdrop, grayscaleWeights)), backdrop, 1.08);
    float strength = adjustedTintStrength(tintStrength, lifted);
    vec3 tintCol = bidirectionalTintColor(lifted, tintColor);
    return mix(lifted, tintCol, strength);
}

// Half-circle lens profile of the rim bevel. dd is the distance from the
// rim (0 at the edge, growing inward); the height rises smoothly from 0 at
// the rim to zR at the inner edge of the band. Used to build the rim normal
// so the fresnel/specular lighting has its own geometry, independent of the
// refraction zone width.
float rimBandHeight(float dd, float zR)
{
    dd = clamp(dd, 0.0, zR);
    return sqrt(dd * (2.0 * zR - dd));
}
// ── End bidirectional tint ────────────────────────────────────────────

vec3 glassOutline(vec2 position, GlassFragment s, vec4 cornerRadius)
{
    // Tint is applied to the *backdrop* colour before any edge lighting is
    // added, so the rim highlights stay luminous instead of being dragged
    // toward the tint colour (black on bright backgrounds).
    vec3 baseColor = applyGlassTint(s.color.rgb);

    vec2 halfBlurSize = blurSize * 0.5;
    float minHalfSize = min(halfBlurSize.x, halfBlurSize.y);

    // ── Rim lighting, decoupled from the refraction zone ───────────────
    // The fresnel + specular below live inside their own band whose width is
    // highlightWidthPx, so widening RefractionEdgeSize (the refraction zone)
    // no longer thickens the highlight.
    float zR = clamp(highlightWidthPx, 0.5, minHalfSize * 0.5);

    // Bevel height field sampled by finite differences. The surface tilts
    // most at the rim (normalZ -> 0) and is flat in the interior
    // (normalZ -> 1), giving a continuous grazing-angle ramp instead of a
    // hardcoded stripe band.
    const float eps = 0.75;
    vec2 gradPosX = vec2(eps, 0.0);
    vec2 gradPosY = vec2(0.0, eps);
    float hR = rimBandHeight(-roundedRectangleDist(position + gradPosX, halfBlurSize, cornerRadius), zR);
    float hL = rimBandHeight(-roundedRectangleDist(position - gradPosX, halfBlurSize, cornerRadius), zR);
    float hU = rimBandHeight(-roundedRectangleDist(position + gradPosY, halfBlurSize, cornerRadius), zR);
    float hD = rimBandHeight(-roundedRectangleDist(position - gradPosY, halfBlurSize, cornerRadius), zR);
    vec2 hGrad = vec2(hR - hL, hU - hD) / (2.0 * eps);

    float invLen = inversesqrt(max(dot(hGrad, hGrad), 1e-8) + 1.0);
    float normalZ = invLen;                 // 1.0 in the interior, 0.0 at the rim
    float fresnel = 1.0 - normalZ;

    vec3 rgb = baseColor;
    vec3 rimLight = adaptiveHighlightColor(baseColor);

    // Fresnel rim: soft luminous edge, added additively so it reads as light
    // catching the edge rather than a painted stripe.
    rgb += rimLight * fresnel * 0.16;

    // Diagonal key-light glint (strongest at the top-right corner, fading
    // around the shape) — the asymmetric "wet" highlight from iOS instead of
    // a uniform white band.
    vec2 n2d = hGrad * invLen;
    const vec2 lightDir = vec2(0.7071, 0.7071);
    float spec = pow(max(dot(n2d, lightDir), 0.0), 14.0);
    rgb += rimLight * spec * fresnel * 0.35;

    return rgb;
}

vec4 glass(vec4 sum, vec4 cornerRadius)
{
    vec2 halfBlurSize = blurSize * 0.5;
    float minHalfSize = min(halfBlurSize.x, halfBlurSize.y);

    vec2 position = uv * blurSize - halfBlurSize.xy;
    float dist = roundedRectangleDist(position, halfBlurSize, cornerRadius);

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

    // Tint + rim lighting are applied inside glassOutline() on the backdrop
    // colour only, so edge highlights stay bright. When there is no edge
    // outline (flat centre), apply the tint directly to the backdrop.
    vec3 rgb;
    if (s.concaveFactor < 1.0) {
        rgb = glassOutline(position, s, cornerRadius);
    } else {
        rgb = applyGlassTint(s.color.rgb);
    }
    return roundedRectangle(uv * blurSize, rgb, cornerRadius);
}
