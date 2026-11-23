#include "networkagent.hpp"

#include <qdbusargument.h>
#include <qdbusmetatype.h>
#include <qdbuspendingcall.h>
#include <qdbuspendingreply.h>
#include <qdbusservicewatcher.h>
#include <qdir.h>
#include <qloggingcategory.h>
#include <qprocess.h>
#include <qsettings.h>

#include <utility>

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

// The auth dialog a VPN plugin ships, from its .name file, e.g. /usr/lib/nm-openconnect-auth-dialog
QString authDialogFor(const QString& service) {
    // shortcut: only the usual plugin dirs, add more if a distro installs .name files elsewhere
    for (const auto& path : { u"/etc/NetworkManager/VPN"_s, u"/usr/lib/NetworkManager/VPN"_s }) {
        const QDir dir(path);
        const auto files = dir.entryList({ u"*.name"_s }, QDir::Files);
        for (const auto& file : files) {
            const QSettings ini(dir.filePath(file), QSettings::IniFormat);
            if (ini.value(u"VPN Connection/service"_s).toString() == service)
                return ini.value(u"GNOME/auth-dialog"_s).toString();
        }
    }
    return {};
}

// vpn.data and vpn.secrets are a{ss}, which arrive still marshalled inside the a{sv}
NMStringMap stringMap(const QVariant& value) {
    if (value.canConvert<QDBusArgument>())
        return qdbus_cast<NMStringMap>(value.value<QDBusArgument>());
    return value.value<NMStringMap>();
}

} // namespace

NetworkAgent::NetworkAgent(QObject* parent)
    : QObject(parent) {
    qDBusRegisterMetaType<NMVariantMapMap>();
    qDBusRegisterMetaType<NMStringMap>();

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

    if (settingName == u"vpn"_s) {
        startVpnDialog(connection, connectionPath.path(), flags, message);
        return {};
    }

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
    if (m_vpnDialog && connectionPath.path() == m_vpnPath && settingName == u"vpn"_s)
        finishVpn(m_vpnPending.createErrorReply(k_errorCanceled, u"Cancelled by NetworkManager"_s));
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

// Speaks the auth-dialog protocol: VPN data and saved secrets go in on stdin, the dialog prints
// "key\nvalue\n" pairs then a blank line, and waits for QUIT.
void NetworkAgent::startVpnDialog(
    const NMVariantMapMap& connection, const QString& path, uint flags, const QDBusMessage& message) {
    const auto vpn = connection.value(u"vpn"_s);
    const auto service = vpn.value(u"service-type"_s).toString();
    const auto dialog = authDialogFor(service);
    if (!(flags & k_allowInteraction) || dialog.isEmpty()) {
        if (dialog.isEmpty())
            qCWarning(lcNetworkAgent) << "No auth dialog installed for" << service;
        QDBusConnection::systemBus().send(message.createErrorReply(k_errorNoSecrets, u"No secrets available"_s));
        return;
    }

    if (m_vpnDialog)
        finishVpn(m_vpnPending.createErrorReply(k_errorCanceled, u"Superseded by a new request"_s));

    message.setDelayedReply(true);
    m_vpnPending = message;
    m_vpnPath = path;

    const auto conn = connection.value(u"connection"_s);
    QStringList args{
        u"-u"_s,
        conn.value(u"uuid"_s).toString(),
        u"-n"_s,
        conn.value(u"id"_s).toString(),
        u"-s"_s,
        service,
        u"-i"_s,
    };
    if (flags & k_requestNew)
        args << u"-r"_s;

    auto* proc = new QProcess(this);
    m_vpnDialog = proc;

    connect(proc, &QProcess::readyReadStandardOutput, this, [this, proc] {
        // Peek: the reply is complete once a blank line follows the last pair
        const auto out = QString::fromUtf8(proc->peek(proc->bytesAvailable()));
        if (proc != m_vpnDialog || (out != u"\n\n"_s && !out.contains(u"\n\n\n"_s)))
            return;
        proc->readAll();

        NMStringMap secrets;
        const auto lines = out.split(u'\n');
        for (qsizetype i = 0; i + 1 < lines.size() && !lines.at(i).isEmpty(); i += 2)
            secrets.insert(lines.at(i), lines.at(i + 1));
        proc->write("QUIT\n\n");

        NMVariantMapMap reply;
        reply.insert(u"vpn"_s, QVariantMap{ { u"secrets"_s, QVariant::fromValue(secrets) } });
        finishVpn(m_vpnPending.createReply(QVariant::fromValue(reply)));
    });
    connect(proc, &QProcess::finished, this, [this, proc] {
        if (proc == m_vpnDialog)
            finishVpn(m_vpnPending.createErrorReply(k_errorCanceled, u"Auth dialog closed"_s));
        proc->deleteLater();
    });
    connect(proc, &QProcess::errorOccurred, this, [this, proc](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart)
            return;
        qCWarning(lcNetworkAgent) << "Could not start" << proc->program();
        if (proc == m_vpnDialog)
            finishVpn(m_vpnPending.createErrorReply(k_errorNoSecrets, u"Auth dialog failed to start"_s));
        proc->deleteLater();
    });

    proc->start(dialog, args);

    QByteArray input;
    const auto data = stringMap(vpn.value(u"data"_s));
    for (auto it = data.cbegin(); it != data.cend(); ++it)
        input += "DATA_KEY=" + it.key().toUtf8() + "\nDATA_VAL=" + it.value().toUtf8() + "\n\n";
    const auto saved = stringMap(vpn.value(u"secrets"_s));
    for (auto it = saved.cbegin(); it != saved.cend(); ++it)
        input += "SECRET_KEY=" + it.key().toUtf8() + "\nSECRET_VAL=" + it.value().toUtf8() + "\n\n";
    proc->write(input + "DONE\n\n");
}

void NetworkAgent::finishVpn(const QDBusMessage& reply) {
    QDBusConnection::systemBus().send(reply);
    // Detach first so the dialog's own exit doesn't answer NM a second time
    auto* proc = std::exchange(m_vpnDialog, nullptr);
    m_vpnPending = {};
    if (proc && proc->state() != QProcess::NotRunning && !reply.errorName().isEmpty())
        proc->terminate();
}

} // namespace caelestia::shell::services
