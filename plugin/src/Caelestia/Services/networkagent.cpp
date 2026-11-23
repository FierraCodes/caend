#include "networkagent.hpp"

#include <qdbusmetatype.h>
#include <qdbuspendingcall.h>
#include <qdbuspendingreply.h>
#include <qdbusservicewatcher.h>
#include <qloggingcategory.h>

namespace {

Q_LOGGING_CATEGORY(lcNetworkAgent, "caelestia.services.networkagent", QtInfoMsg)

} // namespace

namespace caelestia::shell::services {

using Qt::StringLiterals::operator""_s;

namespace {

const QString k_nmService = u"org.freedesktop.NetworkManager"_s;
const QString k_agentPath = u"/org/freedesktop/NetworkManager/SecretAgent"_s;
const QString k_errorNoSecrets = u"org.freedesktop.NetworkManager.SecretAgent.NoSecrets"_s;
const QString k_errorCanceled = u"org.freedesktop.NetworkManager.SecretAgent.UserCanceled"_s;

constexpr uint k_allowInteraction = 0x1;
constexpr uint k_requestNew = 0x2;

// Which secrets a setting needs, given the connection NM sent
QStringList fieldsFor(const QString& setting, const NMVariantMapMap& connection, QVariantMap& prefill) {
    if (setting == u"802-11-wireless-security"_s) {
        const auto sec = connection.value(setting);
        const auto keyMgmt = sec.value(u"key-mgmt"_s).toString();
        if (keyMgmt == u"none"_s)
            return { u"wep-key0"_s };
        if (keyMgmt == u"wpa-psk"_s || keyMgmt == u"sae"_s)
            return { u"psk"_s };
        return {};
    }
    if (setting == u"802-1x"_s) {
        const auto x = connection.value(setting);
        const auto eap = x.value(u"eap"_s).toStringList();
        prefill.insert(u"identity"_s, x.value(u"identity"_s));
        if (eap.contains(u"tls"_s))
            return { u"identity"_s, u"private-key-password"_s };
        return { u"identity"_s, u"password"_s }; // peap, ttls, leap, pwd...
    }
    return {};
}

} // namespace

NetworkAgent::NetworkAgent(QObject* parent)
    : QObject(parent) {
    qDBusRegisterMetaType<NMVariantMapMap>();

    auto bus = QDBusConnection::systemBus();
    if (!bus.isConnected()) {
        qCWarning(lcNetworkAgent) << "No system bus, network prompts disabled";
        return;
    }
    if (!bus.registerObject(k_agentPath, this, QDBusConnection::ExportScriptableSlots)) {
        qCWarning(lcNetworkAgent) << "Could not export secret agent:" << bus.lastError().message();
        return;
    }

    // Register again whenever NetworkManager (re)starts
    m_watcher = new QDBusServiceWatcher(k_nmService, bus, QDBusServiceWatcher::WatchForRegistration, this);
    connect(m_watcher, &QDBusServiceWatcher::serviceRegistered, this, &NetworkAgent::registerAgent);
    registerAgent();
}

void NetworkAgent::registerAgent() {
    auto msg = QDBusMessage::createMethodCall(k_nmService, u"/org/freedesktop/NetworkManager/AgentManager"_s,
        u"org.freedesktop.NetworkManager.AgentManager"_s, u"Register"_s);
    msg << u"caelestia.shell"_s;
    const auto* watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(msg), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [](QDBusPendingCallWatcher* self) {
        const QDBusPendingReply<> reply = *self;
        if (reply.isError())
            qCWarning(lcNetworkAgent) << "Could not register with NetworkManager:" << reply.error().message();
        self->deleteLater();
    });
}

NMVariantMapMap NetworkAgent::GetSecrets(const NMVariantMapMap& connection, const QDBusObjectPath& connectionPath,
    const QString& settingName, const QStringList& hints, uint flags, const QDBusMessage& message) {
    Q_UNUSED(hints)

    QVariantMap prefill;
    const auto fields = fieldsFor(settingName, connection, prefill);
    if (!(flags & k_allowInteraction) || fields.isEmpty()) {
        QDBusConnection::systemBus().send(message.createErrorReply(k_errorNoSecrets, u"No secrets available"_s));
        return {};
    }

    if (m_active)
        replyError(k_errorCanceled, u"Superseded by a new request"_s);

    message.setDelayedReply(true);
    m_pending = message;
    m_retry = flags & k_requestNew;
    m_path = connectionPath.path();
    m_settingName = settingName;
    m_fields = fields;
    m_prefill = prefill;
    m_connectionName = connection.value(u"connection"_s).value(u"id"_s).toString();
    m_active = true;
    emit requestChanged();
    return {};
}

void NetworkAgent::CancelGetSecrets(const QDBusObjectPath& connectionPath, const QString& settingName) {
    if (m_active && connectionPath.path() == m_path && settingName == m_settingName)
        replyError(k_errorCanceled, u"Cancelled by NetworkManager"_s);
}

void NetworkAgent::SaveSecrets(const NMVariantMapMap& /*connection*/, const QDBusObjectPath& /*connectionPath*/) {}

void NetworkAgent::DeleteSecrets(const NMVariantMapMap& /*connection*/, const QDBusObjectPath& /*connectionPath*/) {}

void NetworkAgent::submit(const QVariantMap& secrets) {
    if (!m_active)
        return;
    NMVariantMapMap reply;
    reply.insert(m_settingName, secrets);
    QDBusConnection::systemBus().send(m_pending.createReply(QVariant::fromValue(reply)));
    finish();
}

void NetworkAgent::cancel() {
    if (m_active)
        replyError(k_errorCanceled, u"Cancelled by the user"_s);
}

void NetworkAgent::replyError(const QString& name, const QString& text) {
    QDBusConnection::systemBus().send(m_pending.createErrorReply(name, text));
    finish();
}

void NetworkAgent::finish() {
    m_active = false;
    m_pending = {};
    emit requestChanged();
}

} // namespace caelestia::shell::services
