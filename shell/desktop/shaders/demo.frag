#version 440 core
#extension GL_ARB_separate_shader_objects : enable
#extension GL_ARB_shading_language_420pack : enable

layout(location = 0) in vec2 v_texCoord;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    vec2 resolution;
    vec2 pointer;
    float time;
} ubuf;

float roundedRectSdf(vec2 p, vec2 halfSize, float radius)
{
    vec2 q = abs(p) - halfSize + vec2(radius);
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - radius;
}

void main()
{
    vec2 uv = v_texCoord;
    vec2 pixel = uv * ubuf.resolution;
    vec2 centered = pixel - ubuf.resolution * 0.5;

    float radius = 24.0;

    float sdf = roundedRectSdf(centered, ubuf.resolution * 0.5, radius);

    float mask = 1.0 - smoothstep(-1.0, 1.0, sdf);

    // inner edge highlight
    float innerEdge = smoothstep(-5.0, -1.0, sdf) * mask;

    // top lighting
    float topHighlight = pow(1.0 - uv.y, 5.0) * 0.28;

    // mouse glow
    vec2 mouseUv = ubuf.pointer / ubuf.resolution;
    float mouseDistance = distance(uv, mouseUv);
    float mouseGlow = smoothstep(0.32, 0.0, mouseDistance) * 0.18;

    // moving light band
    float movingBand = smoothstep(0.18, 0.0,
        abs(uv.x - fract(ubuf.time * 0.08) * 1.4 + 0.2));
    movingBand *= smoothstep(1.0, 0.4, uv.y) * 0.07;

    // edge color dispersion
    vec3 edgeColor = vec3(0.72 + uv.x * 0.16, 0.86, 1.0 - uv.x * 0.10);

    vec3 color = vec3(1.0);

    float alpha = topHighlight + mouseGlow + movingBand;
    alpha = max(alpha, 0.08);  // base visibility

    color = mix(color, edgeColor, innerEdge * 0.55);
    alpha += innerEdge * 0.20;

    alpha *= mask * ubuf.qt_Opacity;

    // Qt Quick uses premultiplied alpha
    fragColor = vec4(color * alpha, alpha);
}
