#pragma once

#include <effect/effect.h>
#include <QVariant>

#include <memory>

class QJsonObject;

namespace KWin
{

class ContextMenuPointerSpy;

// Observe KWin's global pointer state and report presses, and own the one
// privileged action the Shell cannot perform itself: synthesising a key event
// for the focused window. Pointer observation never consumes or redirects.
class ContextMenuInputEffect final : public Effect
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kos.KWin.ContextMenuInput")

public:
    ContextMenuInputEffect();
    ~ContextMenuInputEffect() override;

public slots:
    QVariantMap activeApplicationMenu() const;
    // Type Ctrl+V only if the requested window still holds keyboard focus. An effect runs
    // inside KWin, so this needs no uinput device or external helper; the Shell
    // reaches it through kos-platform's input.paste operation.
    bool paste(const QString &expectedWindowId);

private:
    friend class ContextMenuPointerSpy;

    void handlePointerPress(const QPointF &position, Qt::MouseButton button);
    void installPointerSpy();
    void publish(const QJsonObject &eventData);

    std::unique_ptr<ContextMenuPointerSpy> m_pointerSpy;
    bool m_pointerSpyInstalled = false;
};

} // namespace KWin
