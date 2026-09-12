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

    Q_INVOKABLE QVariantMap updateDockEdgeMargin(double margin) {
        return snapshotFromReply(callDock({QStringLiteral("updateEdgeMargin"),
                                           QString::number(margin, 'f', 2)}));
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

    Q_INVOKABLE QVariantMap updateDockShowWidgets(bool enabled) {
        return snapshotFromReply(callDock({QStringLiteral("updateShowWidgets"),
                                           enabled ? QStringLiteral("true") : QStringLiteral("false")}));
    }

    Q_INVOKABLE QVariantMap updateDockWidgetMode(const QString &mode) {
        return snapshotFromReply(callDock({QStringLiteral("updateWidgetMode"), mode}));
    }

    Q_INVOKABLE QVariantMap updateDockFixedWidget(const QString &widget) {
        return snapshotFromReply(callDock({QStringLiteral("updateFixedWidget"), widget}));
    }

    Q_INVOKABLE QVariantMap updateDockWidgetEnabled(const QString &id, bool enabled) {
        return snapshotFromReply(callDock({QStringLiteral("updateDockWidgetEnabled"),
                                           id,
                                           enabled ? QStringLiteral("true") : QStringLiteral("false")}));
    }

    Q_INVOKABLE QVariantMap updateDockCarouselInterval(int seconds) {
        return snapshotFromReply(callDock({QStringLiteral("updateCarouselInterval"),
                                           QString::number(seconds)}));
    }

    Q_INVOKABLE QVariantMap widgetsSnapshot() {
        return widgetsSnapshotFromReply(callWidgets({QStringLiteral("snapshot")}));
    }

    Q_INVOKABLE QVariantMap updateDesktopWidgetsEnabled(bool enabled) {
        return widgetsSnapshotFromReply(callWidgets({QStringLiteral("updateDesktopWidgetsEnabled"),
                                                    enabled ? QStringLiteral("true") : QStringLiteral("false")}));
    }

    Q_INVOKABLE QVariantMap updateDesktopWidgetEnabled(const QString &id, bool enabled) {
        return widgetsSnapshotFromReply(callWidgets({QStringLiteral("updateDesktopWidgetEnabled"),
                                                    id,
                                                    enabled ? QStringLiteral("true") : QStringLiteral("false")}));
    }

    Q_INVOKABLE QVariantMap updateDesktopWidgetSize(const QString &id, const QString &size) {
        return widgetsSnapshotFromReply(callWidgets({QStringLiteral("updateDesktopWidgetSize"),
                                                    id, size}));
    }

    static QString weatherCtlBinary() {
        QStringList candidates;
        candidates.append(QDir::home().filePath(QStringLiteral(".local/bin/kos-weather-ctl")));
        candidates.append(QDir(QStringLiteral(SETTINGS_SHELL_DIR)).filePath(QStringLiteral("tools/kos-weather-ctl")));
        candidates.append(QStringLiteral("/usr/local/bin/kos-weather-ctl"));
        candidates.append(QStringLiteral("/usr/bin/kos-weather-ctl"));
        for (const QString &cand : candidates) {
            if (QFileInfo::exists(cand))
                return cand;
        }
        return QStringLiteral("kos-weather-ctl");
    }

    QByteArray runWeatherCtl(const QStringList &args) {
        QProcess proc;
        proc.start(weatherCtlBinary(), args);
        if (!proc.waitForStarted(1500))
            return {};
        if (!proc.waitForFinished(6000)) {
            proc.kill();
            proc.waitForFinished();
            return {};
        }
        return proc.readAllStandardOutput().trimmed();
    }

    Q_INVOKABLE QVariantMap weatherCurrentLocation() {
        const QByteArray raw = runWeatherCtl({QStringLiteral("current")});
        if (raw.isEmpty()) return {};
        const auto doc = QJsonDocument::fromJson(raw);
        if (doc.isObject() && doc.object().value(QStringLiteral("ok")).toBool()) {
            return doc.object().value(QStringLiteral("location")).toObject().toVariantMap();
        }
        return {};
    }

    Q_INVOKABLE QVariantList searchWeatherCities(const QString &query) {
        if (query.trimmed().isEmpty()) return {};
        const QByteArray raw = runWeatherCtl({QStringLiteral("search"), query.trimmed()});
        if (raw.isEmpty()) return {};
        const auto doc = QJsonDocument::fromJson(raw);
        if (doc.isObject() && doc.object().value(QStringLiteral("ok")).toBool()) {
            QVariantList list;
            for (const auto &item : doc.object().value(QStringLiteral("locations")).toArray()) {
                list.append(item.toObject().toVariantMap());
            }
            return list;
        }
        return {};
    }

    Q_INVOKABLE QVariantMap autoDetectWeatherLocation() {
        const QByteArray raw = runWeatherCtl({QStringLiteral("auto-locate")});
        if (raw.isEmpty()) return {};
        const auto doc = QJsonDocument::fromJson(raw);
        if (doc.isObject() && doc.object().value(QStringLiteral("ok")).toBool()) {
            QVariantMap res = doc.object().value(QStringLiteral("location")).toObject().toVariantMap();
            res.insert(QStringLiteral("detected"), doc.object().value(QStringLiteral("detected")).toString());
            return res;
        }
        return {};
    }

    Q_INVOKABLE bool setWeatherLocation(const QVariantMap &location) {
        const QString locJson = QString::fromUtf8(QJsonDocument(QJsonObject::fromVariantMap(location)).toJson(QJsonDocument::Compact));
        const QByteArray raw = runWeatherCtl({QStringLiteral("set"), locJson});
        if (raw.isEmpty()) return false;
        const auto doc = QJsonDocument::fromJson(raw);
        return doc.isObject() && doc.object().value(QStringLiteral("ok")).toBool();
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
            {QStringLiteral("edgeMargin"), object.value(QStringLiteral("edgeMargin")).toDouble(10.0)},
            {QStringLiteral("position"), object.value(QStringLiteral("position")).toString()},
            {QStringLiteral("iconMode"), object.value(QStringLiteral("iconMode")).toString()},
            {QStringLiteral("iconOpacity"), object.value(QStringLiteral("iconOpacity")).toDouble()},
            {QStringLiteral("iconTintColor"), object.value(QStringLiteral("iconTintColor")).toString()},
            {QStringLiteral("visibilityMode"), object.value(QStringLiteral("visibilityMode")).toString()},
            {QStringLiteral("windowGrouping"), object.value(QStringLiteral("windowGrouping")).toString()},
            {QStringLiteral("showWidgets"), object.value(QStringLiteral("showWidgets")).toBool(true)},
            {QStringLiteral("widgetMode"), object.value(QStringLiteral("widgetMode")).toString(QStringLiteral("carousel"))},
            {QStringLiteral("fixedWidget"), object.value(QStringLiteral("fixedWidget")).toString(QStringLiteral("weather"))},
            {QStringLiteral("enabledWidgets"), object.value(QStringLiteral("enabledWidgets")).toObject().toVariantMap()},
            {QStringLiteral("carouselInterval"), object.value(QStringLiteral("carouselInterval")).toInt(30)},
        };
    }

    QVariantMap widgetsSnapshotFromReply(const QString &payload) {
        if (payload.isEmpty())
            return {};

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(payload.toUtf8(), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            setLastError(QStringLiteral("桌面环境返回了无效的小组件配置"));
            return {};
        }

        const QJsonObject object = document.object();
        setLastError({});

        QVariantList widgetList;
        for (const QJsonValue &val : object.value(QStringLiteral("widgets")).toArray()) {
            const QJsonObject w = val.toObject();
            widgetList.append(QVariantMap{
                {QStringLiteral("id"), w.value(QStringLiteral("id")).toString()},
                {QStringLiteral("name"), w.value(QStringLiteral("name")).toString()},
                {QStringLiteral("desc"), w.value(QStringLiteral("desc")).toString()},
                {QStringLiteral("icon"), w.value(QStringLiteral("icon")).toString()},
                {QStringLiteral("enabled"), w.value(QStringLiteral("enabled")).toBool(true)},
                {QStringLiteral("size"), w.value(QStringLiteral("size")).toString(QStringLiteral("medium"))}
            });
        }

        const QVariantMap curWeather = weatherCurrentLocation();
        const QString weatherCity = curWeather.value(QStringLiteral("name")).toString();
        const QString weatherAdmin1 = curWeather.value(QStringLiteral("admin1")).toString();
        const QString weatherCountry = curWeather.value(QStringLiteral("country")).toString();

        return {
            {QStringLiteral("desktopWidgetsEnabled"), object.value(QStringLiteral("desktopWidgetsEnabled")).toBool(true)},
            {QStringLiteral("widgets"), widgetList},
            {QStringLiteral("dockShowWidgets"), object.value(QStringLiteral("dockShowWidgets")).toBool(true)},
            {QStringLiteral("dockWidgetMode"), object.value(QStringLiteral("dockWidgetMode")).toString(QStringLiteral("carousel"))},
            {QStringLiteral("dockFixedWidget"), object.value(QStringLiteral("dockFixedWidget")).toString(QStringLiteral("weather"))},
            {QStringLiteral("dockEnabledWidgets"), object.value(QStringLiteral("dockEnabledWidgets")).toObject().toVariantMap()},
            {QStringLiteral("dockCarouselInterval"), object.value(QStringLiteral("dockCarouselInterval")).toInt(30)},
            {QStringLiteral("weatherCity"), weatherCity},
            {QStringLiteral("weatherAdmin1"), weatherAdmin1},
            {QStringLiteral("weatherCountry"), weatherCountry},
            {QStringLiteral("weatherLocation"), curWeather}
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
            {QStringLiteral("barIntegratedWithDock"),
                object.value(QStringLiteral("barIntegratedWithDock")).toBool()},
            {QStringLiteral("barVisibilityMode"),
                barVisibility.isEmpty() ? QStringLiteral("always") : barVisibility},
            {QStringLiteral("barLayoutMode"),
                object.value(QStringLiteral("barLayoutMode")).toString(QStringLiteral("transparent"))},
            {QStringLiteral("dockWindowAnimationStyle"),
                object.value(QStringLiteral("dockWindowAnimationStyle")).toString()},
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

    QString callWidgets(const QStringList &arguments) {
        return callShell(QStringLiteral("widget-settings"), arguments,
                         QStringLiteral("小组件设置请求失败"));
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
