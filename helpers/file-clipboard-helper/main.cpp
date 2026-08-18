#include <QClipboard>
#include <QFile>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMimeData>
#include <QSet>
#include <QTextStream>
#include <QTimer>
#include <QUrl>

namespace {

constexpr auto kdeCutMime = "application/x-kde-cutselection";
constexpr auto gnomeFilesMime = "x-special/gnome-copied-files";

void writeResponse(bool ok, const QString &mode = {},
                   const QStringList &paths = {}, const QString &error = {})
{
    QJsonObject response{{QStringLiteral("type"), QStringLiteral("clipboard")},
                         {QStringLiteral("ok"), ok}};
    if (!mode.isEmpty())
        response.insert(QStringLiteral("mode"), mode);
    if (!paths.isEmpty()) {
        QJsonArray values;
        for (const QString &path : paths)
            values.append(path);
        response.insert(QStringLiteral("paths"), values);
    }
    if (!error.isEmpty())
        response.insert(QStringLiteral("error"), error);
    QFile output;
    if (!output.open(stdout, QIODevice::WriteOnly))
        return;
    output.write(QJsonDocument(response).toJson(QJsonDocument::Compact));
    output.write("\n");
    output.flush();
}

QStringList localPathsFromMimeData(const QMimeData *mimeData)
{
    QStringList paths;
    QSet<QString> seen;
    auto appendUrl = [&](const QUrl &url) {
        if (!url.isLocalFile())
            return;
        const QString path = url.toLocalFile();
        if (path.isEmpty() || seen.contains(path))
            return;
        seen.insert(path);
        paths.append(path);
    };

    for (const QUrl &url : mimeData->urls())
        appendUrl(url);
    if (paths.isEmpty() && mimeData->hasFormat(QStringLiteral("text/uri-list"))) {
        const QList<QByteArray> lines = mimeData->data(QStringLiteral("text/uri-list"))
                                            .split('\n');
        for (QByteArray line : lines) {
            line = line.trimmed();
            if (!line.isEmpty() && !line.startsWith('#'))
                appendUrl(QUrl::fromEncoded(line));
        }
    }
    if (paths.isEmpty() && mimeData->hasFormat(QString::fromLatin1(gnomeFilesMime))) {
        const QList<QByteArray> lines = mimeData->data(QString::fromLatin1(gnomeFilesMime))
                                            .split('\n');
        for (qsizetype index = 1; index < lines.size(); ++index)
            appendUrl(QUrl::fromEncoded(lines.at(index).trimmed()));
    }
    return paths;
}

QString operationFromMimeData(const QMimeData *mimeData)
{
    if (mimeData->hasFormat(QString::fromLatin1(kdeCutMime))
        && mimeData->data(QString::fromLatin1(kdeCutMime)).trimmed() == "1") {
        return QStringLiteral("cut");
    }
    if (mimeData->hasFormat(QString::fromLatin1(gnomeFilesMime))) {
        const QByteArray firstLine = mimeData->data(QString::fromLatin1(gnomeFilesMime))
                                         .split('\n').value(0).trimmed();
        if (firstLine == "cut")
            return QStringLiteral("cut");
    }
    return QStringLiteral("copy");
}

int setClipboard(QGuiApplication &application)
{
    QFile input;
    if (!input.open(stdin, QIODevice::ReadOnly)) {
        writeResponse(false, {}, {}, QStringLiteral("cannot read request"));
        return 2;
    }
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(input.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        writeResponse(false, {}, {}, QStringLiteral("invalid clipboard request"));
        return 2;
    }
    const QJsonObject request = document.object();
    const QString mode = request.value(QStringLiteral("mode")).toString();
    if (mode != QStringLiteral("copy") && mode != QStringLiteral("cut")) {
        writeResponse(false, {}, {}, QStringLiteral("invalid clipboard mode"));
        return 2;
    }

    QList<QUrl> urls;
    QStringList paths;
    QSet<QString> seen;
    for (const QJsonValue &value : request.value(QStringLiteral("paths")).toArray()) {
        const QString path = value.toString();
        if (!path.startsWith(u'/') || seen.contains(path))
            continue;
        seen.insert(path);
        paths.append(path);
        urls.append(QUrl::fromLocalFile(path));
    }
    if (urls.isEmpty()) {
        writeResponse(false, {}, {}, QStringLiteral("clipboard path list is empty"));
        return 2;
    }

    auto *mimeData = new QMimeData;
    mimeData->setUrls(urls);
    mimeData->setData(QString::fromLatin1(kdeCutMime), mode == QStringLiteral("cut") ? "1" : "0");
    QByteArray gnomePayload = mode.toUtf8();
    for (const QUrl &url : urls) {
        gnomePayload.append('\n');
        gnomePayload.append(url.toEncoded());
    }
    mimeData->setData(QString::fromLatin1(gnomeFilesMime), gnomePayload);

    QClipboard *clipboard = QGuiApplication::clipboard();
    bool published = false;
    QObject::connect(clipboard, &QClipboard::dataChanged, &application,
                     [&application, clipboard, &published] {
        // Wayland selections are served by their owner. Exit once another
        // application replaces this selection, but ignore setMimeData's own
        // initial dataChanged signal.
        if (published && !clipboard->ownsClipboard())
            application.quit();
    });
    clipboard->setMimeData(mimeData, QClipboard::Clipboard);
    QTimer::singleShot(0, &application, [&application, clipboard, &published, mode, paths] {
        published = true;
        if (!clipboard->ownsClipboard()) {
            writeResponse(false, {}, {}, QStringLiteral("cannot own clipboard"));
            application.exit(1);
            return;
        }
        writeResponse(true, mode, paths);
    });
    return application.exec();
}

int readClipboard(QGuiApplication &application)
{
    QTimer::singleShot(0, &application, [&application] {
        const QMimeData *mimeData = QGuiApplication::clipboard()->mimeData(
            QClipboard::Clipboard);
        if (!mimeData) {
            writeResponse(false, {}, {}, QStringLiteral("clipboard is unavailable"));
            application.exit(1);
            return;
        }
        writeResponse(true, operationFromMimeData(mimeData),
                      localPathsFromMimeData(mimeData));
        application.quit();
    });
    return application.exec();
}

} // namespace

int main(int argc, char *argv[])
{
    QGuiApplication application(argc, argv);
    const QStringList arguments = application.arguments();
    if (arguments.size() != 2) {
        writeResponse(false, {}, {}, QStringLiteral("expected --set or --read"));
        return 2;
    }
    if (arguments.at(1) == QStringLiteral("--set"))
        return setClipboard(application);
    if (arguments.at(1) == QStringLiteral("--read"))
        return readClipboard(application);
    writeResponse(false, {}, {}, QStringLiteral("unknown operation"));
    return 2;
}
