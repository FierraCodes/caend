#pragma once

#include <qdbusconnection.h>
#include <qdbusextratypes.h>
#include <qdbusmessage.h>
#include <qmap.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qstring.h>
#include <qstringlist.h>
#include <qvariant.h>

class QDBusServiceWatcher;

namespace caelestia::shell::services {

using NMVariantMapMap = QMap<QString, QVariantMap>;

// NetworkManager secret agent: NM asks it for Wi-Fi / 802.1X secrets and the shell shows the prompt.
class NetworkAgent : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.NetworkManager.SecretAgent")
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool active READ active NOTIFY requestChanged)
    Q_PROPERTY(QString connectionName READ connectionName NOTIFY requestChanged)
    Q_PROPERTY(QString settingName READ settingName NOTIFY requestChanged)
    // Secret keys to ask for, e.g. ["psk"] or ["identity", "password"]
    Q_PROPERTY(QStringList fields READ fields NOTIFY requestChanged)
    // Values already known for those keys (e.g. the 802.1X identity)
    Q_PROPERTY(QVariantMap prefill READ prefill NOTIFY requestChanged)
    // NM wants new secrets, i.e. the saved or last entered ones were wrong
    Q_PROPERTY(bool retry READ retry NOTIFY requestChanged)

public:
    explicit NetworkAgent(QObject* parent = nullptr);

    [[nodiscard]] bool active() const { return m_active; }

    [[nodiscard]] QString connectionName() const { return m_connectionName; }

    [[nodiscard]] QString settingName() const { return m_settingName; }

    [[nodiscard]] QStringList fields() const { return m_fields; }

    [[nodiscard]] QVariantMap prefill() const { return m_prefill; }

    [[nodiscard]] bool retry() const { return m_retry; }

    Q_INVOKABLE void submit(const QVariantMap& secrets);
    Q_INVOKABLE void cancel();

public slots:
    // D-Bus: org.freedesktop.NetworkManager.SecretAgent, so the names are fixed by the interface
    // NOLINTBEGIN(readability-identifier-naming)
    Q_SCRIPTABLE NMVariantMapMap GetSecrets(const NMVariantMapMap& connection, const QDBusObjectPath& connectionPath,
        const QString& settingName, const QStringList& hints, uint flags, const QDBusMessage& message);
    Q_SCRIPTABLE void CancelGetSecrets(const QDBusObjectPath& connectionPath, const QString& settingName);
    Q_SCRIPTABLE void SaveSecrets(const NMVariantMapMap& connection, const QDBusObjectPath& connectionPath);
    Q_SCRIPTABLE void DeleteSecrets(const NMVariantMapMap& connection, const QDBusObjectPath& connectionPath);
    // NOLINTEND(readability-identifier-naming)

signals:
    void requestChanged();

private:
    void registerAgent();
    void finish();
    void replyError(const QString& name, const QString& text);

    bool m_active = false;
    bool m_retry = false;
    QString m_connectionName;
    QString m_settingName;
    QString m_path;
    QStringList m_fields;
    QVariantMap m_prefill;
    QDBusMessage m_pending;
    QDBusServiceWatcher* m_watcher = nullptr;
};

} // namespace caelestia::shell::services

Q_DECLARE_METATYPE(caelestia::shell::services::NMVariantMapMap)
