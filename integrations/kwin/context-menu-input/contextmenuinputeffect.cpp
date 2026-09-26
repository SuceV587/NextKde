#include "contextmenuinputeffect.h"

#include <input.h>
#include <input_event.h>
#include <input_event_spy.h>
#include <keyboard_input.h>
#include <window.h>
#include <workspace.h>
#include <wayland_server.h>
#include <wayland/seat.h>
#include <xkb.h>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDateTime>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>

#include <chrono>
#include <optional>

#include <xkbcommon/xkbcommon-keysyms.h>

namespace KWin
{

// InputEventSpy runs before KWin's input filters, observes every pointer
// button change, and has no return value with which it could consume input.
class ContextMenuPointerSpy final : public InputEventSpy
{
public:
    explicit ContextMenuPointerSpy(ContextMenuInputEffect *effect)
        : m_effect(effect)
    {
    }

    void pointerButton(PointerButtonEvent *event) override
    {
        if (event && event->state == PointerButtonState::Pressed)
            m_effect->handlePointerPress(event->position, event->button);
    }

private:
    ContextMenuInputEffect *m_effect;
};

ContextMenuInputEffect::ContextMenuInputEffect()
{
    QDBusConnection::sessionBus().registerObject(
        QStringLiteral("/KOSContextMenuInput"), this,
        QDBusConnection::ExportAllSlots);
    m_pointerSpy = std::make_unique<ContextMenuPointerSpy>(this);
    installPointerSpy();
}

ContextMenuInputEffect::~ContextMenuInputEffect()
{
    QDBusConnection::sessionBus().unregisterObject(QStringLiteral("/KOSContextMenuInput"));
}

QVariantMap ContextMenuInputEffect::activeApplicationMenu() const
{
    Window *window = Workspace::self() ? Workspace::self()->activeWindow() : nullptr;
    if (!window || !window->hasApplicationMenu())
        return {{QStringLiteral("available"), false}};

    const QString service = window->applicationMenuServiceName();
    const QString path = window->applicationMenuObjectPath();
    return {{QStringLiteral("available"), !service.isEmpty() && !path.isEmpty()},
            {QStringLiteral("service"), service},
            {QStringLiteral("path"), path}};
}

bool ContextMenuInputEffect::paste(const QString &expectedWindowId)
{
    InputRedirection *redirection = input();
    KeyboardInputRedirection *keyboard = redirection ? redirection->keyboard() : nullptr;
    Xkb *xkb = keyboard ? keyboard->xkb() : nullptr;
    Window *target = Workspace::self() ? Workspace::self()->activeWindow() : nullptr;
    SeatInterface *seat = waylandServer() ? waylandServer()->seat() : nullptr;
    // Keyboard focus, rather than activeWindow(), also excludes an intervening
    // layer surface, popup or lock screen. No event loop runs before injection.
    const QUuid expected(expectedWindowId);
    if (expected.isNull() || !target || target->internalId() != expected
            || !target->surface() || !seat
            || seat->focusedKeyboardSurface() != target->surface())
        return false;
    if (!xkb) {
        qWarning() << "KOS paste: keyboard state unavailable; skipping injection";
        return false;
    }

    // Resolve the keycodes on the layout that is active right now. Going
    // through xkb keeps the injected chord identical to a physical press on
    // non-Latin layouts, where the V keysym does not sit where a hardcoded
    // keycode would put it.
    const std::optional<Xkb::KeyCode> control =
        xkb->keycodeFromKeysym(XKB_KEY_Control_L);
    const std::optional<Xkb::KeyCode> letterV = xkb->keycodeFromKeysym(XKB_KEY_v);
    if (!control || !letterV) {
        qWarning() << "KOS paste: Ctrl+V is not reachable on the active layout";
        return false;
    }

    // KWin stamps real input with the monotonic clock. Reusing it keeps key
    // repeat and shortcut handling looking at a plausible sequence instead of
    // an event from before the session started.
    const auto now = std::chrono::duration_cast<std::chrono::microseconds>(
        std::chrono::steady_clock::now().time_since_epoch());

    keyboard->processKey(control->keyCode, KeyboardKeyState::Pressed, now);
    keyboard->processKey(letterV->keyCode, KeyboardKeyState::Pressed, now);
    keyboard->processKey(letterV->keyCode, KeyboardKeyState::Released, now);
    keyboard->processKey(control->keyCode, KeyboardKeyState::Released, now);
    return true;
}

void ContextMenuInputEffect::installPointerSpy()
{
    if (m_pointerSpyInstalled)
        return;

    if (auto *inputRedirection = input()) {
        inputRedirection->installInputEventSpy(m_pointerSpy.get());
        m_pointerSpyInstalled = true;
        return;
    }

    // Effects may be constructed before KWin finishes bringing up input on a
    // compositor restart. Retry on its event loop instead of silently ending
    // up with a permanently inactive effect.
    QTimer::singleShot(100, this, &ContextMenuInputEffect::installPointerSpy);
}

void ContextMenuInputEffect::handlePointerPress(const QPointF &position,
                                                Qt::MouseButton button)
{
    // KWin owns the authoritative surface hit-test. PopupWindow's QML x/y are
    // anchor-local and cannot be compared to compositor-global coordinates.
    // A press delivered to any popup is therefore already an internal menu
    // interaction, not an outside press that should dismiss our menu.
    if (auto *target = input() ? input()->findToplevel(position) : nullptr;
        target && target->isPopupWindow()) {
        return;
    }

    const QJsonObject eventData{
        {QStringLiteral("type"), QStringLiteral("global-pointer-press")},
        {QStringLiteral("x"), position.x()},
        {QStringLiteral("y"), position.y()},
        {QStringLiteral("button"), static_cast<int>(button)},
        {QStringLiteral("timestamp"), QDateTime::currentMSecsSinceEpoch()},
    };
    publish(eventData);
}

void ContextMenuInputEffect::publish(const QJsonObject &eventData)
{
    const QString payload = QString::fromUtf8(QJsonDocument(eventData).toJson(
        QJsonDocument::Compact));

    // WindowService already owns this local session-bus endpoint. send() is a
    // no-reply, non-blocking D-Bus delivery and therefore cannot stall KWin's
    // input thread when Quickshell is restarting.
    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.kos.Platform"),
        QStringLiteral("/Platform"),
        QStringLiteral("org.kos.Platform"),
        QStringLiteral("Publish"));
    message.setArguments({payload});
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (bus.isConnected())
        bus.send(message);
}

} // namespace KWin
