#include <QGuiApplication>
#include <QDateTime>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QProcess>
#include <QStandardPaths>
#include <QThread>
#include <QVariantMap>

class SettingsBridge final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit SettingsBridge(QObject *parent = nullptr) : QObject(parent) {}

    QString lastError() const { return m_lastError; }

    Q_INVOKABLE QVariantMap dockSnapshot() {
        return snapshotFromReply(callDock({QStringLiteral("snapshot")}));
    }

    Q_INVOKABLE QVariantMap updateDockLayout(double height) {
        return snapshotFromReply(callDock({QStringLiteral("updateLayout"),
                                           QString::number(height, 'f', 2)}));
    }

    Q_INVOKABLE QVariantMap updateDockPosition(const QString &position) {
        return snapshotFromReply(callDock({QStringLiteral("updatePosition"), position}));
    }

    Q_INVOKABLE QVariantMap updateDockIconMode(const QString &mode) {
        return snapshotFromReply(callDock({QStringLiteral("updateIconMode"), mode}));
    }

    Q_INVOKABLE QVariantMap updateDockIconOpacity(double opacity) {
        return snapshotFromReply(callDock({QStringLiteral("updateIconOpacity"), QString::number(opacity, 'f', 2)}));
    }

    Q_INVOKABLE QVariantMap updateDockIconTintColor(const QString &color) {
        return snapshotFromReply(callDock({QStringLiteral("updateIconTintColor"), color}));
    }

    Q_INVOKABLE QVariantMap updateDockVisibilityMode(const QString &mode) {
        return snapshotFromReply(callDock({QStringLiteral("updateVisibilityMode"), mode}));
    }

    Q_INVOKABLE QVariantMap updateDockWindowGrouping(const QString &mode) {
        return snapshotFromReply(callDock({QStringLiteral("updateWindowGrouping"), mode}));
    }

    Q_INVOKABLE QVariantMap appearanceSnapshot() {
        return appearanceSnapshotFromReply(callAppearance({QStringLiteral("snapshot")}));
    }

    Q_INVOKABLE QVariantMap updateBlurStrength(double strength) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateGlobalBlurStrength"),
            QString::number(strength, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateLiquidStrength(double strength) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateGlobalLiquidStrength"),
            QString::number(strength, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateGlobalBlurStrength(double strength) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateGlobalBlurStrength"),
            QString::number(strength, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateGlobalLiquidStrength(double strength) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateGlobalLiquidStrength"),
            QString::number(strength, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateGlobalIconMode(const QString &mode) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateGlobalIconMode"), mode}));
    }

    Q_INVOKABLE QVariantMap updateGlobalIconOpacity(double opacity) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateGlobalIconOpacity"),
            QString::number(opacity, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateGlobalIconTintColor(const QString &color) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateGlobalIconTintColor"), color}));
    }

    Q_INVOKABLE QVariantMap updateShellStyle(const QString &style) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateShellStyle"), style}));
    }

    Q_INVOKABLE QVariantMap updateMaterialStyle(const QString &style) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateMaterialStyle"), style}));
    }

    Q_INVOKABLE QVariantMap updateBionicRefract(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicRefract"),
            QString::number(value, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateBionicEdgeLight(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicEdgeLight"),
            QString::number(value, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateBionicSoftEdgePx(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicSoftEdgePx"),
            QString::number(value, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateBionicHsvv(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicHsvv"),
            QString::number(value, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateClassicRefract(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateClassicRefract"),
            QString::number(value, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateClassicReflect(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateClassicReflect"),
            QString::number(value, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateClassicEdgeLight(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateClassicEdgeLight"),
            QString::number(value, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateClassicSoftEdgePx(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateClassicSoftEdgePx"),
            QString::number(value, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateBionicTransparency(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicTransparency"),
            QString::number(value, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateBionicActDarken(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicActDarken"),
            QString::number(value, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateBionicActEdgeLight(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicActEdgeLight"),
            QString::number(value, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateBionicActOpposite(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicActOpposite"),
            QString::number(value, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateBionicActHsvv(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicActHsvv"),
            QString::number(value, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateBionicActRefl(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicActRefl"),
            QString::number(value, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateBionicActRefract(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicActRefract"),
            QString::number(value, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateBionicLum0(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicLum0"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicLum1(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicLum1"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicLum2(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicLum2"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicLum3(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicLum3"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicLumAmount(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicLumAmount"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicDarkBase(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicDarkBase"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicDarkRange0(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicDarkRange0"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicDarkRange1(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicDarkRange1"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicBrightBase(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicBrightBase"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicInnerBottom(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicInnerBottom"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicInnerWhite(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicInnerWhite"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicInnerMix(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicInnerMix"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicColorPow(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicColorPow"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicAlphaLayer(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicAlphaLayer"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicShapeEdgePow(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicShapeEdgePow"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicShapeThickness(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicShapeThickness"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicReflectOffset(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicReflectOffset"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicReflLighten(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicReflLighten"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicReflStrength(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicReflStrength"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicDirX(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicDirX"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicDirY(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicDirY"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicDirZ(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicDirZ"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicDirInt(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicDirInt"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicDirOpp(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicDirOpp"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicDirAngle(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicDirAngle"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicDirEdgePow(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicDirEdgePow"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicBgSat(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicBgSat"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicBgBri(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicBgBri"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateBionicActColorPow(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBionicActColorPow"),
            QString::number(value, 'f', 4)}));
    }

    Q_INVOKABLE QVariantMap updateClassicStrokeDegree(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateClassicStrokeDegree"),
            QString::number(value, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateClassicStrokeSize(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateClassicStrokeSize"),
            QString::number(value, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateClassicReflLighten(double value) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateClassicReflLighten"),
            QString::number(value, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap resetMaterialTuning() {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("resetMaterialTuning")}));
    }


    Q_INVOKABLE QVariantMap updateBarIntegratedWithDock(bool enabled) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBarIntegratedWithDock"),
            enabled ? QStringLiteral("true") : QStringLiteral("false")}));
    }

    Q_INVOKABLE QVariantMap updateBarVisibilityMode(const QString &mode) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBarVisibilityMode"), mode}));
    }

    Q_INVOKABLE QVariantMap updateBarLayoutMode(const QString &mode) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBarLayoutMode"), mode}));
    }

    Q_INVOKABLE QVariantMap updateDockWindowAnimationStyle(const QString &style) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateDockWindowAnimationStyle"), style}));
    }

    Q_INVOKABLE QVariantMap resetAppearanceStrengths() {
        return appearanceSnapshotFromReply(callAppearance({QStringLiteral("resetStrengths")}));
    }

    Q_INVOKABLE QVariantMap launcherSnapshot() {
        return launcherSnapshotFromReply(callLauncher({QStringLiteral("snapshot")}));
    }

    Q_INVOKABLE QVariantMap shortcutsSnapshot() {
        return shortcutsSnapshotFromReply(callShortcuts({QStringLiteral("snapshot")}));
    }

    Q_INVOKABLE QVariantMap updateShortcut(const QString &id, const QString &combo) {
        return shortcutsSnapshotFromReply(callShortcuts({QStringLiteral("updateShortcut"),
                                                         id, combo}));
    }

    Q_INVOKABLE QVariantMap resetShortcut(const QString &id) {
        return shortcutsSnapshotFromReply(callShortcuts({QStringLiteral("resetShortcut"), id}));
    }

    Q_INVOKABLE QVariantMap updateLauncherDisplayMode(const QString &mode) {
        return launcherSnapshotFromReply(callLauncher({
            QStringLiteral("updateDisplayMode"), mode}));
    }

    Q_INVOKABLE QVariantMap updateLauncherProfileIconSize(const QString &mode,
                                                           const QString &size) {
        return launcherSnapshotFromReply(callLauncher({
            QStringLiteral("updateProfileIconSize"), mode, size}));
    }

    Q_INVOKABLE QVariantMap updateLauncherProfileDensity(const QString &mode,
                                                          const QString &density) {
        return launcherSnapshotFromReply(callLauncher({
            QStringLiteral("updateProfileDensity"), mode, density}));
    }

    Q_INVOKABLE QVariantMap updateLauncherProfileFontWeight(const QString &mode,
                                                             const QString &weight) {
        return launcherSnapshotFromReply(callLauncher({
            QStringLiteral("updateProfileFontWeight"), mode, weight}));
    }

    Q_INVOKABLE QVariantMap resetLauncherLayoutProfile(const QString &mode) {
        return launcherSnapshotFromReply(callLauncher({
            QStringLiteral("resetProfile"), mode}));
    }

    Q_INVOKABLE bool applySystemAppearance(bool dark) {
        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(
            callAppearance({QStringLiteral("applySystemAppearance"),
                            dark ? QStringLiteral("true") : QStringLiteral("false")})
                .toUtf8(), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject())
            return false;
        const QJsonObject response = document.object();
        const bool accepted = response.value(QStringLiteral("accepted")).toBool();
        if (!accepted && m_lastError.isEmpty())
            setLastError(QStringLiteral("桌面环境拒绝了主题切换请求"));
        return accepted;
    }

    Q_INVOKABLE QVariantMap integrationSnapshot() {
        QVariantMap result = integrationSnapshotFromReply(
            callIntegration({QStringLiteral("snapshot")}));

        const QDBusConnection sessionBus = QDBusConnection::sessionBus();
        auto *busInterface = sessionBus.interface();
        QString notificationProvider = QStringLiteral("none");
        QString notificationOwner;
        uint notificationPid = 0;
        if (busInterface) {
            const QDBusReply<QString> ownerReply = busInterface->serviceOwner(
                QStringLiteral("org.freedesktop.Notifications"));
            if (ownerReply.isValid() && !ownerReply.value().isEmpty()) {
                notificationOwner = ownerReply.value();
                const QDBusReply<uint> pidReply = busInterface->servicePid(notificationOwner);
                if (pidReply.isValid())
                    notificationPid = pidReply.value();

                QFile commandLine(QStringLiteral("/proc/%1/cmdline").arg(notificationPid));
                QString command;
                if (commandLine.open(QIODevice::ReadOnly)) {
                    QByteArray raw = commandLine.readAll();
                    raw.replace('\0', ' ');
                    command = QString::fromLocal8Bit(raw).trimmed();
                }
                if (command.contains(QStringLiteral("plasmashell"))) {
                    notificationProvider = QStringLiteral("plasma");
                } else if (command.contains(QStringLiteral("/qs"))
                           || command.contains(QStringLiteral("quickshell"))) {
                    notificationProvider = QStringLiteral("kos");
                } else {
                    notificationProvider = QStringLiteral("other");
                }
                result.insert(QStringLiteral("notificationCommand"), command);
            }
        }
        result.insert(QStringLiteral("notificationProvider"), notificationProvider);
        result.insert(QStringLiteral("notificationOwner"), notificationOwner);
        result.insert(QStringLiteral("notificationPid"), notificationPid);

        QDBusInterface effects(QStringLiteral("org.kde.KWin"), QStringLiteral("/Effects"),
                               QStringLiteral("org.kde.kwin.Effects"), sessionBus);
        const QStringList loadedEffects = effects.isValid()
            ? effects.property("loadedEffects").toStringList() : QStringList{};
        result.insert(QStringLiteral("kwinAvailable"), effects.isValid());
        result.insert(QStringLiteral("glassLoaded"),
                      loadedEffects.contains(QStringLiteral("glass")));
        result.insert(QStringLiteral("dockAnimationLoaded"),
                      loadedEffects.contains(QStringLiteral("kos_dock_window_animation")));
        result.insert(QStringLiteral("contextMenuInputLoaded"),
                      loadedEffects.contains(QStringLiteral("kos_context_menu_input")));
        result.insert(QStringLiteral("updatedAt"),
                      QDateTime::currentDateTime().toString(QStringLiteral("HH:mm:ss")));
        return result;
    }

signals:
    void lastErrorChanged();

private:
    QVariantMap snapshotFromReply(const QString &payload) {
        if (payload.isEmpty())
            return {};

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(payload.toUtf8(), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            setLastError(QStringLiteral("桌面环境返回了无效的 Dock 配置"));
            return {};
        }

        const QJsonObject object = document.object();
        if (!object.contains(QStringLiteral("baseHeight"))
                || !object.contains(QStringLiteral("windowGrouping"))) {
            setLastError(QStringLiteral("桌面环境返回的 Dock 配置不完整"));
            return {};
        }

        setLastError({});
        return {
            {QStringLiteral("baseHeight"), object.value(QStringLiteral("baseHeight")).toDouble()},
            {QStringLiteral("position"), object.value(QStringLiteral("position")).toString()},
            {QStringLiteral("iconMode"), object.value(QStringLiteral("iconMode")).toString()},
            {QStringLiteral("iconOpacity"), object.value(QStringLiteral("iconOpacity")).toDouble()},
            {QStringLiteral("iconTintColor"), object.value(QStringLiteral("iconTintColor")).toString()},
            {QStringLiteral("visibilityMode"), object.value(QStringLiteral("visibilityMode")).toString()},
            {QStringLiteral("windowGrouping"), object.value(QStringLiteral("windowGrouping")).toString()},
        };
    }

    QVariantMap appearanceSnapshotFromReply(const QString &payload) {
        if (payload.isEmpty())
            return {};

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(payload.toUtf8(), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            setLastError(QStringLiteral("桌面环境返回了无效的外观配置"));
            return {};
        }

        const QJsonObject object = document.object();
        if ((!object.contains(QStringLiteral("globalBlurStrength"))
                    && !object.contains(QStringLiteral("dockBlurStrength"))
                    && !object.contains(QStringLiteral("blurStrength")))
                || (!object.contains(QStringLiteral("globalLiquidStrength"))
                    && !object.contains(QStringLiteral("dockLiquidStrength"))
                    && !object.contains(QStringLiteral("liquidStrength")))
                || !object.contains(QStringLiteral("shellStyle"))
                || !object.contains(QStringLiteral("barIntegratedWithDock"))
                || !object.contains(QStringLiteral("dockWindowAnimationStyle"))) {
            setLastError(QStringLiteral("桌面环境返回的外观配置不完整"));
            return {};
        }

        const double globalBlur = object.contains(QStringLiteral("globalBlurStrength"))
            ? object.value(QStringLiteral("globalBlurStrength")).toDouble()
            : (object.contains(QStringLiteral("dockBlurStrength"))
                ? object.value(QStringLiteral("dockBlurStrength")).toDouble()
                : object.value(QStringLiteral("blurStrength")).toDouble());
        const double globalLiquid = object.contains(QStringLiteral("globalLiquidStrength"))
            ? object.value(QStringLiteral("globalLiquidStrength")).toDouble()
            : (object.contains(QStringLiteral("dockLiquidStrength"))
                ? object.value(QStringLiteral("dockLiquidStrength")).toDouble()
                : object.value(QStringLiteral("liquidStrength")).toDouble());

        const QString barVisibility = object.value(QStringLiteral("barVisibilityMode")).toString(QStringLiteral("always"));

        setLastError({});
        return {
            {QStringLiteral("globalBlurStrength"), globalBlur},
            {QStringLiteral("globalLiquidStrength"), globalLiquid},
            {QStringLiteral("effectiveDockBlur"), globalBlur},
            {QStringLiteral("effectiveDockLiquid"), globalLiquid},
            {QStringLiteral("effectiveBarBlur"), globalBlur},
            {QStringLiteral("effectiveBarLiquid"), globalLiquid},
            {QStringLiteral("effectiveLauncherBlur"), globalBlur},
            {QStringLiteral("effectiveLauncherLiquid"), globalLiquid},
            {QStringLiteral("blurStrength"), globalBlur},
            {QStringLiteral("liquidStrength"), globalLiquid},
            {QStringLiteral("iconMode"), object.value(QStringLiteral("iconMode")).toString(QStringLiteral("color"))},
            {QStringLiteral("iconOpacity"), object.value(QStringLiteral("iconOpacity")).toDouble(0.5)},
            {QStringLiteral("iconTintColor"), object.value(QStringLiteral("iconTintColor")).toString(QStringLiteral("#a855f7"))},
            {QStringLiteral("shellStyle"), object.value(QStringLiteral("shellStyle")).toString()},
            {QStringLiteral("materialStyle"),
                object.value(QStringLiteral("materialStyle")).toString(QStringLiteral("liquid"))},
            {QStringLiteral("barIntegratedWithDock"),
                object.value(QStringLiteral("barIntegratedWithDock")).toBool()},
            {QStringLiteral("barVisibilityMode"),
                barVisibility.isEmpty() ? QStringLiteral("always") : barVisibility},
            {QStringLiteral("barLayoutMode"),
                object.value(QStringLiteral("barLayoutMode")).toString(QStringLiteral("transparent"))},
            {QStringLiteral("dockWindowAnimationStyle"),
                object.value(QStringLiteral("dockWindowAnimationStyle")).toString()},
            // 材质微调（柔光玻璃 / 轻透磨砂）
            {QStringLiteral("bionicRefract"),
                object.value(QStringLiteral("bionicRefract")).toDouble(4.0)},
            {QStringLiteral("bionicEdgeLight"),
                object.value(QStringLiteral("bionicEdgeLight")).toDouble(1.4)},
            {QStringLiteral("bionicSoftEdgePx"),
                object.value(QStringLiteral("bionicSoftEdgePx")).toDouble(1.5)},
            {QStringLiteral("bionicHsvv"),
                object.value(QStringLiteral("bionicHsvv")).toDouble(1.0)},
            {QStringLiteral("classicRefract"),
                object.value(QStringLiteral("classicRefract")).toDouble(1.5)},
            {QStringLiteral("classicReflect"),
                object.value(QStringLiteral("classicReflect")).toDouble(0.06)},
            {QStringLiteral("classicEdgeLight"),
                object.value(QStringLiteral("classicEdgeLight")).toDouble(0.1)},
            {QStringLiteral("classicSoftEdgePx"),
                object.value(QStringLiteral("classicSoftEdgePx")).toDouble(1.5)},
            {QStringLiteral("classicStrokeDegree"),
                object.value(QStringLiteral("classicStrokeDegree")).toDouble(24.0)},
            {QStringLiteral("classicStrokeSize"),
                object.value(QStringLiteral("classicStrokeSize")).toDouble(2.0)},
            {QStringLiteral("classicReflLighten"),
                object.value(QStringLiteral("classicReflLighten")).toDouble(2.0)},
            {QStringLiteral("bionicRefractMin"),
                object.value(QStringLiteral("bionicRefractMin")).toDouble(1.0)},
            {QStringLiteral("bionicRefractMax"),
                object.value(QStringLiteral("bionicRefractMax")).toDouble(5.0)},
            {QStringLiteral("bionicEdgeLightMin"),
                object.value(QStringLiteral("bionicEdgeLightMin")).toDouble(0.0)},
            {QStringLiteral("bionicEdgeLightMax"),
                object.value(QStringLiteral("bionicEdgeLightMax")).toDouble(3.0)},
            {QStringLiteral("bionicSoftEdgePxMin"),
                object.value(QStringLiteral("bionicSoftEdgePxMin")).toDouble(0.1)},
            {QStringLiteral("bionicSoftEdgePxMax"),
                object.value(QStringLiteral("bionicSoftEdgePxMax")).toDouble(25.0)},
            {QStringLiteral("bionicHsvvMin"),
                object.value(QStringLiteral("bionicHsvvMin")).toDouble(0.0)},
            {QStringLiteral("bionicHsvvMax"),
                object.value(QStringLiteral("bionicHsvvMax")).toDouble(2.0)},
            {QStringLiteral("classicRefractMin"),
                object.value(QStringLiteral("classicRefractMin")).toDouble(1.0)},
            {QStringLiteral("classicRefractMax"),
                object.value(QStringLiteral("classicRefractMax")).toDouble(2.0)},
            {QStringLiteral("classicReflectMin"),
                object.value(QStringLiteral("classicReflectMin")).toDouble(0.0)},
            {QStringLiteral("classicReflectMax"),
                object.value(QStringLiteral("classicReflectMax")).toDouble(1.5)},
            {QStringLiteral("classicEdgeLightMin"),
                object.value(QStringLiteral("classicEdgeLightMin")).toDouble(0.0)},
            {QStringLiteral("classicEdgeLightMax"),
                object.value(QStringLiteral("classicEdgeLightMax")).toDouble(0.5)},
            {QStringLiteral("classicSoftEdgePxMin"),
                object.value(QStringLiteral("classicSoftEdgePxMin")).toDouble(0.5)},
            {QStringLiteral("classicSoftEdgePxMax"),
                object.value(QStringLiteral("classicSoftEdgePxMax")).toDouble(25.0)},
            {QStringLiteral("bionicTransparency"),
                object.value(QStringLiteral("bionicTransparency")).toDouble(1.0)},
            {QStringLiteral("bionicActDarken"),
                object.value(QStringLiteral("bionicActDarken")).toDouble(0.42)},
            {QStringLiteral("bionicActEdgeLight"),
                object.value(QStringLiteral("bionicActEdgeLight")).toDouble(3.0)},
            {QStringLiteral("bionicActOpposite"),
                object.value(QStringLiteral("bionicActOpposite")).toDouble(2.0)},
            {QStringLiteral("bionicActHsvv"),
                object.value(QStringLiteral("bionicActHsvv")).toDouble(1.6)},
            {QStringLiteral("bionicActRefl"),
                object.value(QStringLiteral("bionicActRefl")).toDouble(1.3)},
            {QStringLiteral("bionicActRefract"),
                object.value(QStringLiteral("bionicActRefract")).toDouble(4.6)},
            {QStringLiteral("bionicLum0"),
                object.value(QStringLiteral("bionicLum0")).toDouble(0.67)},
            {QStringLiteral("bionicLum1"),
                object.value(QStringLiteral("bionicLum1")).toDouble(0.16)},
            {QStringLiteral("bionicLum2"),
                object.value(QStringLiteral("bionicLum2")).toDouble(0.09)},
            {QStringLiteral("bionicLum3"),
                object.value(QStringLiteral("bionicLum3")).toDouble(0.0)},
            {QStringLiteral("bionicLumAmount"),
                object.value(QStringLiteral("bionicLumAmount")).toDouble(0.24)},
            {QStringLiteral("bionicDarkBase"),
                object.value(QStringLiteral("bionicDarkBase")).toDouble(0.3)},
            {QStringLiteral("bionicDarkRange0"),
                object.value(QStringLiteral("bionicDarkRange0")).toDouble(0.6)},
            {QStringLiteral("bionicDarkRange1"),
                object.value(QStringLiteral("bionicDarkRange1")).toDouble(1.0)},
            {QStringLiteral("bionicBrightBase"),
                object.value(QStringLiteral("bionicBrightBase")).toDouble(-0.02)},
            {QStringLiteral("bionicInnerBottom"),
                object.value(QStringLiteral("bionicInnerBottom")).toDouble(0.03)},
            {QStringLiteral("bionicInnerWhite"),
                object.value(QStringLiteral("bionicInnerWhite")).toDouble(0.2)},
            {QStringLiteral("bionicInnerMix"),
                object.value(QStringLiteral("bionicInnerMix")).toDouble(0.3)},
            {QStringLiteral("bionicColorPow"),
                object.value(QStringLiteral("bionicColorPow")).toDouble(1.0)},
            {QStringLiteral("bionicAlphaLayer"),
                object.value(QStringLiteral("bionicAlphaLayer")).toDouble(0.1)},
            {QStringLiteral("bionicShapeEdgePow"),
                object.value(QStringLiteral("bionicShapeEdgePow")).toDouble(3.8)},
            {QStringLiteral("bionicShapeThickness"),
                object.value(QStringLiteral("bionicShapeThickness")).toDouble(80.0)},
            {QStringLiteral("bionicReflectOffset"),
                object.value(QStringLiteral("bionicReflectOffset")).toDouble(800.0)},
            {QStringLiteral("bionicReflLighten"),
                object.value(QStringLiteral("bionicReflLighten")).toDouble(1.2)},
            {QStringLiteral("bionicReflStrength"),
                object.value(QStringLiteral("bionicReflStrength")).toDouble(1.0)},
            {QStringLiteral("bionicDirX"),
                object.value(QStringLiteral("bionicDirX")).toDouble(-0.4)},
            {QStringLiteral("bionicDirY"),
                object.value(QStringLiteral("bionicDirY")).toDouble(0.6)},
            {QStringLiteral("bionicDirZ"),
                object.value(QStringLiteral("bionicDirZ")).toDouble(-0.8)},
            {QStringLiteral("bionicDirInt"),
                object.value(QStringLiteral("bionicDirInt")).toDouble(1.4)},
            {QStringLiteral("bionicDirOpp"),
                object.value(QStringLiteral("bionicDirOpp")).toDouble(0.7)},
            {QStringLiteral("bionicDirAngle"),
                object.value(QStringLiteral("bionicDirAngle")).toDouble(0.8)},
            {QStringLiteral("bionicDirEdgePow"),
                object.value(QStringLiteral("bionicDirEdgePow")).toDouble(1.15)},
            {QStringLiteral("bionicBgSat"),
                object.value(QStringLiteral("bionicBgSat")).toDouble(2.0)},
            {QStringLiteral("bionicBgBri"),
                object.value(QStringLiteral("bionicBgBri")).toDouble(0.0)},
            {QStringLiteral("bionicActColorPow"),
                object.value(QStringLiteral("bionicActColorPow")).toDouble(1.0)},
            {QStringLiteral("bionicTransparencyMin"),
                object.value(QStringLiteral("bionicTransparencyMin")).toDouble(0.0)},
            {QStringLiteral("bionicTransparencyMax"),
                object.value(QStringLiteral("bionicTransparencyMax")).toDouble(1.0)},
            {QStringLiteral("tokenVersion"), object.value(QStringLiteral("tokenVersion")).toInt()},
        };
    }

    QVariantMap launcherSnapshotFromReply(const QString &payload) {
        if (payload.isEmpty())
            return {};

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(payload.toUtf8(), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            setLastError(QStringLiteral("桌面环境返回了无效的启动台配置"));
            return {};
        }

        const QJsonObject object = document.object();
        if (!object.contains(QStringLiteral("displayMode"))) {
            setLastError(QStringLiteral("桌面环境返回的启动台配置不完整"));
            return {};
        }

        setLastError({});
        return {
            {QStringLiteral("displayMode"), object.value(QStringLiteral("displayMode")).toString()},
            {QStringLiteral("layoutProfiles"),
                object.value(QStringLiteral("layoutProfiles")).toObject().toVariantMap()},
        };
    }

    QVariantMap integrationSnapshotFromReply(const QString &payload) {
        if (payload.isEmpty())
            return {{QStringLiteral("shellReady"), false}};

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(payload.toUtf8(), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            setLastError(QStringLiteral("桌面环境返回了无效的接入状态"));
            return {{QStringLiteral("shellReady"), false}};
        }
        setLastError({});
        return document.object().toVariantMap();
    }

    QVariantMap shortcutsSnapshotFromReply(const QString &payload) {
        if (payload.isEmpty())
            return {};

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(payload.toUtf8(), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            setLastError(QStringLiteral("桌面环境返回了无效的快捷键配置"));
            return {};
        }

        const QJsonObject object = document.object();
        if (!object.contains(QStringLiteral("shortcuts"))) {
            setLastError(QStringLiteral("桌面环境返回的快捷键配置不完整"));
            return {};
        }

        QVariantList shortcuts;
        for (const QJsonValue &value : object.value(QStringLiteral("shortcuts")).toArray()) {
            const QJsonObject item = value.toObject();
            shortcuts.append(QVariantMap{
                {QStringLiteral("id"), item.value(QStringLiteral("id")).toString()},
                {QStringLiteral("description"), item.value(QStringLiteral("description")).toString()},
                {QStringLiteral("defaultCombo"), item.value(QStringLiteral("defaultCombo")).toString()},
                {QStringLiteral("combo"), item.value(QStringLiteral("combo")).toString()},
                {QStringLiteral("custom"), item.value(QStringLiteral("custom")).toBool()},
            });
        }

        // The Shell validates rebinding requests and reports rejections
        // (unknown id, malformed combo, duplicate binding) inline instead of
        // failing the IPC call, so surface it the same way as transport errors.
        const QString error = object.value(QStringLiteral("error")).toString();
        setLastError(error);
        return {
            {QStringLiteral("shortcuts"), shortcuts},
            {QStringLiteral("error"), error},
        };
    }

    QString callDock(const QStringList &arguments) {
        return callShell(QStringLiteral("dock-settings"), arguments,
                         QStringLiteral("Dock 设置请求失败"));
    }

    QString callAppearance(const QStringList &arguments) {
        return callShell(QStringLiteral("appearance-settings"), arguments,
                         QStringLiteral("外观设置请求失败"));
    }

    QString callLauncher(const QStringList &arguments) {
        return callShell(QStringLiteral("applauncher-settings"), arguments,
                         QStringLiteral("启动台设置请求失败"));
    }

    QString callShortcuts(const QStringList &arguments) {
        return callShell(QStringLiteral("shortcuts-settings"), arguments,
                         QStringLiteral("快捷键设置请求失败"));
    }

    QString callIntegration(const QStringList &arguments) {
        return callShell(QStringLiteral("integration-status"), arguments,
                         QStringLiteral("接入状态请求失败"));
    }

    static QString shellDirectory() {
        const QString configured = qEnvironmentVariable("KOS_SHELL_DIR");
        if (!configured.isEmpty())
            return configured;

        // Development desktop entries do not inherit the Shell environment.
        // Prefer the compile-time source tree when it still exists; this is
        // the same tree a locally built settings binary was compiled for.
        const QString source = QStringLiteral(SETTINGS_SHELL_DIR);
        if (QFileInfo::exists(QDir(source).filePath(QStringLiteral("shell.qml"))))
            return source;

        const QString installed = QStandardPaths::writableLocation(
            QStandardPaths::ConfigLocation) + QStringLiteral("/quickshell/kos");
        return installed;
    }

    QString callShell(const QString &target, const QStringList &arguments,
                      const QString &fallbackError) {
        const QString shellPath = shellDirectory();
        QString failure;
        // Quickshell tracks instances by how they identify their config: a
        // Shell launched as `-c kos` is NOT matched by `--path <same dir>`.
        // The installed session runs as `-c kos`, so address it by name;
        // development sessions (`-p <dir>`) take the explicit path.
        const QString installed = QStandardPaths::writableLocation(
            QStandardPaths::ConfigLocation) + QStringLiteral("/quickshell/kos");
        QStringList connectArgs;
        if (shellPath == installed)
            connectArgs = {QStringLiteral("-c"), QStringLiteral("kos")};
        else
            connectArgs = {QStringLiteral("--path"), shellPath};
        // The Shell can still be registering IPC targets during the first
        // moments of a development launch. Retry once instead of turning that
        // brief race into a permanent, opaque Settings error.
        for (int attempt = 0; attempt < 2; ++attempt) {
            QProcess process;
            QStringList command = connectArgs;
            command << QStringLiteral("ipc") << QStringLiteral("call") << target;
            command.append(arguments);
            process.start(QStringLiteral("quickshell"), command);
            if (!process.waitForStarted(1500)) {
                failure = QStringLiteral("无法启动 Quickshell IPC");
            } else if (!process.waitForFinished(5000)) {
                process.kill();
                process.waitForFinished();
                failure = QStringLiteral("桌面环境没有响应（超过 5 秒）");
            } else if (process.exitStatus() == QProcess::NormalExit
                       && process.exitCode() == 0) {
                return QString::fromUtf8(process.readAllStandardOutput()).trimmed();
            } else {
                failure = QString::fromUtf8(process.readAllStandardError()).trimmed();
                if (failure.isEmpty())
                    failure = fallbackError;
            }
            if (attempt == 0)
                QThread::msleep(120);
        }
        setLastError(QStringLiteral("%1（IPC：%2；Shell：%3）")
                         .arg(failure, target, shellPath));
        return {};
    }

    void setLastError(const QString &error) {
        if (m_lastError == error)
            return;
        m_lastError = error;
        emit lastErrorChanged();
    }

    QString m_lastError;
};

int main(int argc, char *argv[]) {
    QGuiApplication application(argc, argv);
    // Keep this window out of the Shell's KWin rules. This must match the
    // installed desktop entry basename: kos-settings.desktop.
    application.setApplicationName(QStringLiteral("kos-settings"));
    application.setApplicationDisplayName(QStringLiteral(""));
    application.setDesktopFileName(QStringLiteral("kos-settings"));
    application.setOrganizationName(QStringLiteral("Quickshell"));

    SettingsBridge bridge;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("settingsBridge"), &bridge);
    QString settingsQml = QDir(QCoreApplication::applicationDirPath()).filePath(
        QStringLiteral("../share/kos/settings/main.qml"));
    if (!QFileInfo::exists(settingsQml))
        settingsQml = QDir(QStringLiteral(SETTINGS_QML_DIR)).filePath(
            QStringLiteral("main.qml"));
    const QUrl entrypoint = QUrl::fromLocalFile(settingsQml);
    engine.load(entrypoint);
    if (engine.rootObjects().isEmpty())
        return 1;
    return application.exec();
}

#include "main.moc"
