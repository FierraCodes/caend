#include "nmvpn.hpp"

#include <qdbusargument.h>
#include <qdbusconnection.h>
#include <qdbusextratypes.h>
#include <qdbusmetatype.h>
#include <qdbuspendingcall.h>
#include <qdbuspendingreply.h>
#include <qdbusservicewatcher.h>
#include <qloggingcategory.h>

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

QDBusMessage call(const QString& path, const QString& iface, const QString& method, const QVariantList& args = {}) {
    auto msg = QDBusMessage::createMethodCall(k_service, path, iface, method);
    msg.setArguments(args);
    return msg;
}

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

    bus.connect(k_service, k_settingsPath, k_settingsIface, u"NewConnection"_s, this,
        SLOT(onNewConnection(QDBusObjectPath)));
    bus.connect(k_service, k_settingsPath, k_settingsIface, u"ConnectionRemoved"_s, this,
        SLOT(onConnectionRemoved(QDBusObjectPath)));
    // Empty path = every object, so one hook covers all profiles / active connections
    bus.connect(k_service, QString(), k_connectionIface, u"Updated"_s, this, SLOT(onConnectionUpdated(QDBusMessage)));
    bus.connect(k_service, QString(), k_activeIface, u"StateChanged"_s, this, SLOT(onActiveStateChanged(QDBusMessage)));
    bus.connect(k_service, k_managerPath, k_propsIface, u"PropertiesChanged"_s, this,
        SLOT(onManagerPropertiesChanged(QString, QVariantMap, QStringList)));

    m_watcher = new QDBusServiceWatcher(k_service, bus,
        QDBusServiceWatcher::WatchForRegistration | QDBusServiceWatcher::WatchForUnregistration, this);
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
    const auto it = std::find_if(m_profiles.cbegin(), m_profiles.cend(), [&](const Profile& p) {
        return p.uuid == uuid;
    });
    if (it == m_profiles.cend()) {
        emit activationFailed(uuid, u"Connection not found"_s);
        return;
    }

    const QDBusObjectPath none(u"/"_s);
    auto* w = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(call(k_managerPath, k_managerIface,
                                              u"ActivateConnection"_s,
                                              { QVariant::fromValue(QDBusObjectPath(it->path)),
                                                  QVariant::fromValue(none), QVariant::fromValue(none) })),
        this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, uuid](QDBusPendingCallWatcher* self) {
        const QDBusPendingReply<QDBusObjectPath> reply = *self;
        if (reply.isError()) {
            qCWarning(lcNmVpn) << "Failed to activate" << uuid << reply.error().message();
            emit activationFailed(uuid, reply.error().message());
        }
        self->deleteLater();
    });
}

void NmVpn::deactivate(const QString& uuid) {
    for (auto it = m_active.begin(); it != m_active.end(); ++it) {
        if (it->uuid != uuid)
            continue;
        it->reachedActivated = true; // a cancelled connect is not a failure
        auto* w = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(call(k_managerPath, k_managerIface,
                                                  u"DeactivateConnection"_s,
                                                  { QVariant::fromValue(QDBusObjectPath(it.key())) })),
            this);
        connect(w, &QDBusPendingCallWatcher::finished, this, [uuid](QDBusPendingCallWatcher* self) {
            const QDBusPendingReply<> reply = *self;
            if (reply.isError())
                qCWarning(lcNmVpn) << "Failed to deactivate" << uuid << reply.error().message();
            self->deleteLater();
        });
    }
}

void NmVpn::reload() {
    // Startup calls (list, settings, active connections) tracked so `loaded` means the whole picture is in
    m_loading = true;
    m_pending = 2;
    auto* w = new QDBusPendingCallWatcher(
        QDBusConnection::systemBus().asyncCall(call(k_settingsPath, k_settingsIface, u"ListConnections"_s)), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher* self) {
        const QDBusPendingReply<QList<QDBusObjectPath>> reply = *self;
        self->deleteLater();
        if (reply.isError())
            qCWarning(lcNmVpn) << "Failed to list connections:" << reply.error().message();
        else
            for (const auto& path : reply.value())
                loadProfile(path.path());
        stepDone(); // NM missing: an empty list is the real answer
    });
    fetchActiveConnections();
}

void NmVpn::clear() {
    if (m_profiles.isEmpty() && m_active.isEmpty())
        return;
    m_profiles.clear();
    m_active.clear();
    emit connectionsChanged();
}

void NmVpn::loadProfile(const QString& path) {
    if (m_loading)
        m_pending++;
    auto* w = new QDBusPendingCallWatcher(
        QDBusConnection::systemBus().asyncCall(call(path, k_connectionIface, u"GetSettings"_s)), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, path](QDBusPendingCallWatcher* self) {
        const QDBusPendingReply<NMVariantMapMap> reply = *self;
        self->deleteLater();

        const auto existing = std::find_if(m_profiles.begin(), m_profiles.end(), [&](const Profile& p) {
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
                Profile p{ path, con.value(u"uuid"_s).toString(), con.value(u"id"_s).toString(), kind,
                    con.value(u"interface-name"_s).toString() };
                if (existing != m_profiles.end())
                    *existing = p;
                else
                    m_profiles << p;
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
    auto* w = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(
                                              call(k_managerPath, k_propsIface, u"Get"_s,
                                                  { k_managerIface, u"ActiveConnections"_s })),
        this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher* self) {
        const QDBusPendingReply<QDBusVariant> reply = *self;
        self->deleteLater();
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

    for (const auto& path : current) {
        if (m_active.contains(path))
            continue;
        if (m_loading)
            m_pending++;
        auto* w = new QDBusPendingCallWatcher(
            QDBusConnection::systemBus().asyncCall(call(path, k_propsIface, u"GetAll"_s, { k_activeIface })), this);
        connect(w, &QDBusPendingCallWatcher::finished, this, [this, path](QDBusPendingCallWatcher* self) {
            const QDBusPendingReply<QVariantMap> reply = *self;
            self->deleteLater();
            const auto props = reply.isError() ? QVariantMap() : reply.value();
            const auto state = props.value(u"State"_s).toUInt();
            if (isVpnType(props.value(u"Type"_s).toString()) && state != k_deactivated) {
                m_active.insert(path, { props.value(u"Uuid"_s).toString(), state, state == k_activated });
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
