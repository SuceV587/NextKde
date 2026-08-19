#version 440 core
#extension GL_ARB_separate_shader_objects : enable
#extension GL_ARB_shading_language_420pack : enable

layout(location = 0) in vec2 v_texCoord;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D u_source;

// Uniform order MUST match the QML ShaderEffect property declarations.
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float u_refraction;      // convex-lens refraction strength (0 = none)
    float u_specular;        // specular highlight strength
    float u_glassAlpha;      // glass white opacity (rest of the surface stays translucent)
    float u_cornerRadius;    // pill corner radius in px
    float u_blurRadius;      // background blur radius in px (0 = none)
    vec2 u_size;             // element size in px
    vec2 u_uvOffset;         // element origin in the source texture (normalized)
    vec2 u_uvScale;          // element size / source texture size
    vec4 u_tint;             // glass tint (rgb multiplied, a = mix amount)
};

float sdRoundedBox(vec2 p, vec2 b, float r)
{
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main()
{
    // Local UV is used for shape/highlights and as the lens centre; the
    // source UV maps the element onto the background texture so thumb and
    // background bar sample the pixels that are really underneath them.
    vec2 localUV = v_texCoord;
    vec2 uv = localUV * u_uvScale + u_uvOffset;
    vec2 px = 1.0 / u_size;

    // ---- Convex lens refraction: magnify around the centre ----
    // Sampling point moves outward by the strength with a centre-weighted
    // falloff, so content near the middle is magnified (the Vue displacement
    // map's convex_circle surface) and edges stay untouched.
    vec2 center = vec2(0.5);
    vec2 delta = localUV - center;
    float dist = length(delta);
    float falloff = 1.0 - smoothstep(0.0, 0.45, dist);
    vec2 uv2 = uv + delta * u_refraction * falloff;

    // ---- Background blur (3x3 gaussian, approximates feGaussianBlur) ----
    vec4 bg = vec4(0.0);
    float total = 0.0;
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            float w = 1.0 / (1.0 + float(i * i + j * j));
            bg += texture(u_source, uv2 + vec2(float(i), float(j)) * px * u_blurRadius) * w;
            total += w;
        }
    }
    bg /= total;

    // ---- Glass body: white veil over the refracted background ----
    vec3 color = mix(bg.rgb, vec3(1.0), u_glassAlpha);

    // ---- Specular highlights ----
    // Rim light from the pill SDF (bright near the edge, like the Vue
    // feSpecularLighting) plus a soft top sheen.
    float aspect = u_size.y / u_size.x;
    vec2 halfB = vec2(1.0, aspect);
    float r = min(u_cornerRadius / (u_size.x * 0.5), min(halfB.x, halfB.y));
    float d = sdRoundedBox(localUV * 2.0 - 1.0, halfB, r);

    float rim = exp(clamp(d, -1.0, 0.0) * 9.0);
    float topSheen = smoothstep(0.85, 0.35, localUV.y);
    color += vec3(rim * 0.7 + topSheen * 0.5) * u_specular;

    // ---- Tint ----
    color = mix(color, color * u_tint.rgb, u_tint.a);

    // Surface stays translucent so content above (items) shows through,
    // while the refracted background is carried in the colour channels.
    fragColor = vec4(color, qt_Opacity * (1.0 - u_glassAlpha));
}
