#include "settings.h"
#include "blurconfig.h"

#include <algorithm>

namespace KWin
{

QStringList parseWindowClasses(const QString &input)
{
    QStringList result;
    const auto blank = QStringLiteral("blank");
    for (const auto &line : input.split("\n", Qt::SkipEmptyParts)) {
        QString unescaped = "";
        bool consumed = false;
        for (qsizetype i = 0; i < line.size(); i++) {
            const auto character = line[i];
            if (character == QChar('$') && !consumed) {
                consumed = true;
                continue;
            }
            if (consumed) {
                const qsizetype skips = blank.size();
                if (line.mid(i, skips) == blank) {
                    consumed = false;
                    i += skips - 1;
                    continue;
                }
            }
            consumed = false;
            unescaped += character;
        }
        if (consumed) {
            unescaped += QChar('$');
        }
        result << unescaped;
    }
    return result;
}

void BlurSettings::read()
{
    BlurConfig::self()->read();

    general.blurStrength = BlurConfig::blurStrength() - 1;
    general.noiseStrength = BlurConfig::noiseStrength();
    general.decorationBlurStrength = BlurConfig::decorationBlurStrength() - 1;
    general.decorationNoiseStrength = BlurConfig::decorationNoiseStrength();
    general.dockBlurStrength = BlurConfig::dockBlurStrength() - 1;
    general.dockNoiseStrength = BlurConfig::dockNoiseStrength();
    general.brightness = BlurConfig::brightness();
    general.saturation = BlurConfig::saturation();
    general.contrast = BlurConfig::contrast();
    general.oklabSaturation = BlurConfig::oklabSaturation();

    const float finetune = 0.5f + std::clamp(BlurConfig::blurFinetune(), 0, 10) * 0.13f;
    general.blurRadius = finetune;
    general.upsampleOffset = finetune;
    general.saturationCompensation = BlurConfig::blurSaturationCompensation();

    general.tintColor = BlurConfig::tintColor();
    general.autoTintAlpha = BlurConfig::autoTintAlpha();
    general.glowColor = BlurConfig::glowColor();
    general.edgeLighting = BlurConfig::edgeLighting();
    general.edgeLightingDock = BlurConfig::edgeLightingDock();
    general.edgeLightingTooltip = BlurConfig::edgeLightingTooltip();
    general.excludeDocks = BlurConfig::excludeDocks();
    general.excludeDecorations = BlurConfig::excludeDecorations();
    general.excludeTooltips = BlurConfig::excludeTooltips();
    general.excludeMenus = BlurConfig::excludeMenus();
    general.excludeOSD = BlurConfig::excludeOSD();

    forceBlur.onlyQuickshell = BlurConfig::onlyQuickshell();
    forceBlur.windowClasses = parseWindowClasses(BlurConfig::windowClasses());
    forceBlur.windowClassMatchingMode = BlurConfig::blurMatching() ? WindowClassMatchingMode::Whitelist : WindowClassMatchingMode::Blacklist;
    forceBlur.blurDecorations = BlurConfig::blurDecorations();
    forceBlur.blurMenus = BlurConfig::blurMenus();
    forceBlur.blurDocks = BlurConfig::blurDocks();
    forceBlur.skipEmptyDockBlurRegions = BlurConfig::skipEmptyDockBlurRegions();

    roundedCorners.windowTopRadius = BlurConfig::topCornerRadius();
    roundedCorners.windowBottomRadius = BlurConfig::bottomCornerRadius();
    roundedCorners.menuRadius = BlurConfig::menuCornerRadius();
    roundedCorners.dockRadius = BlurConfig::dockCornerRadius();
    roundedCorners.useDeclaredCornerRadius = BlurConfig::useDeclaredCornerRadius();
    roundedCorners.ignoreContentBlurRegion = BlurConfig::ignoreContentBlurRegion();
    roundedCorners.roundMaximized = BlurConfig::roundCornersOfMaximizedWindows();
    roundedCorners.dynamicCorners = BlurConfig::dynamicCorners();
    roundedCorners.dynamicCornersExcludeWindows = BlurConfig::dynamicCornersExcludeWindows();
    roundedCorners.dynamicCornersExcludeDocks = BlurConfig::dynamicCornersExcludeDocks();
    roundedCorners.dynamicCornersExcludeTooltips = BlurConfig::dynamicCornersExcludeTooltips();
    roundedCorners.dynamicCornersExcludeMenus = BlurConfig::dynamicCornersExcludeMenus();

    refraction.edgeSizePixels = BlurConfig::refractionEdgeSize() * 10;
    refraction.highlightWidthPx = BlurConfig::highlightWidthPx();
    refraction.highlightAngle = BlurConfig::highlightAngle();
    refraction.refractionStrength = BlurConfig::refractionStrength() / 20.0;
    refraction.refractionNormalPow = BlurConfig::refractionNormalPow() / 2.0;
    refraction.refractionRGBFringing = BlurConfig::refractionRGBFringing() / 20.0;
    refraction.refractionOffsetStrength = BlurConfig::refractionOffsetStrength() / 2.0;
    refraction.refractionBevelIntensity = BlurConfig::refractionBevelIntensity() / 10.0;
    refraction.physicallyBased = BlurConfig::physicallyBasedRefraction();

    bionic.enabled = BlurConfig::bionicMode();
    bionic.lumValue0 = BlurConfig::bionicLumValue0();
    bionic.lumValue1 = BlurConfig::bionicLumValue1();
    bionic.lumValue2 = BlurConfig::bionicLumValue2();
    bionic.lumValue3 = BlurConfig::bionicLumValue3();
    bionic.lumAmount = BlurConfig::bionicLumAmount();
    bionic.brightness = BlurConfig::bionicBrightness();
    bionic.darker = BlurConfig::bionicDarker();
    bionic.darkerRange0 = BlurConfig::bionicDarkerRange0();
    bionic.darkerRange1 = BlurConfig::bionicDarkerRange1();
    bionic.innerBottom = BlurConfig::bionicInnerBottom();
    bionic.innerColorWhite = BlurConfig::bionicInnerColorWhite();
    bionic.innerColorMix = BlurConfig::bionicInnerColorMix();
    bionic.colorPow = BlurConfig::bionicColorPow();
    bionic.alpha = BlurConfig::bionicAlpha();
    bionic.overallAlpha = BlurConfig::bionicOverallAlpha();
    bionic.shapeEdgePx = BlurConfig::bionicShapeEdgePx();
    bionic.shapeEdgePow = BlurConfig::bionicShapeEdgePow();
    bionic.shapeThicknessPx = BlurConfig::bionicShapeThicknessPx();
    bionic.shapeReflectOffsetPx = BlurConfig::bionicShapeReflectOffsetPx();
    bionic.reflLighten = BlurConfig::bionicReflLighten();
    bionic.reflStrength = BlurConfig::bionicReflStrength();
    bionic.dirX = BlurConfig::bionicDirX();
    bionic.dirY = BlurConfig::bionicDirY();
    bionic.dirZ = BlurConfig::bionicDirZ();
    bionic.dirIntensity = BlurConfig::bionicDirIntensity();
    bionic.dirOppositeIntensity = BlurConfig::bionicDirOppositeIntensity();
    bionic.dirAngleRange = BlurConfig::bionicDirAngleRange();
    bionic.dirEdgePow = BlurConfig::bionicDirEdgePow();
    bionic.blur = BlurConfig::bionicBlur();
    bionic.ior = BlurConfig::bionicIOR();
    bionic.bgColorSaturation = BlurConfig::bionicBgColorSaturation();
    bionic.bgColorBrightness = BlurConfig::bionicBgColorBrightness();
    bionic.hsvvBoost = BlurConfig::bionicHsvvBoost();
    bionic.darkerActivated = BlurConfig::bionicActivatedDarker();
    bionic.dirIntensityActivated = BlurConfig::bionicActivatedDirIntensity();
    bionic.dirOppositeIntensityActivated = BlurConfig::bionicActivatedDirOppositeIntensity();
    bionic.colorPowActivated = BlurConfig::bionicActivatedColorPow();
    bionic.hsvvBoostActivated = BlurConfig::bionicActivatedHsvvBoost();
    bionic.reflStrengthActivated = BlurConfig::bionicActivatedReflStrength();
    bionic.refractActivated = BlurConfig::bionicActivatedRefract();

    classic.enabled = BlurConfig::classicMode();
    classic.dark0 = BlurConfig::classicDark0();
    classic.dark1 = BlurConfig::classicDark1();
    classic.dark2 = BlurConfig::classicDark2();
    classic.light0 = BlurConfig::classicLight0();
    classic.light1 = BlurConfig::classicLight1();
    classic.light2 = BlurConfig::classicLight2();
    classic.strokeSize = BlurConfig::classicStrokeSize();
    classic.strokeStrength = BlurConfig::classicStrokeStrength();
    classic.strokeDegree = BlurConfig::classicStrokeDegree();
    classic.refractIOR = BlurConfig::classicRefractIOR();
    classic.reflLighten = BlurConfig::classicReflLighten();
    classic.reflStrength = BlurConfig::classicReflStrength();
    classic.maskSoft = BlurConfig::classicMaskSoft();
}

}
