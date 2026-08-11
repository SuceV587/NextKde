#version 440 core
#extension GL_ARB_separate_shader_objects : enable
#extension GL_ARB_shading_language_420pack : enable

layout(location = 0) in vec2 v_texCoord;
layout(location = 0) out vec4 fragColor;

// The pre-blurred wallpaper texture covering the full screen. The QML side
// blurs the raw wallpaper via MultiEffect before binding it here, so this
// shader only handles refraction + SDF mask + highlight + tint.
layout(binding = 1) uniform sampler2D u_wallpaper;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    // Card geometry in screen-logical pixels.
    vec2 u_cardScreenPos;   // top-left of the card, in screen coords
    vec2 u_cardSize;        // card width/height in pixels
    vec2 u_screenSize;      // full screen size in pixels
    float u_cornerRadius;   // corner radius in pixels

    // Material parameters.
    float u_refractionStrength; // 0..1, lens bend amount
    float u_dispersion;         // 0..1, chromatic aberration
    float u_innerShadow;        // 0..1, directional inset darkening
    float u_highlightFalloff;   // specular falloff exponent
    float u_highlightIntensity; // 0..1 specular brightness
    vec4 u_tintColor;           // RGBA tint (alpha controls strength)
    vec4 u_highlightColor;      // RGBA highlight color
    // Light direction for the specular highlight (normalized, screen space).
    vec2 u_lightDir;
};

// ── SDF: rounded box (Kyant0 sdRoundedRect, iquilezles sdRoundedBox) ──
// p: position relative to box center. b: half-extents. r: corner radius.
float sdRoundedBox(vec2 p, vec2 b, float r)
{
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// Analytic gradient of sdRoundedBox, used as the surface normal for both
// refraction and the directional highlight. (Kyant0 gradSdRoundedRect.)
vec2 gradSdRoundedBox(vec2 p, vec2 b, float r)
{
    vec2 q = abs(p) - b + r;
    // Region classification: inside the cross (q.x<0 && q.y<0) gives axis-aligned
    // normal; outside the corner circle gives radial normal.
    vec2 sgn = sign(p);
    vec2 outside = max(q, 0.0);
    float lenOut = length(outside);
    if (lenOut > 1e-5) {
        return sgn * outside / lenOut;
    }
    // Inside region: normal points toward nearest edge.
    return (q.x > q.y) ? vec2(sgn.x, 0.0) : vec2(0.0, sgn.y);
}

// Kyant0 circleMap: a circular-arc lens profile. 0 at the very edge,
// rising toward refractionAmount deeper inside the band.
float circleMap(float x)
{
    return 1.0 - sqrt(1.0 - clamp(x, 0.0, 1.0) * x);
}

void main()
{
    // Card-local centered coordinate, in pixels.
    vec2 cardPx = v_texCoord * u_cardSize;
    vec2 center = u_cardSize * 0.5;
    vec2 p = cardPx - center;

    float r = clamp(u_cornerRadius, 0.0, min(u_cardSize.x, u_cardSize.y) * 0.5);
    float dist = sdRoundedBox(p, center, r);

    // Sub-pixel anti-aliased mask from the SDF. This replaces the 1px-scanline
    // rasterization that caused aliasing on the old KWin region path.
    float aaWidth = fwidth(dist);
    // alpha = 1 fully inside, 0 fully outside, smooth at the edge.
    float alpha = 1.0 - smoothstep(-aaWidth, aaWidth, dist);
    if (alpha <= 0.001) discard;

    // ── UV into the (already-cropped) wallpaper texture ──
    // The MultiEffect blur input is a ShaderEffectSource cropped to this card's
    // screen region, so the texture already spans exactly the card. v_texCoord
    // (0..1) maps directly into it - no screen-space math needed.
    vec2 baseUV = v_texCoord;

    // ── Refraction: bend the sampling UV along the SDF normal ──
    // Only the band near the edge bends; the deep interior samples straight.
    float refractionHeight = max(r, 4.0) * 1.5;
    vec2 refractedUV = baseUV;
    if (u_refractionStrength > 0.001) {
        float interiorDist = -dist; // positive inside
        if (interiorDist < refractionHeight) {
            float bandT = 1.0 - clamp(interiorDist / refractionHeight, 0.0, 1.0);
            float magnitude = circleMap(bandT) * u_refractionStrength * r * 0.5;
            vec2 grad = gradSdRoundedBox(p, center, r);
            float gradLen = length(grad);
            vec2 normal = gradLen > 1e-5 ? grad / gradLen : vec2(0.0);
            // Displacement in card-texture UV units (cardSize pixels = 1.0 UV).
            vec2 disp = normal * magnitude / u_cardSize;
            refractedUV = baseUV + disp;
        }
    }

    // ── Sample wallpaper (pre-blurred by MultiEffect on the QML side) ──
    vec3 baseColor;
    if (u_dispersion > 0.001) {
        // 3-tap chromatic aberration along the refraction normal, strongest at
        // corners (Kyant0 uses 7 taps; 3 is enough for the subtle fringe).
        vec2 grad = gradSdRoundedBox(p, center, r);
        vec2 normal = length(grad) > 1e-5 ? normalize(grad) : vec2(0.0);
        float fringe = u_dispersion * 0.35 / max(u_cardSize.x, 1.0);
        float rC = texture(u_wallpaper, clamp(refractedUV + normal * fringe, 0.0, 1.0)).r;
        vec3  gC = texture(u_wallpaper, clamp(refractedUV, 0.0, 1.0)).rgb;
        float bC = texture(u_wallpaper, clamp(refractedUV - normal * fringe, 0.0, 1.0)).b;
        baseColor = vec3(rC, gC.g, bC);
    } else {
        baseColor = texture(u_wallpaper, clamp(refractedUV, 0.0, 1.0)).rgb;
    }

    // ── Bidirectional tint: adapt to wallpaper luminance ──
    float lum = dot(baseColor, vec3(0.2126, 0.7152, 0.0722));
    // Dark backgrounds lift toward the tint's bright side; bright backgrounds
    // darken slightly for readability. Keeps text legible on any wallpaper.
    float tintAmount = u_tintColor.a;
    float tintMix = tintAmount * mix(1.3, 0.7, clamp(lum, 0.0, 1.0));
    vec3 tinted = mix(baseColor, baseColor * (1.0 - tintAmount) + u_tintColor.rgb * tintAmount, tintMix);

    // ── Inner shadow: directional (top-weighted) inset darkening ──
    // Applied to the base before highlights so the rim light still reads.
    if (u_innerShadow > 0.001) {
        float edgeProximity = clamp(1.0 - (-dist) / max(r, 1.0), 0.0, 1.0);
        // Top edge darker, bottom edge lighter — a soft directional inset.
        float dirFactor = clamp(-p.y / max(center.y, 1.0) * 0.5 + 0.5, 0.0, 1.0);
        float shadow = edgeProximity * u_innerShadow * mix(0.6, 1.0, dirFactor);
        tinted *= (1.0 - shadow * 0.25);
    }

    // ── Specular highlight: SDF-normal driven directional sheen ──
    // (Kyant0 DefaultHighlightShaderString: pow(abs(dot(grad, lightDir)), falloff))
    vec3 finalColor = tinted;
    if (u_highlightIntensity > 0.001) {
        vec2 grad = gradSdRoundedBox(p, center, r);
        vec2 normal = length(grad) > 1e-5 ? normalize(grad) : vec2(0.0, 1.0);
        float d = dot(normal, u_lightDir);
        float spec = pow(abs(d), max(u_highlightFalloff, 1.0));
        // Only show highlight near the edge band.
        float edgeBand = smoothstep(0.0, 1.0, clamp((-dist) / max(r, 1.0), 0.0, 1.0));
        spec *= u_highlightIntensity * edgeBand;
        finalColor += u_highlightColor.rgb * u_highlightColor.a * spec;
    }

    // ── Top reflection: a soft bright sheen across the top of the card ──
    // Gives the glass body depth without a hard border line.
    float topSheen = smoothstep(0.5, 0.0, v_texCoord.y) * 0.10;
    finalColor += vec3(topSheen);

    fragColor = vec4(finalColor, alpha * qt_Opacity);
}
