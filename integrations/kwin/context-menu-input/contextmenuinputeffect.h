#pragma once

#include <effect/effect.h>

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

public:
    ContextMenuInputEffect();
    ~ContextMenuInputEffect() override;

private:
    friend class ContextMenuPointerSpy;

    void handlePointerPress(const QPointF &position, Qt::MouseButton button);
    void installPointerSpy();
    void publish(const QJsonObject &eventData);

    std::unique_ptr<ContextMenuPointerSpy> m_pointerSpy;
    bool m_pointerSpyInstalled = false;
};

} // namespace KWin
