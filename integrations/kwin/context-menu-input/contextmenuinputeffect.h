#pragma once

#include <effect/effect.h>
#include <QVariant>

#include <memory>

class QJsonObject;

namespace KWin
{

class ContextMenuPointerSpy;

// Observe KWin's global pointer state and report presses. It never consumes
// or redirects input.
class ContextMenuInputEffect final : public Effect
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kos.KWin.ContextMenuInput")

public:
    ContextMenuInputEffect();
    ~ContextMenuInputEffect() override;

public slots:
    QVariantMap activeApplicationMenu() const;

private:
    friend class ContextMenuPointerSpy;

    void handlePointerPress(const QPointF &position, Qt::MouseButton button);
    void installPointerSpy();
    void publish(const QJsonObject &eventData);

    std::unique_ptr<ContextMenuPointerSpy> m_pointerSpy;
    bool m_pointerSpyInstalled = false;
};

} // namespace KWin
