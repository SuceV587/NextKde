#pragma once

#include <QStringList>

namespace KWin
{

QStringList parseWindowClasses(const QString &input);

enum class WindowClassMatchingMode
{
    Blacklist,
    Whitelist
};


struct GeneralSettings
{
    int blurStrength;
    int noiseStrength;
    int decorationBlurStrength;
    int decorationNoiseStrength;
    int dockBlurStrength;
    int dockNoiseStrength;
    float brightness;
    float saturation;
    float contrast;
    bool oklabSaturation;
    float blurRadius;
    float upsampleOffset;
    bool saturationCompensation;
    QString tintColor;
    bool autoTintAlpha;
    QString glowColor;
    bool edgeLighting;
    bool edgeLightingDock;
    bool edgeLightingTooltip;
    bool excludeDocks;
    bool excludeDecorations;
    bool excludeTooltips;
    bool excludeMenus;
    bool excludeOSD;
};

struct ForceBlurSettings
{
    // Quickshell surfaces often contain several independently rounded blur
    // regions.  Restricting the effect to them avoids changing the rendering
    // or corner geometry of normal application windows.
    bool onlyQuickshell;
    QStringList windowClasses;
    WindowClassMatchingMode windowClassMatchingMode;
    bool blurDecorations;
    bool blurMenus;
    bool blurDocks;
    // Layer-shell clients such as Quickshell may create a background-effect
    // object without declaring a region. Treating that empty region as the
    // entire dock makes transparent panels receive the glass shader.
    bool skipEmptyDockBlurRegions;
};

struct RoundedCornersSettings
{
    float windowTopRadius;
    float windowBottomRadius;
    float menuRadius;
    float dockRadius;
    bool useDeclaredCornerRadius;
    bool ignoreContentBlurRegion;
    bool roundMaximized;
    bool dynamicCorners;
    bool dynamicCornersExcludeWindows;
    bool dynamicCornersExcludeDocks;
    bool dynamicCornersExcludeTooltips;
    bool dynamicCornersExcludeMenus;
};

struct RefractionSettings
{
    float edgeSizePixels;
    float refractionStrength;
    float refractionNormalPow;
    float refractionRGBFringing;
    float refractionOffsetStrength;
    float refractionBevelIntensity;
    float highlightWidthPx;
    float highlightAngle;  // degrees, light direction for the focused highlight
    bool physicallyBased;
};

struct BionicSettings
{
    bool enabled;
    float lumValue0;
    float lumValue1;
    float lumValue2;
    float lumValue3;
    float lumAmount;
    float brightness;
    float darker;
    float darkerRange0;
    float darkerRange1;
    float innerBottom;
    float innerColorWhite;
    float innerColorMix;
    float colorPow;
    float alpha;
    float overallAlpha;
    float shapeEdgePx;
    float shapeEdgePow;
    float shapeThicknessPx;
    float shapeReflectOffsetPx;
    float reflLighten;
    float reflStrength;
    float dirX;
    float dirY;
    float dirZ;
    float dirIntensity;
    float dirOppositeIntensity;
    float dirAngleRange;
    float dirEdgePow;
    int blur;
    float ior;
    float bgColorSaturation;
    float bgColorBrightness;
    float hsvvBoost;
    float darkerActivated;
    float dirIntensityActivated;
    float dirOppositeIntensityActivated;
    float colorPowActivated;
};

struct ClassicSettings
{
    bool enabled;
    QString dark0;
    QString dark1;
    QString dark2;
    QString light0;
    QString light1;
    QString light2;
    float strokeSize;
    float strokeStrength;
    float strokeDegree;
    float refractIOR;
    float reflLighten;
    float reflStrength;
    float maskSoft;
};

class BlurSettings
{
public:
    GeneralSettings general{};
    ForceBlurSettings forceBlur{};
    RoundedCornersSettings roundedCorners{};
    RefractionSettings refraction{};
    BionicSettings bionic{};
    ClassicSettings classic{};

    void read();
};

}
