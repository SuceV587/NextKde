#version 440 core
#extension GL_ARB_separate_shader_objects : enable
#extension GL_ARB_shading_language_420pack : enable

layout(location = 0) in vec2 v_texCoord;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float u_radius;
    float u_strength;
    float u_reflectionScale;
    float u_depth;
    float u_bottomShade;
    vec2 u_size;
};

float sdRoundedBox(vec2 p, vec2 halfSize, float radius)
{
    vec2 q = abs(p) - halfSize + radius;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

vec2 sdfNormal(vec2 p, vec2 halfSize, float radius)
{
    // One-pixel central differences keep the edge direction stable at every
    // aspect ratio and naturally carry the highlight around rounded corners.
    vec2 e = vec2(1.0, 0.0);
    vec2 gradient = vec2(
        sdRoundedBox(p + e.xy, halfSize, radius)
            - sdRoundedBox(p - e.xy, halfSize, radius),
        sdRoundedBox(p + e.yx, halfSize, radius)
            - sdRoundedBox(p - e.yx, halfSize, radius));
    float gradientLength = length(gradient);
    return gradientLength > 1e-4 ? gradient / gradientLength : vec2(0.0, -1.0);
}

void main()
{
    vec2 pixel = v_texCoord * u_size;
    vec2 halfSize = u_size * 0.5;
    vec2 p = pixel - halfSize;
    float radius = clamp(u_radius, 0.0, min(halfSize.x, halfSize.y));
    float distanceToEdge = sdRoundedBox(p, halfSize, radius);

    // Match the Rectangle's antialiased outer coverage while keeping all
    // lighting inside the material.
    // Never paint outside the owning QML rectangle. Apart from avoiding a
    // one-pixel halo, this keeps neighbouring control-centre cards visually
    // independent even though Rectangle children are not clipped by default.
    float coverage = smoothstep(0.15, -0.85, distanceToEdge);
    if (coverage <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float inside = max(0.0, -distanceToEdge);
    float bevelWidth = clamp(min(u_size.x, u_size.y) * 0.10, 3.0, 8.0);
    float bevel = 1.0 - smoothstep(0.0, bevelWidth, inside);
    float innerRim = 1.0 - smoothstep(0.35, bevelWidth * 0.72, inside);
    vec2 edgeNormal = sdfNormal(p, halfSize, radius);

    // A shallow convex bevel reconstructed from the SDF. It stays flat in the
    // centre and becomes steep only near the rim, like a moulded glass lens.
    // The old 2.2 slope aligned with the half-vector halfway through the
    // bevel, creating a detached bright bulge on small pills. A shallower
    // profile puts the specular maximum back against the physical rim.
    float slope = 0.72 * bevel * bevel;
    vec3 normal = normalize(vec3(edgeNormal * slope, 1.0));
    vec3 light = normalize(vec3(-0.42, -0.76, 0.72));
    vec3 view = vec3(0.0, 0.0, 1.0);
    vec3 halfVector = normalize(light + view);

    float specular = pow(max(dot(normal, halfVector), 0.0), 18.0);
    float fresnel = pow(1.0 - max(normal.z, 0.0), 2.4);
    float facingLight = max(dot(edgeNormal, normalize(light.xy)), 0.0);
    // Treat this as an environmental reflection, not a bevel. Only the
    // upper, light-facing rim receives a quiet glint; drawing an opposite
    // dark/bright band made menus and cards look stamped into plastic.
    float bright = (specular * 0.18 + fresnel * facingLight * 0.11)
        * innerRim;
    float brightAlpha = clamp(bright * u_strength * u_reflectionScale,
        0.0, 0.16);
    float alpha = brightAlpha * coverage;

    // Very slight cool/warm dispersion at the lateral shoulders prevents a
    // perfectly neutral computer-drawn edge without turning it iridescent.
    vec3 cool = vec3(0.90, 0.955, 1.0);
    vec3 warm = vec3(1.0, 0.94, 0.97);
    vec3 highlightColor = mix(cool, warm, smoothstep(-1.0, 1.0, edgeNormal.x));
    vec3 color = highlightColor;

    fragColor = vec4(color * alpha, alpha) * qt_Opacity;
}
