#version 440 core
#extension GL_ARB_separate_shader_objects : enable
#extension GL_ARB_shading_language_420pack : enable

layout(location = 0) in vec2 v_texCoord;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D u_in;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float u_noise;
    float u_glowWeight;
    float u_glowBias;
    float u_glowEdge0;
    float u_glowEdge1;
    float u_glowFocus;
    float u_glowAngle;
    float u_powFactor;
    float u_factor;
    int u_cornerRadius;
    int u_glowPattern;
    vec2 u_screenResolution;
    vec2 u_panelPosition;
    vec2 u_panelSize;
    vec4 u_color;
    vec4 u_glowColor;
};

float sdRoundedBox(vec2 p, vec2 b, float r)
{
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

float rand(vec2 co)
{
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main()
{
    // ── Panel-local UV (matches demo) ──
    vec2 uv = v_texCoord * 2.0 - 1.0;                  // [-1, 1]

    // ── Aspect-ratio correction for SDF mask ──
    // Scale so one unit = same pixel distance in both x and y,
    // so corner radius is circular regardless of panel aspect ratio.
    float aspect = u_panelSize.y / u_panelSize.x;
    vec2 squareUV = uv * vec2(1.0, aspect);
    vec2 boxHalf  = vec2(1.0, aspect);

    float pxPerUnit = u_panelSize.x * 0.5;
    float r = min(u_cornerRadius / pxPerUnit, min(boxHalf.x, boxHalf.y));
    float d = sdRoundedBox(squareUV, boxHalf, r);

    if (d >= 0.0) discard;

    // Normalize SDF so interior depth is always ~1.0 at the farthest point
    // from any edge, regardless of panel aspect ratio.  Without this, thin
    // panels (e.g. 1920×32 topbar) have a shallow d everywhere, causing
    // near-maximum refraction and glow bleed across the entire surface.
    float interiorDepth = min(boxHalf.x, boxHalf.y);
    float dNorm = d / interiorDepth;

    // ── Screen-space UV ──
    vec2 screenUV = (u_panelPosition + v_texCoord * u_panelSize) / u_screenResolution;

    // ── Refraction — radial direction, matching demo ──
    // Demo uses simple normalize(uv) from center; NOT SDF gradient.
    vec2 dir = length(uv) > 1e-5 ? normalize(uv) : vec2(1.0, 0.0);

    float edgeProximity = clamp(1.0 - abs(dNorm), 0.0, 1.0);
    vec2 offset = -dir * u_factor * pow(edgeProximity, u_powFactor);

    // offset is in [-1,1] panel space. Convert to screen UV:
    // panel space [-1,1] spans panel width/height in pixels,
    // so offset_in_pixels = offset * 0.5 * panelSize.
    vec2 screenOffset = offset * 0.5 * u_panelSize / u_screenResolution;

    // ── Sample background + noise dither ──
    vec4 noise = vec4(vec3(rand(gl_FragCoord.xy * 1e-3) - 0.5), 0.0);
    vec4 color = texture(u_in, screenUV + screenOffset) + noise * u_noise;

    // ── Glow / rim light (matches demo distance calculation) ──
    float dist = length(uv);                           // raw [-1,1] distance
    vec2 dir2 = vec2(cos(u_glowAngle), sin(u_glowAngle));
    float directional = dot(dir, dir2) * 0.5 + 0.5;

    float glow;
    if (u_glowPattern == 0) {
        glow = sin(dist * 10.0 + u_glowAngle) * 0.5 + 0.5;
    } else {
        glow = mix(1.0 - dist, directional, u_glowFocus);
    }

    float glowIntensity = glow * u_glowWeight
        * smoothstep(u_glowEdge0, u_glowEdge1, abs(dNorm));

    vec3 glowEffect = u_glowColor.rgb * glowIntensity * u_glowColor.a;
    vec3 finalColor = color.rgb * (1.0 + u_glowBias) * u_color.rgb + glowEffect;

    fragColor = vec4(finalColor, color.a * u_color.a * qt_Opacity);
}
