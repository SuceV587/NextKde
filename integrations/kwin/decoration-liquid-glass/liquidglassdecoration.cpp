#include "liquidglassdecoration.h"

#include "appearanceconfig.h"
#include "trafficlightbutton.h"

#include <KDecoration3/DecoratedWindow>
#include <KDecoration3/DecorationButtonGroup>
#include <KDecoration3/DecorationSettings>
#include <KDecoration3/ScaleHelpers>

#include <QFontMetricsF>
#include <QLinearGradient>
#include <QPainter>
#include <QPainterPath>

#include <algorithm>

namespace KOS
{

namespace
{
// Logical pixels. These are the macOS proportions; KWin scales them per output.
constexpr qreal TitleBarHeight = 34.0;
constexpr qreal CornerRadius = 10.0;
// macOS uses 12px lights in a 28px title bar. This bar is taller, so the row
// is scaled to match rather than left looking undersized in it.
constexpr qreal ButtonDiameter = 15.0;
constexpr qreal ButtonSpacing = 9.0;
constexpr qreal ButtonsLeftMargin = 20.0;
// The window has no visible side or bottom frame, so resizing relies entirely
// on this invisible grab margin.
constexpr qreal ResizeGrab = 4.0;
// Below this relative luminance the colour scheme is treated as dark, which
// flips the specular highlight and hairline strengths.
constexpr qreal DarkLuminanceThreshold = 0.45;
// The title bar tint is fixed on purpose, and is the one place here that does
// not follow the shell's glass sliders.
//
// The Dock and the Bar sit at roughly four percent tint, which works because
// each is a single fixed strip the eye already knows the position of. A title
// bar is a window's handle: at that tint the boundary between one window and
// the next stops reading, and picking a window out of a stack becomes work.
// Legibility wins over matching the material exactly.
constexpr qreal ActiveTintAlpha = 0.74;
constexpr qreal InactiveTintAlpha = 0.58;
}

LiquidGlassDecoration::LiquidGlassDecoration(QObject *parent, const QVariantList &args)
    : KDecoration3::Decoration(parent, args)
{
}

LiquidGlassDecoration::~LiquidGlassDecoration() = default;

bool LiquidGlassDecoration::init()
{
    auto *client = window();
    if (!client) {
        return false;
    }

    createButtons();
    updateLayout();

    // Geometry-affecting changes.
    connect(client, &KDecoration3::DecoratedWindow::maximizedChanged,
            this, &LiquidGlassDecoration::updateLayout);
    connect(client, &KDecoration3::DecoratedWindow::shadedChanged,
            this, &LiquidGlassDecoration::updateLayout);
    connect(client, &KDecoration3::DecoratedWindow::widthChanged,
            this, &LiquidGlassDecoration::updateLayout);
    connect(client, &KDecoration3::DecoratedWindow::heightChanged,
            this, &LiquidGlassDecoration::updateLayout);
    connect(client, &KDecoration3::DecoratedWindow::scaleChanged,
            this, &LiquidGlassDecoration::updateLayout);
    // The borders are snapped against nextScale(), so a pending scale change
    // has to re-run the layout even before it becomes current.
    connect(client, &KDecoration3::DecoratedWindow::nextScaleChanged,
            this, &LiquidGlassDecoration::updateLayout);

    // setBorders() only reaches borders() once the compositor applies the next
    // state, so the title bar rect, blur region and button geometry are
    // refreshed from the applied value rather than from the requested one.
    connect(this, &KDecoration3::Decoration::bordersChanged,
            this, &LiquidGlassDecoration::updateDerivedGeometry);

    // Repaint-only changes. Activation also re-tints the lights, so the whole
    // title bar is invalidated rather than just the caption.
    connect(client, &KDecoration3::DecoratedWindow::activeChanged,
            this, qOverload<>(&LiquidGlassDecoration::update));
    connect(client, &KDecoration3::DecoratedWindow::paletteChanged,
            this, qOverload<>(&LiquidGlassDecoration::update));
    connect(client, &KDecoration3::DecoratedWindow::captionChanged,
            this, qOverload<>(&LiquidGlassDecoration::update));

    if (auto config = settings()) {
        connect(config.get(), &KDecoration3::DecorationSettings::fontChanged,
                this, &LiquidGlassDecoration::updateLayout);
    }

    // Moving the glass sliders in the shell restyles open windows immediately,
    // the same as it does the Dock and the Bar.
    connect(&AppearanceConfig::instance(), &AppearanceConfig::changed,
            this, qOverload<>(&LiquidGlassDecoration::update));

    return true;
}

void LiquidGlassDecoration::createButtons()
{
    // Built by hand rather than from settings()->decorationButtonsLeft(): the
    // row is deliberately fixed to close/minimize/zoom on the left, which is
    // the whole point of this decoration. A user-ordered or right-hand row
    // would not read as macOS.
    m_trafficLights = new KDecoration3::DecorationButtonGroup(this);
    m_trafficLights->setSpacing(ButtonSpacing);

    const auto types = {
        KDecoration3::DecorationButtonType::Close,
        KDecoration3::DecorationButtonType::Minimize,
        KDecoration3::DecorationButtonType::Maximize,
    };

    for (auto type : types) {
        auto *button = new TrafficLightButton(type, this, m_trafficLights);
        button->setGeometry(QRectF(0, 0, ButtonDiameter, ButtonDiameter));
        m_trafficLights->addButton(button);
        // Any light changing hover state reveals or hides all three glyphs, so
        // the whole row is invalidated rather than just the button under the
        // pointer.
        connect(button, &KDecoration3::DecorationButton::hoveredChanged, this, [this] {
            update(m_trafficLights->geometry());
        });
    }
}

void LiquidGlassDecoration::updateLayout()
{
    auto *client = window();
    if (!client) {
        return;
    }

    const bool maximized = client->isMaximized();

    // Borders must land on whole device pixels. Under fractional scaling they
    // otherwise do not: 34 logical px at scale 1.25 is 42.5 device px, and the
    // half pixel left between the title bar and the client surface shows the
    // desktop through as a seam. These are the buffered properties, so they
    // are snapped against the scale they will be applied with, not the current
    // one.
    const qreal scale = client->nextScale();
    const auto snap = [scale](qreal value) {
        return KDecoration3::snapToPixelGrid(value, scale);
    };

    // No visible side or bottom frame in either state; a maximized window also
    // drops the rounded corners and the outline, as its edges meet the screen.
    setBorders(QMarginsF(0, client->isShaded() ? 0 : snap(TitleBarHeight), 0, 0));
    setResizeOnlyBorders(maximized
        ? QMarginsF(0, 0, 0, 0)
        : QMarginsF(snap(ResizeGrab), 0, snap(ResizeGrab), snap(ResizeGrab)));

    const KDecoration3::BorderRadius radius = maximized
        ? KDecoration3::BorderRadius(0)
        : KDecoration3::BorderRadius(snap(CornerRadius));
    setBorderRadius(radius);
    setBorderOutline(maximized
        ? KDecoration3::BorderOutline()
        : KDecoration3::BorderOutline(KDecoration3::pixelSize(scale),
                                      outlineColor(), radius));

    // Runs again on bordersChanged() when the new borders are actually
    // applied; calling it here as well covers the changes that move nothing
    // buffered, such as the window being resized.
    updateDerivedGeometry();
}

void LiquidGlassDecoration::updateDerivedGeometry()
{
    if (!window()) {
        return;
    }

    setTitleBar(QRectF(0, 0, size().width(), borderTop()));
    updateTrafficLightPosition();
    updateBlurRegion();
    update();
}

void LiquidGlassDecoration::updateBlurRegion()
{
    // Only the title bar strip is published. The compositor's glass effect
    // intersects this with (decoration rect - client rect) anyway, but being
    // explicit keeps the client area out of the blur region even if the
    // borders ever grow.
    const qreal top = borderTop();
    if (top <= 0.0) {
        setBlurRegion(QRegion());
        return;
    }
    setBlurRegion(QRegion(QRectF(0, 0, size().width(), top).toAlignedRect()));
}

void LiquidGlassDecoration::updateTrafficLightPosition()
{
    auto *client = window();
    if (!client || !m_trafficLights) {
        return;
    }

    // The group derives its own size from the buttons and the spacing; only
    // its top-left corner has to be placed.
    const qreal scale = std::max(1.0, client->scale());
    const qreal top = borderTop();
    const qreal y = KDecoration3::snapToPixelGrid((top - ButtonDiameter) / 2.0, scale);
    m_trafficLights->setPos(
        KDecoration3::snapToPixelGrid(QPointF(ButtonsLeftMargin, y), scale));
}

bool LiquidGlassDecoration::trafficLightsHovered() const
{
    if (!m_trafficLights) {
        return false;
    }
    const auto lights = m_trafficLights->buttons();
    return std::any_of(lights.cbegin(), lights.cend(),
                       [](const KDecoration3::DecorationButton *light) {
                           return light && light->isHovered();
                       });
}

QColor LiquidGlassDecoration::baseColor() const
{
    auto *client = window();
    if (!client) {
        return QColor(0x2b, 0x2f, 0x36);
    }
    return client->palette().color(QPalette::Window);
}

bool LiquidGlassDecoration::isDark() const
{
    const QColor base = baseColor();
    const qreal luminance =
        0.2126 * base.redF() + 0.7152 * base.greenF() + 0.0722 * base.blueF();
    return luminance < DarkLuminanceThreshold;
}

QColor LiquidGlassDecoration::titleBarTint() const
{
    auto *client = window();
    const bool active = client && client->isActive();

    // The window's own palette, so the bar reads as part of the application
    // rather than as a neutral pane floating over it. That difference between
    // one window and the next is itself part of telling them apart.
    QColor tint = baseColor();
    tint.setAlphaF(active ? ActiveTintAlpha : InactiveTintAlpha);
    return tint;
}

QColor LiquidGlassDecoration::hairlineColor() const
{
    return isDark() ? QColor(255, 255, 255, 41) : QColor(20, 26, 41, 41);
}

QColor LiquidGlassDecoration::outlineColor() const
{
    // Measured: KWin renders BorderOutline with the alpha channel ignored, so
    // handing it the translucent hairlineColor() painted a pure white 1px
    // frame around every window. These are the blended results picked as
    // opaque values instead.
    return isDark() ? QColor(88, 94, 104) : QColor(168, 173, 183);
}

QColor LiquidGlassDecoration::captionColor() const
{
    auto *client = window();
    if (!client) {
        return Qt::white;
    }
    QColor text = client->palette().color(QPalette::WindowText);
    if (!client->isActive()) {
        text.setAlphaF(0.55);
    }
    return text;
}

void LiquidGlassDecoration::paintTitleBar(QPainter *painter)
{
    auto *client = window();
    const qreal top = borderTop();
    const QRectF bar(0, 0, size().width(), top);
    if (bar.isEmpty()) {
        return;
    }

    const bool maximized = client && client->isMaximized();
    const bool dark = isDark();
    const qreal scale = client ? std::max(1.0, client->scale()) : 1.0;
    const qreal hairline = KDecoration3::pixelSize(scale);
    // Snapped the same way as the radius handed to KWin in updateLayout(), so
    // the painted top corners follow the corners KWin actually clips.
    const qreal radius = maximized
        ? 0.0
        : KDecoration3::snapToPixelGrid(CornerRadius, scale);

    // The fill runs one device pixel past the bottom of the title bar. An
    // antialiased edge landing exactly on the boundary leaves a partly
    // transparent row there, which reads as a seam against the client surface;
    // overshooting puts that row underneath the client instead, where the
    // decoration is never composited.
    const QRectF fill = bar.adjusted(0, 0, 0, hairline);

    // Only the top corners are rounded here. The bottom of the strip meets the
    // client area square; the window's own bottom corners are rounded by KWin
    // from the border radius set in updateLayout(), which is the only thing
    // that can clip the client's opaque content.
    QPainterPath path;
    if (radius > 0.0) {
        path.moveTo(fill.left(), fill.bottom());
        path.lineTo(fill.left(), fill.top() + radius);
        path.quadTo(fill.left(), fill.top(), fill.left() + radius, fill.top());
        path.lineTo(fill.right() - radius, fill.top());
        path.quadTo(fill.right(), fill.top(), fill.right(), fill.top() + radius);
        path.lineTo(fill.right(), fill.bottom());
        path.closeSubpath();
    } else {
        path.addRect(fill);
    }

    // No clip path here either: drawPath already fills exactly this shape, and
    // an extra antialiased clip along the same edges only risks shaving
    // coverage off the boundary rows the way the repaintArea clip did.
    painter->save();
    painter->setPen(Qt::NoPen);
    painter->setBrush(titleBarTint());
    painter->drawPath(path);

    // Soft top-down specular highlight. Anchored to the title bar rather than
    // to the overshooting fill so the gradient still ends at the visible edge.
    //
    // It fades to fully transparent rather than to a black wash. Tinting the
    // bottom dark left the last rows of the title bar darker than the client
    // area below it, and that band terminating in a step is what reads as a
    // seam between the decoration and the window.
    // Scaled by the shell's liquid slider, the same multiplier its own
    // reflection layers use, so the two materials stay in step.
    const qreal liquid = AppearanceConfig::instance().liquidStrength();
    const auto reflection = [liquid](int alpha) {
        return QColor(255, 255, 255, qRound(alpha * liquid));
    };
    QLinearGradient specular(bar.topLeft(), bar.bottomLeft());
    specular.setColorAt(0.0, reflection(dark ? 31 : 107));
    specular.setColorAt(0.45, reflection(dark ? 10 : 31));
    specular.setColorAt(1.0, QColor(255, 255, 255, 0));
    painter->setBrush(specular);
    painter->drawPath(path);

    // Seal the bottom edge to fully opaque over the last few device pixels.
    //
    // Under fractional scaling a window can land on a half device pixel, and
    // then the boundary row is only partly covered by the decoration. While
    // the title bar is translucent there, that partial coverage lets the
    // desktop show through as a one pixel seam -- the colour of it tracks
    // whatever is behind the window, which is how it was identified. Breeze
    // never shows it because its title bar is opaque, so the same partial
    // coverage merely blends two opaque colours.
    //
    // The seal is proportional to how solid the glass already is, never a flat
    // opaque band: at the shell's default blur strength the title bar is only
    // a few percent opaque, and sealing that to 100% would replace the seam
    // with a hard line of its own. Thin glass therefore gets a correspondingly
    // gentle seal and keeps a fainter seam.
    const qreal sealHeight = std::min(bar.height(), 3.0 * hairline);
    QLinearGradient seal(QPointF(0, bar.bottom() - sealHeight),
                         QPointF(0, bar.bottom()));
    QColor sealColor = baseColor();
    const qreal sealTarget = qBound(0.0, titleBarTint().alphaF() * 3.0, 1.0);
    sealColor.setAlphaF(0.0);
    seal.setColorAt(0.0, sealColor);
    sealColor.setAlphaF(sealTarget);
    seal.setColorAt(1.0, sealColor);
    painter->setBrush(seal);
    painter->drawPath(path);

    painter->restore();

    // Neither edge of the title bar gets a hairline of its own.
    //
    // The top used to carry an inset glass bevel, but it sits one device pixel
    // below the window outline KWin draws, so the two read as two separate
    // lines stacked at the window edge. The soft top stop of the gradient
    // above already implies the bevel without drawing an edge.
    //
    // The bottom is left bare because macOS runs the title bar into the
    // content as one continuous surface, and a hairline there reads as a crack
    // between the decoration and the client.
}

void LiquidGlassDecoration::paintCaption(QPainter *painter)
{
    auto *client = window();
    auto config = settings();
    if (!client || !config) {
        return;
    }

    const QString caption = client->caption();
    if (caption.isEmpty()) {
        return;
    }

    // Centred on the window, macOS-style. The available width is reserved
    // symmetrically around the centre so a long title elides instead of
    // sliding under the traffic lights.
    const qreal reserved = m_trafficLights ? m_trafficLights->geometry().right()
                                           : ButtonsLeftMargin;
    const qreal margin = reserved + ButtonSpacing;
    const qreal available = size().width() - 2.0 * margin;
    if (available <= 0.0) {
        return;
    }

    const QRectF bar(margin, 0, available, borderTop());
    const QFontMetricsF metrics(config->font());
    const QString elided = metrics.elidedText(caption, Qt::ElideMiddle, available);

    painter->save();
    painter->setFont(config->font());
    painter->setPen(captionColor());
    painter->drawText(bar, Qt::AlignCenter | Qt::TextSingleLine, elided);
    painter->restore();
}

void LiquidGlassDecoration::paint(QPainter *painter, const QRectF &repaintArea)
{
    if (!window() || size().isEmpty()) {
        return;
    }

    // repaintArea is deliberately not used as a clip. KWin hands it over in
    // whole logical pixels, so under fractional scaling its bottom edge lands
    // mid-pixel: 34 logical at scale 1.25 is 42.5 device px, and clipping an
    // antialiasing painter there leaves the title bar's last device row at
    // half coverage -- a one pixel line of the desktop showing through
    // between the title bar and the client. The compositor already limits
    // what it takes from this painter, so the clip only did harm.
    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, true);

    paintTitleBar(painter);
    paintCaption(painter);
    if (m_trafficLights) {
        m_trafficLights->paint(painter, repaintArea);
    }

    painter->restore();
}

} // namespace KOS
