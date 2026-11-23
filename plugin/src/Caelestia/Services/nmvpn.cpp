#include "nmvpn.hpp"

#include <qdbusargument.h>
#include <qdbusconnection.h>
#include <qdbusextratypes.h>
#include <qdbusmetatype.h>
#include <qdbuspendingcall.h>
#include <qdbuspendingreply.h>
#include <qdbusservicewatcher.h>
#include <qloggingcategory.h>

#include <algorithm>
#include <functional>

namespace {

Q_LOGGING_CATEGORY(lcNmVpn, "caelestia.services.nmvpn", QtInfoMsg)

} // namespace

namespace caelestia::shell::services {

using Qt::StringLiterals::operator""_s;

namespace {

const QString k_service = u"org.freedesktop.NetworkManager"_s;
const QString k_managerPath = u"/org/freedesktop/NetworkManager"_s;
const QString k_managerIface = u"org.freedesktop.NetworkManager"_s;
const QString k_settingsPath = u"/org/freedesktop/NetworkManager/Settings"_s;
const QString k_settingsIface = u"org.freedesktop.NetworkManager.Settings"_s;
const QString k_connectionIface = u"org.freedesktop.NetworkManager.Settings.Connection"_s;
const QString k_activeIface = u"org.freedesktop.NetworkManager.Connection.Active"_s;
const QString k_propsIface = u"org.freedesktop.DBus.Properties"_s;

// NMActiveConnectionState
constexpr uint k_activating = 1;
constexpr uint k_activated = 2;
constexpr uint k_deactivating = 3;
constexpr uint k_deactivated = 4;

bool isVpnType(const QString& type) {
    return type == u"vpn"_s || type == u"wireguard"_s;
}

QString stateName(uint state) {
    switch (state) {
    case k_activating:
        return u"connecting"_s;
    case k_activated:
        return u"connected"_s;
    case k_deactivating:
        return u"disconnecting"_s;
    default:
        return u"disconnected"_s;
    }
}

QList<QDBusObjectPath> toPathList(const QVariant& v) {
    if (v.canConvert<QDBusArgument>())
        return qdbus_cast<QList<QDBusObjectPath>>(v.value<QDBusArgument>());
    return v.value<QList<QDBusObjectPath>>();
}

// Async call on NetworkManager; onReply runs with the finished call, then the watcher deletes itself
void callAsync(QObject* ctx, const QString& path, const QString& iface, const QString& method, const QVariantList& args,
    const std::function<void(const QDBusPendingCall&)>& onReply) {
    auto msg = QDBusMessage::createMethodCall(k_service, path, iface, method);
    msg.setArguments(args);
    // NOLINTBEGIN(clang-analyzer-cplusplus.NewDeleteLeaks) watcher is parented and self-deletes
    const auto* watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(msg), ctx);
    QObject::connect(watcher, &QDBusPendingCallWatcher::finished, ctx, [onReply](QDBusPendingCallWatcher* self) {
        onReply(*self);
        self->deleteLater();
    });
}

// NOLINTEND(clang-analyzer-cplusplus.NewDeleteLeaks)

} // namespace

NmVpn::NmVpn(QObject* parent)
    : QObject(parent) {
    qDBusRegisterMetaType<NMVariantMapMap>();

    auto bus = QDBusConnection::systemBus();
    if (!bus.isConnected()) {
        qCWarning(lcNmVpn) << "No system bus, NetworkManager VPNs unavailable";
        setLoaded();
        return;
    }

    bus.connect(
        k_service, k_settingsPath, k_settingsIface, u"NewConnection"_s, this, SLOT(onNewConnection(QDBusObjectPath)));
    bus.connect(k_service, k_settingsPath, k_settingsIface, u"ConnectionRemoved"_s, this,
        SLOT(onConnectionRemoved(QDBusObjectPath)));
    // Empty path = every object, so one hook covers all profiles / active connections
    bus.connect(k_service, QString(), k_connectionIface, u"Updated"_s, this, SLOT(onConnectionUpdated(QDBusMessage)));
    bus.connect(k_service, QString(), k_activeIface, u"StateChanged"_s, this, SLOT(onActiveStateChanged(QDBusMessage)));
    bus.connect(k_service, k_managerPath, k_propsIface, u"PropertiesChanged"_s, this,
        SLOT(onManagerPropertiesChanged(QString, QVariantMap, QStringList)));

    m_watcher = new QDBusServiceWatcher(
        k_service, bus, QDBusServiceWatcher::WatchForRegistration | QDBusServiceWatcher::WatchForUnregistration, this);
    connect(m_watcher, &QDBusServiceWatcher::serviceRegistered, this, &NmVpn::reload);
    connect(m_watcher, &QDBusServiceWatcher::serviceUnregistered, this, &NmVpn::clear);

    reload();
}

QVariantList NmVpn::connections() const {
    QHash<QString, uint> stateByUuid;
    for (const auto& a : m_active)
        stateByUuid.insert(a.uuid, a.state);

    QVariantList list;
    list.reserve(m_profiles.size());
    for (const auto& p : m_profiles) {
        list << QVariantMap{
            { u"uuid"_s, p.uuid },
            { u"name"_s, p.name },
            { u"kind"_s, p.kind },
            { u"interface"_s, p.iface },
            { u"state"_s, stateName(stateByUuid.value(p.uuid)) },
        };
    }
    return list;
}

void NmVpn::activate(const QString& uuid) {
    const auto it = std::ranges::find_if(m_profiles, [&](const Profile& p) {
        return p.uuid == uuid;
    });
    if (it == m_profiles.cend()) {
        emit activationFailed(uuid, u"Connection not found"_s);
        return;
    }

    const QDBusObjectPath none(u"/"_s);
    callAsync(this, k_managerPath, k_managerIface, u"ActivateConnection"_s,
        { QVariant::fromValue(QDBusObjectPath(it->path)), QVariant::fromValue(none), QVariant::fromValue(none) },
        [this, uuid](const QDBusPendingCall& pending) {
            const QDBusPendingReply<QDBusObjectPath> reply = pending;
            if (reply.isError()) {
                qCWarning(lcNmVpn) << "Failed to activate" << uuid << reply.error().message();
                emit activationFailed(uuid, reply.error().message());
            }
        });
}

void NmVpn::deactivate(const QString& uuid) {
    for (auto it = m_active.begin(); it != m_active.end(); ++it) {
        if (it->uuid != uuid)
            continue;
        it->reachedActivated = true; // a cancelled connect is not a failure
        callAsync(this, k_managerPath, k_managerIface, u"DeactivateConnection"_s,
            { QVariant::fromValue(QDBusObjectPath(it.key())) }, [this, uuid](const QDBusPendingCall& pending) {
                const QDBusPendingReply<> reply = pending;
                if (reply.isError()) {
                    qCWarning(lcNmVpn) << "Failed to deactivate" << uuid << reply.error().message();
                    emit deactivationFailed(uuid, reply.error().message());
                }
            });
    }
}

void NmVpn::reload() {
    // Startup calls (list, settings, active connections) tracked so `loaded` means the whole picture is in
    m_loading = true;
    m_pending = 2;
    callAsync(this, k_settingsPath, k_settingsIface, u"ListConnections"_s, {}, [this](const QDBusPendingCall& pending) {
        const QDBusPendingReply<QList<QDBusObjectPath>> reply = pending;
        if (reply.isError()) {
            qCWarning(lcNmVpn) << "Failed to list connections:" << reply.error().message();
        } else {
            const auto paths = reply.value();
            for (const auto& path : paths)
                loadProfile(path.path());
        }
        stepDone(); // NM missing: an empty list is the real answer
    });
    fetchActiveConnections();
}

void NmVpn::clear() {
    // NM is gone: not loaded until it comes back, so a saved NM selection isn't dropped meanwhile
    if (m_loaded) {
        m_loaded = false;
        emit loadedChanged();
    }
    if (m_profiles.isEmpty() && m_active.isEmpty())
        return;
    m_profiles.clear();
    m_active.clear();
    emit connectionsChanged();
}

void NmVpn::loadProfile(const QString& path) {
    if (m_loading)
        m_pending++;
    callAsync(this, path, k_connectionIface, u"GetSettings"_s, {}, [this, path](const QDBusPendingCall& pending) {
        const QDBusPendingReply<NMVariantMapMap> reply = pending;
        const auto existing = std::ranges::find_if(m_profiles, [&](const Profile& p) {
            return p.path == path;
        });

        if (!reply.isError()) {
            const auto settings = reply.value();
            const auto con = settings.value(u"connection"_s);
            const auto type = con.value(u"type"_s).toString();
            if (isVpnType(type)) {
                // e.g. org.freedesktop.NetworkManager.openvpn -> openvpn
                const auto kind = type == u"vpn"_s
                                      ? settings.value(u"vpn"_s).value(u"service-type"_s).toString().section(u'.', -1)
                                      : type;
                Profile p{
                    .path = path,
                    .uuid = con.value(u"uuid"_s).toString(),
                    .name = con.value(u"id"_s).toString(),
                    .kind = kind,
                    .iface = con.value(u"interface-name"_s).toString(),
                };
                if (existing != m_profiles.end())
                    *existing = std::move(p);
                else
                    m_profiles << std::move(p);
                emit connectionsChanged();
            } else if (existing != m_profiles.end()) {
                m_profiles.erase(existing);
                emit connectionsChanged();
            }
        }

        stepDone();
    });
}

void NmVpn::fetchActiveConnections() {
    callAsync(this, k_managerPath, k_propsIface, u"Get"_s, { k_managerIface, u"ActiveConnections"_s },
        [this](const QDBusPendingCall& pending) {
            const QDBusPendingReply<QDBusVariant> reply = pending;
            if (!reply.isError())
                setActiveConnections(toPathList(reply.value().variant()));
            stepDone();
        });
}

void NmVpn::setActiveConnections(const QList<QDBusObjectPath>& paths) {
    QStringList current;
    for (const auto& p : paths)
        current << p.path();

    bool changed = false;
    for (auto it = m_active.begin(); it != m_active.end();) {
        if (current.contains(it.key())) {
            ++it;
        } else {
            it = m_active.erase(it);
            changed = true;
        }
    }
    if (changed)
        emit connectionsChanged();

    for (const auto& path : std::as_const(current)) {
        if (m_active.contains(path))
            continue;
        if (m_loading)
            m_pending++;
        callAsync(
            this, path, k_propsIface, u"GetAll"_s, { k_activeIface }, [this, path](const QDBusPendingCall& pending) {
                const QDBusPendingReply<QVariantMap> reply = pending;
                const auto props = reply.isError() ? QVariantMap() : reply.value();
                const auto state = props.value(u"State"_s).toUInt();
                if (isVpnType(props.value(u"Type"_s).toString()) && state != k_deactivated) {
                    m_active.insert(path, {
                                              .uuid = props.value(u"Uuid"_s).toString(),
                                              .state = state,
                                              .reachedActivated = state == k_activated,
                                          });
                    emit connectionsChanged();
                }
                stepDone();
            });
    }
}

void NmVpn::stepDone() {
    if (m_loading && --m_pending <= 0) {
        m_loading = false;
        setLoaded();
    }
}

void NmVpn::setLoaded() {
    if (m_loaded)
        return;
    m_loaded = true;
    emit loadedChanged();
}

void NmVpn::onNewConnection(const QDBusObjectPath& path) {
    loadProfile(path.path());
}

void NmVpn::onConnectionRemoved(const QDBusObjectPath& path) {
    const auto removed = m_profiles.removeIf([&](const Profile& p) {
        return p.path == path.path();
    });
    if (removed > 0)
        emit connectionsChanged();
}

void NmVpn::onConnectionUpdated(const QDBusMessage& msg) {
    loadProfile(msg.path());
}

void NmVpn::onManagerPropertiesChanged(
    const QString& iface, const QVariantMap& changed, const QStringList& invalidated) {
    if (iface != k_managerIface)
        return;
    if (changed.contains(u"ActiveConnections"_s))
        setActiveConnections(toPathList(changed.value(u"ActiveConnections"_s)));
    else if (invalidated.contains(u"ActiveConnections"_s))
        fetchActiveConnections();
}

void NmVpn::onActiveStateChanged(const QDBusMessage& msg) {
    const auto it = m_active.find(msg.path());
    if (it == m_active.end() || msg.arguments().isEmpty())
        return;

    const auto state = msg.arguments().constFirst().toUInt();
    if (state == it->state)
        return;

    if (state == k_activated)
        it->reachedActivated = true;

    if (state == k_deactivated) {
        // Dropped before it ever came up = the connect attempt failed
        const auto uuid = it->uuid;
        const bool failed = !it->reachedActivated;
        m_active.erase(it);
        emit connectionsChanged();
        if (failed)
            emit activationFailed(uuid, u"NetworkManager could not bring the connection up"_s);
        return;
    }

    it->state = state;
    emit connectionsChanged();
}

} // namespace caelestia::shell::services
