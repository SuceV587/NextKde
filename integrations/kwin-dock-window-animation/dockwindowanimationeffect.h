#pragma once

#include <effect/effectwindow.h>
#include <effect/offscreeneffect.h>
#include <effect/timeline.h>

#include <QHash>
#include <QList>
#include <QRectF>
#include <QString>
#include <QStringList>

namespace KWin
{

class DockWindowAnimationEffect final : public OffscreenEffect
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kos.KWin.DockWindowAnimation")

public:
    DockWindowAnimationEffect();
    ~DockWindowAnimationEffect() override;

    void reconfigure(ReconfigureFlags flags) override;
    void prePaintScreen(ScreenPrePaintData &data) override;
    void prePaintWindow(RenderView *view, EffectWindow *window,
                        WindowPrePaintData &data) override;
    void postPaintScreen() override;
    bool isActive() const override;

    int requestedEffectChainPosition() const override
    {
        return 50;
    }

    static bool supported();

public Q_SLOTS:
    void updateTargets(const QString &payload);
    bool prepareLaunch(const QString &payload);
    QString status() const;

Q_SIGNALS:
    void animationStarted(const QString &appId, const QString &windowId,
                          const QString &transition, int durationMs);

protected:
    void drawWindow(const RenderTarget &renderTarget,
                    const RenderViewport &viewport, EffectWindow *window,
                    int mask, const Region &deviceRegion,
                    WindowPaintData &data) override;
    void apply(EffectWindow *window, int mask, WindowPaintData &data,
               WindowQuadList &quads) override;

private:
    enum class Transition {
        Open,
        Minimize,
        Restore,
    };

    struct Target {
        QString appId;
        QString windowId;
        QRectF geometry;
    };

    struct WindowAnimation {
        EffectWindowVisibleRef visibleRef;
        TimeLine timeLine;
        Target target;
        Transition transition = Transition::Minimize;
    };

    struct PendingLaunch {
        Target target;
        QStringList aliases;
        qint64 expiresAt = 0;
    };

    void handleWindowAdded(EffectWindow *window);
    void watchWindow(EffectWindow *window);
    void tryStartTicketedOpenAnimation(EffectWindow *window,
                                       int remainingAttempts);
    void handleMinimizedChanged(EffectWindow *window);
    void handleWindowDeleted(EffectWindow *window);
    bool eligibleWindow(EffectWindow *window) const;
    bool claim(EffectWindow *window, int role);
    void releaseClaim(EffectWindow *window);
    void finishAnimation(EffectWindow *window);
    void startAnimation(EffectWindow *window, const Target &target,
                        Transition transition);
    void applyDockMorph(EffectWindow *window, const WindowAnimation &animation,
                        WindowQuadList &quads) const;
    std::optional<Target> targetForWindow(EffectWindow *window) const;
    std::optional<Target> takePendingLaunchForWindow(EffectWindow *window);
    QStringList windowIdentityCandidates(EffectWindow *window) const;
    QString normalizedId(const QString &value) const;

    QHash<QString, Target> m_targetsByApp;
    QHash<QString, Target> m_targetsByWindow;
    QList<PendingLaunch> m_pendingLaunches;
    QHash<EffectWindow *, WindowAnimation> m_animations;
    QHash<EffectWindow *, int> m_claimedRoles;

    int m_openDuration = 300;
    int m_minimizeDuration = 300;
    int m_restoreDuration = 200;
    quint64 m_openAnimationCount = 0;
    quint64 m_minimizeAnimationCount = 0;
    quint64 m_restoreAnimationCount = 0;
    quint64 m_launchTicketCount = 0;
    quint64 m_launchTicketConsumedCount = 0;
    QString m_lastAnimatedAppId;
};

} // namespace KWin
