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

// iOS glass reflects the environment above it: a faint band of light falling
// from the top edge across the whole surface. Distinct from the bevel (which
// is confined to the rim band) — this covers the glass interior, scaled per
// window type so the dock reads more "glassy" than popups.
float topEnvironmentReflection(vec2 position, vec2 halfBlurSize)
{
    float t = position.y / halfBlurSize.y;   // -1 top, +1 bottom
    return smoothstep(0.3, -0.7, t);
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

    float n2dLen = max(length(hGrad), 1e-5);
    vec2 n2d = hGrad / n2dLen;              // unit 2D rim normal (points inward)

    // Inner shadow (container lip): a soft dark band just inside the rim,
    // mirroring the recessed lip of iOS glass. It multiplies the *base*
    // colour only, before any highlight is added, so the highlights layer on
    // top of it instead of being swallowed by it. The band starts just off
    // the very edge (0.35zR) and extends past the highlight band (to 1.6zR),
    // so the outer edge stays a bright highlight line while the lip shades.
    // Inner shadow (container lip), directional like iOS: the glass is lit
    // from above, so the lip shadow is strongest just under the bright top
    // edge and fades toward the bottom (which the bevel already dims) and
    // the sides. Not a uniform all-around band. The band eases in from the
    // edge and dissolves progressively inward, so it reads as a recessed lip
    // rather than a hard ring.
    float shadowW = zR * 1.6;
    float topWeight = smoothstep(0.35, -0.35, position.y / halfBlurSize.y);
    float innerShadow = smoothstep(0.0, zR * 0.3, -s.dist)
                      * (1.0 - smoothstep(shadowW * 0.5, shadowW, -s.dist))
                      * mix(0.25, 1.0, topWeight);

    vec3 rgb = baseColor * (1.0 - innerShadow * 0.15);
    vec3 highlight = getHighlightColor(baseColor, 1.0);

    // ── Focused edge highlight (iOS-style partial rim) ────────────────
    // iOS glass does NOT draw a full enclosing rim. The highlight is the
    // mirror reflection of a directional light source off the bevel's normal
    // field: only the arc whose outward normal faces the light is bright, the
    // rest of the rim stays dark. Because both corners along the light's
    // diagonal share normals that face it, the highlight reads as "top-left +
    // bottom-right" (or the opposite diagonal) instead of a closed ring.
    //
    // -n2d is the outward rim normal. highlightAngle (degrees, kwinrc) picks
    //   the light direction. abs() is the iOS diagonal: the two corners on the
    //   light's diagonal share mirror-symmetric outward normals (top-left
    //   faces 225° when the light is at 45°), so BOTH corners light up as
    //   "top-left + bottom-right" (or the opposite diagonal) - the signature
    //   partial-rim look. Without abs, only one corner would be lit.
    //   highlightAngle < 0 (applauncher) falls back to a uniform ring: all
    //   edges lit equally, no directional focus.
    float angleRad = highlightAngle * 3.14159265 / 180.0;
    vec2 lightDir = vec2(cos(angleRad), sin(angleRad));
    float facing = abs(dot(-n2d, lightDir));
    float focused = smoothstep(0.25, 1.0, facing);
    if (highlightAngle < 0.0) {
        focused = 1.0;
    }

    // Faint all-around fresnel keeps the rim visible on dark backdrops, but
    // deliberately low so the arc reads as the light source, not a ring.
    rgb += highlight * fresnel * 0.05 * surfaceScale;
    // The directional arc: brightest where the normal faces the light.
    // 0.42 keeps it subtle - a sheen, not a painted stripe.
    rgb += highlight * fresnel * focused * 0.42 * surfaceScale;

    // Synthetic bevel: the top edge catches light while the bottom shades
    // (n2d.y > 0 on the top edge), giving the material a physical thickness.
    // Kept independent of the diagonal arc - it is the "3D slab" cue, the arc
    // is the liquid reflection.
    float bevelGradient = n2d.y * 0.15;
    rgb += highlight * (bevelGradient * fresnel) * surfaceScale;

    // Specular sheen on the same light direction, so the whole highlight
    // rotates together when highlightAngle changes. No back-kick: a second
    // opposing light would re-add the symmetric full-ring glow.
    vec2 anisoN = (n2d + vec2(-n2d.y, n2d.x) * 0.2) * 0.9805806;
    float mainLight = max(dot(anisoN, lightDir), 0.0);
    float directional = mainLight * sqrt(mainLight) * 0.7;
    float brightnessRaw = (directional + 0.02) * fresnel * 0.4 * surfaceScale;
    float brightness = brightnessRaw / (1.0 + brightnessRaw);
    rgb = mix(rgb, highlight, brightness);

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
    // colour only, so edge highlights stay bright. The outline zone spans
    // both the refraction band (edgeSizePixels) and the rim band
    // (highlightWidthPx), so widening either one never clips the other.
    float zR = clamp(highlightWidthPx, 0.5, minHalfSize * 0.5);
    float glassZone = max(minEsp, zR);
    vec3 rgb;
    if (abs(dist) < glassZone) {
        rgb = glassOutline(position, s, cornerRadius);
    } else {
        rgb = applyGlassTint(s.color.rgb);
    }

    // Top environment reflection over the whole surface, scaled per window
    // type so the dock reads more "glassy" than popups.
    float topReflection = topEnvironmentReflection(position, halfBlurSize);
    rgb += getHighlightColor(rgb, 1.0) * topReflection * 0.08 * surfaceScale;

    return roundedRectangle(uv * blurSize, rgb, cornerRadius);
}
