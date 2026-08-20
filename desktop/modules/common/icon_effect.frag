#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float opacityMult;
    float sat;
    float iconTintStrength;
    vec4 iconTintColor;
} ubuf;

void main() {
    vec4 color = texture(source, qt_TexCoord0);

    // 1. Convert to grayscale first
    float lum = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    vec3 gray = vec3(lum);
    vec3 desat = mix(color.rgb, gray, 1.0 - ubuf.sat);

    // 2. Apply color tint: dark -> tint color, bright -> lighter tint/white
    // Softer mapping: dark uses tint color, bright blends toward white
    vec3 tintBase = mix(ubuf.iconTintColor.rgb, vec3(1.0), lum) * lum;
    vec3 glassColor = mix(desat, tintBase, ubuf.iconTintStrength) * color.a;

    // 3. Keep icon shape: solid parts visible, transparent edges more transparent
    // opacityMult controls the final solidity (1.0 = solid, lower = more transparent)
    float shapeAlpha = mix(color.a * 0.25, color.a, color.a);

    float finalAlpha = shapeAlpha * ubuf.opacityMult;

    fragColor = vec4(glassColor, finalAlpha) * ubuf.qt_Opacity;
}
