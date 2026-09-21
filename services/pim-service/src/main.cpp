#include "PimStore.h"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusError>
#include <QDebug>
#include <QMetaObject>

int main(int argc, char *argv[])
{
    QCoreApplication application(argc, argv);
    application.setApplicationName(QStringLiteral("kos-pim-service"));
    application.setApplicationVersion(QStringLiteral(KOS_APP_VERSION));
    application.setOrganizationName(QStringLiteral("NextKde"));
    application.setOrganizationDomain(QStringLiteral("nextkde.org"));

    PimStore store;
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.registerObject(QStringLiteral("/Pim"), &store,
                            QDBusConnection::ExportAllSlots
                                | QDBusConnection::ExportAllSignals)) {
        qCritical() << "Unable to export PIM object:" << bus.lastError().message();
        return 1;
    }
    if (!bus.registerService(QStringLiteral("org.nextkde.Kos.Pim1"))) {
        qCritical() << "Unable to own PIM service name:" << bus.lastError().message();
        return 1;
    }

    // D-Bus-activated services must not outlive the session bus: a detached
    // PIM process is left behind when a user logs out or a private test
    // session ends. org.freedesktop.DBus.Local.Disconnected is synthesised
    // by QtDBus locally when the bus connection drops -- no polling needed.
    // isConnected() is checked once up front in case the connection was
    // already dead before the watch was armed.
    bus.connect(QStringLiteral("org.freedesktop.DBus.Local"),
                QStringLiteral("/org/freedesktop/DBus/Local"),
                QStringLiteral("org.freedesktop.DBus.Local"),
                QStringLiteral("Disconnected"),
                &application, SLOT(quit()));
    if (!bus.isConnected())
        QMetaObject::invokeMethod(&application, "quit", Qt::QueuedConnection);

    return application.exec();
}
