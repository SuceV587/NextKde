vec4 processSample(sampler2D tex, vec2 baseUv, vec3 glassNormal, float ior,
    float dispersion, float magnitude, vec2 uvScale, vec2 lensShift,
    out float backdropComplexity)
{
    vec3 viewRay = vec3(0.0, 0.0, -1.0);

    vec3 refractG = refract(viewRay, glassNormal, 1.0 / ior);
    vec2 dir = length(refractG.xy) > 0.001 ? normalize(refractG.xy) : vec2(0.0);
    vec2 shiftG = dir * magnitude * uvScale + lensShift;
    vec4 sampleG = texture(tex, clamp(baseUv + shiftG, 0.0, 1.0));

    // Measure complexity in refracted-coordinate space. Four shared probes
    // are enough to detect text and dense texture; unlike sampling around the
    // original UV, their low-frequency correction cannot undo lens motion.
    vec2 diffusionTap = halfpixel * 8.0;
    vec3 probeXPos = texture(tex, clamp(baseUv + shiftG
        + vec2(diffusionTap.x, 0.0), 0.0, 1.0)).rgb;
    vec3 probeXNeg = texture(tex, clamp(baseUv + shiftG
        - vec2(diffusionTap.x, 0.0), 0.0, 1.0)).rgb;
    vec3 probeYPos = texture(tex, clamp(baseUv + shiftG
        + vec2(0.0, diffusionTap.y), 0.0, 1.0)).rgb;
    vec3 probeYNeg = texture(tex, clamp(baseUv + shiftG
        - vec2(0.0, diffusionTap.y), 0.0, 1.0)).rgb;
    const vec3 lumaWeights = vec3(0.299, 0.587, 0.114);
    float centreLuma = dot(sampleG.rgb, lumaWeights);
    float minLuma = min(centreLuma, min(min(dot(probeXPos, lumaWeights),
        dot(probeXNeg, lumaWeights)), min(dot(probeYPos, lumaWeights),
        dot(probeYNeg, lumaWeights))));
    float maxLuma = max(centreLuma, max(max(dot(probeXPos, lumaWeights),
        dot(probeXNeg, lumaWeights)), max(dot(probeYPos, lumaWeights),
        dot(probeYNeg, lumaWeights))));
    float complexity = smoothstep(0.075, 0.24, maxLuma - minLuma);
    backdropComplexity = complexity;
    if (dispersion > 0.001) {
        // Preserve spectral separation on gradients, but keep hard saturated
        // boundaries from turning into red/cyan contour smears that overpower
        // the neutral reflection glint.
        float fringe = clamp(dispersion, 0.0, 1.0) * 0.3
            * mix(1.0, 0.35, complexity);
        vec2 shiftR = dir * (magnitude * (1.0 + fringe)) * uvScale + lensShift;
        vec2 shiftB = dir * (magnitude * (1.0 - fringe)) * uvScale + lensShift;

        float r = texture(tex, clamp(baseUv + shiftR, 0.0, 1.0)).r;
        float b = texture(tex, clamp(baseUv + shiftB, 0.0, 1.0)).b;
        return vec4(
            r,
            sampleG.g,
            b,
            sampleG.a
        );
    }
    return sampleG;
}

GlassFragment snellsRefraction(vec2 position, vec2 halfBlurSize, vec4 cornerRadius, float minHalfSize, float dist, float edgeFactor, float concaveFactor)
{
    float bandWidth = clamp(edgeSizePixels, 0.1, minHalfSize * 0.9);
    float ior = 1.0 + refractionStrength;

    float minR = min(min(cornerRadius.x, cornerRadius.y), min(cornerRadius.z, cornerRadius.w));
    float eps = min(bandWidth * 0.75, minR * 0.6);
    float dxp = roundedRectangleDist(position + vec2(eps, 0.0), halfBlurSize, cornerRadius);
    float dxn = roundedRectangleDist(position - vec2(eps, 0.0), halfBlurSize, cornerRadius);
    float dyp = roundedRectangleDist(position + vec2(0.0, eps), halfBlurSize, cornerRadius);
    float dyn = roundedRectangleDist(position - vec2(0.0, eps), halfBlurSize, cornerRadius);
    vec2 smoothGrad = vec2(dxp - dxn, dyp - dyn);
    float gradLen = length(smoothGrad);
    
    // A steeper inner falloff keeps the outer Snell rim fully expressive but
    // calms displacement sooner toward text-bearing interior pixels.
    float opticalProfile = pow(concaveFactor, 1.35);
    float normalHeight = opticalProfile * refractionBevelIntensity;
    vec2 normalXY = gradLen > 0.001 ? (smoothGrad / gradLen) * normalHeight : vec2(0.0);
    vec3 glassNormal = normalize(vec3(normalXY, 1.0));

    // Large shell panels should not displace the backdrop as aggressively as
    // a Dock-height lens. Without this size response, isolated shapes are
    // stretched through a 50 px band and look like grime under the glass.
    // Dock-sized surfaces (<= 160 px) retain the configured optical strength.
    float surfaceHeight = minHalfSize * 2.0;
    float largeSurfaceAttenuation = mix(1.0, 0.42,
        smoothstep(160.0, 480.0, surfaceHeight));
    float lensMagnitude = opticalProfile * bandWidth
        * refractionBevelIntensity * largeSurfaceAttenuation;
    vec2 surfaceNormal = gradLen > 0.001 ? smoothGrad / gradLen : vec2(1.0, 0.0);

    vec2 normalizedPos = position / blurSize;
    float cornerWeight = dot(normalizedPos, normalizedPos) * refractionOffsetStrength;
    surfaceNormal += normalizedPos * opticalProfile * cornerWeight;

    vec2 uvScale = 1.0 / blurSize;
    vec2 lensShift = -surfaceNormal * lensMagnitude * uvScale;

    float refractionMagnitude = lensMagnitude * refractionStrength;
    float backdropComplexity = 0.0;
    vec4 color = processSample(texUnit, uv, glassNormal, ior,
        refractionRGBFringing, refractionMagnitude, uvScale, lensShift,
        backdropComplexity);

    return GlassFragment(color, dist, edgeFactor, concaveFactor, glassNormal,
        ior, backdropComplexity);
}
