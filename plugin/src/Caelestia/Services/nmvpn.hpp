#pragma once

#include "networkagent.hpp" // NMVariantMapMap

#include <qdbusmessage.h>
#include <qhash.h>
#include <qlist.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qstring.h>
#include <qvariant.h>

class QDBusServiceWatcher;

namespace caelestia::shell::services {

// NetworkManager's VPN and WireGuard profiles, kept live over D-Bus (no polling).
class NmVpn : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // [{ uuid, name, kind, interface, state }], state is disconnected/connecting/connected/disconnecting
    Q_PROPERTY(QVariantList connections READ connections NOTIFY connectionsChanged)
    // True once the profile list has been read from NetworkManager at least once
    Q_PROPERTY(bool loaded READ loaded NOTIFY loadedChanged)

public:
    explicit NmVpn(QObject* parent = nullptr);

    [[nodiscard]] QVariantList connections() const;
    [[nodiscard]] bool loaded() const { return m_loaded; }

    Q_INVOKABLE void activate(const QString& uuid);
    Q_INVOKABLE void deactivate(const QString& uuid);

signals:
    void connectionsChanged();
    void loadedChanged();
    void activationFailed(const QString& uuid, const QString& message);

private slots:
    void onNewConnection(const QDBusObjectPath& path);
    void onConnectionRemoved(const QDBusObjectPath& path);
    void onConnectionUpdated(const QDBusMessage& msg);
    void onManagerPropertiesChanged(const QString& iface, const QVariantMap& changed, const QStringList& invalidated);
    void onActiveStateChanged(const QDBusMessage& msg);

private:
    struct Profile {
        QString path;
        QString uuid;
        QString name;
        QString kind;
        QString iface;
    };

    struct Active {
        QString uuid;
        uint state = 0;
        bool reachedActivated = false;
    };

    void reload();
    void clear();
    void loadProfile(const QString& path);
    void fetchActiveConnections();
    void setActiveConnections(const QList<QDBusObjectPath>& paths);
    void stepDone();
    void setLoaded();

    bool m_loaded = false;
    bool m_loading = false;
    int m_pending = 0;
    QList<Profile> m_profiles;
    QHash<QString, Active> m_active; // active connection path -> state
    QDBusServiceWatcher* m_watcher = nullptr;
};

} // namespace caelestia::shell::services
