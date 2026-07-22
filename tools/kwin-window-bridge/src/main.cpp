#include <QDBusConnection>
#include <QDBusError>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QQueue>
#include <QRegularExpression>
#include <QSocketNotifier>
#include <QStandardPaths>
#include <QSettings>
#include <QGuiApplication>
#include <QTextStream>

#include <KIconLoader>

#include <unistd.h>

class Bridge final : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.quickshell.KWinWindowBridge")

public slots:
    void Publish(const QString &payload)
    {
        QJsonParseError error;
        const QJsonDocument document = QJsonDocument::fromJson(payload.toUtf8(), &error);
        if (error.error != QJsonParseError::NoError || !document.isObject()) {
            QTextStream(stderr) << "Invalid KWin event: " << error.errorString() << Qt::endl;
            return;
        }

        QJsonObject event = document.object();
        if (event.value(QStringLiteral("type")) == QStringLiteral("snapshot")) {
            QJsonArray windows = event.value(QStringLiteral("windows")).toArray();
            for (int i = 0; i < windows.size(); ++i) {
                QJsonObject window = windows.at(i).toObject();
                const QString icon = findFallbackIcon(window.value(QStringLiteral("appId")).toString());
                if (!icon.isEmpty()) window.insert(QStringLiteral("iconPath"), icon);
                windows[i] = window;
            }
            event.insert(QStringLiteral("windows"), windows);
        }
        QTextStream(stdout) << "EVENT " << QJsonDocument(event).toJson(QJsonDocument::Compact) << Qt::endl;
    }

    QString TakeCommand()
    {
        return m_commands.isEmpty() ? QString{} : m_commands.dequeue();
    }

    void Enqueue(const QString &payload)
    {
        QJsonParseError error;
        const QJsonDocument document = QJsonDocument::fromJson(payload.toUtf8(), &error);
        if (error.error != QJsonParseError::NoError || !document.isObject())
            return;

        const QString command = QString::fromUtf8(document.toJson(QJsonDocument::Compact));
        const QString action = document.object().value(QStringLiteral("action")).toString();

        // A Dock click expresses the latest focus intent. Keeping older
        // activate requests makes rapid clicks feel delayed and can focus a
        // window the user has already moved away from. Preserve close and
        // minimize requests, but replace queued activations with the latest.
        if (action == QStringLiteral("activate")) {
            QQueue<QString> retained;
            while (!m_commands.isEmpty()) {
                const QString queued = m_commands.dequeue();
                QJsonParseError queuedError;
                const QJsonDocument queuedDocument = QJsonDocument::fromJson(
                    queued.toUtf8(), &queuedError);
                const bool isActivation = queuedError.error == QJsonParseError::NoError
                    && queuedDocument.isObject()
                    && queuedDocument.object().value(QStringLiteral("action")).toString()
                        == QStringLiteral("activate");
                if (!isActivation)
                    retained.enqueue(queued);
            }
            m_commands = retained;
        }

        m_commands.enqueue(command);
    }

    QString Ping() const
    {
        return QStringLiteral("ready");
    }

private:
    static QString normalizeName(QString value) {
        value = value.toLower(); value.remove(QStringLiteral(".desktop"));
        QString result;
        for (const QChar c : value) if (c.isLetterOrNumber()) result.append(c);
        return result;
    }

    void ensureDesktopIndex() {
        if (m_desktopIndexReady) return;
        m_desktopIndexReady = true;
        for (const QString &directory : QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation)) {
            QDirIterator it(directory, {QStringLiteral("*.desktop")}, QDir::Files);
            while (it.hasNext()) {
                const QString path = it.next(); QSettings desktop(path, QSettings::IniFormat);
                desktop.beginGroup(QStringLiteral("Desktop Entry"));
                const QString icon = desktop.value(QStringLiteral("Icon")).toString().trimmed();
                const QString startup = desktop.value(QStringLiteral("StartupWMClass")).toString().trimmed();
                desktop.endGroup(); if (icon.isEmpty()) continue;
                const QString id = normalizeName(QFileInfo(path).completeBaseName());
                const QString startupId = normalizeName(startup);
                if (!id.isEmpty() && !m_desktopIcons.contains(id)) m_desktopIcons.insert(id, icon);
                if (!startupId.isEmpty() && !m_desktopIcons.contains(startupId)) m_desktopIcons.insert(startupId, icon);
            }
        }
    }

    QString findFallbackIcon(const QString &appId) {
        ensureDesktopIndex();
        const QString appKey = normalizeName(appId);
        QString iconName = m_desktopIcons.value(appKey);
        if (iconName.isEmpty()) {
            for (auto it = m_desktopIcons.cbegin(); it != m_desktopIcons.cend(); ++it) {
                if (it.key().contains(appKey) || appKey.contains(it.key())) { iconName = it.value(); break; }
            }
        }
        const QString requestedIcon = iconName.isEmpty() ? appId : iconName;
        if (requestedIcon.startsWith(QLatin1Char('/')) && QFileInfo::exists(requestedIcon))
            return requestedIcon;

        const QString key = normalizeName(requestedIcon);
        if (key.isEmpty()) return {};
        if (m_iconCache.contains(key)) return m_iconCache.value(key);

        // This is the same lookup used by KDE's kiconfinder6: KIconLoader is
        // aware of kdeglobals, the selected icon theme and its inheritance.
        // In particular, a desktop entry such as spotify-launcher resolves to
        // the themed Spotify artwork instead of its hicolor fallback.
        const QString themedIcon = KIconLoader::global()->iconPath(
            requestedIcon, KIconLoader::Desktop, true);
        if (!themedIcon.isEmpty()) {
            m_iconCache.insert(key, themedIcon);
            return themedIcon;
        }

        QString bestPath; int bestScore = -1;
        const QRegularExpression sizeExpression(QStringLiteral("/(\\d+)x\\d+/"));
        for (const QString &root : QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation)) {
            QDirIterator it(root + QStringLiteral("/icons"), {QStringLiteral("*.png"), QStringLiteral("*.svg"), QStringLiteral("*.xpm")}, QDir::Files, QDirIterator::Subdirectories);
            while (it.hasNext()) {
                const QString path = it.next(); const QString name = normalizeName(QFileInfo(path).baseName());
                if (name.isEmpty() || (name != key && !name.contains(key))) continue;
                int score = name == key ? 10000 : 5000 - (name.size() - key.size());
                if (path.contains(QStringLiteral("/apps/"))) score += 1000;
                if (path.contains(QStringLiteral("scalable"))) score += 500;
                const auto match = sizeExpression.match(path); if (match.hasMatch()) score += match.captured(1).toInt();
                if (score > bestScore) { bestScore = score; bestPath = path; }
            }
        }
        m_iconCache.insert(key, bestPath); return bestPath;
    }

    QQueue<QString> m_commands;
    QHash<QString, QString> m_desktopIcons;
    QHash<QString, QString> m_iconCache;
    bool m_desktopIndexReady = false;
};

int main(int argc, char *argv[])
{
    // KIconLoader needs a GUI application in order to inherit the exact KDE
    // session/theme context. QCoreApplication silently falls back to a
    // different icon context for some themes.
    QGuiApplication application(argc, argv);
    QDBusConnection bus = QDBusConnection::sessionBus();

    if (!bus.registerService(QStringLiteral("org.quickshell.KWinWindowBridge"))) {
        QTextStream(stderr) << "Could not register D-Bus service: "
                            << bus.lastError().message() << Qt::endl;
        return 1;
    }

    Bridge bridge;
    if (!bus.registerObject(QStringLiteral("/WindowBridge"), &bridge,
                            QDBusConnection::ExportAllSlots)) {
        QTextStream(stderr) << "Could not register D-Bus object: "
                            << bus.lastError().message() << Qt::endl;
        return 1;
    }

    QTextStream(stdout) << "READY" << Qt::endl;

    // Quickshell owns this process and writes newline-delimited commands to
    // stdin. This is deliberately faster than spawning qdbus6 for every Dock
    // click; KWin still retrieves the commands by its own polling loop.
    QFile input;
    if (input.open(STDIN_FILENO, QIODevice::ReadOnly | QIODevice::Text)) {
        QSocketNotifier inputNotifier(STDIN_FILENO, QSocketNotifier::Read);
        QObject::connect(&inputNotifier, &QSocketNotifier::activated,
                         [&input, &bridge]() {
            // QFile::canReadLine() does not fill its buffer for a pipe, so it
            // can stay false even after QSocketNotifier reported readable
            // data. The notifier guarantees this read will not block.
            const QString command = QString::fromUtf8(input.readLine()).trimmed();
            if (!command.isEmpty())
                bridge.Enqueue(command);
        });
        return application.exec();
    }

    QTextStream(stderr) << "Could not read bridge stdin" << Qt::endl;
    return application.exec();
}

#include "main.moc"
