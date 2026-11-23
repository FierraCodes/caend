#pragma once

#include <qnetworkaccessmanager.h>
#include <qobject.h>
#include <qqmlengine.h>

namespace caelestia::shell {

class Requests : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit Requests(QObject* parent = nullptr);

    Q_INVOKABLE void get(const QUrl& url, const QJSValue& onSuccess, const QJSValue& onError = QJSValue(),
        const QJSValue& headers = QJSValue()) const;
    // POSTs `body` and calls onLine(line) for every line of the response as it streams in, then
    // onDone(error, statusCode) once (error is "" on success). Returns the reply, which has abort().
    Q_INVOKABLE [[nodiscard]] QObject* stream(const QUrl& url, const QString& body, const QJSValue& onLine,
        const QJSValue& onDone = QJSValue(), const QJSValue& headers = QJSValue()) const;
    Q_INVOKABLE void resetCookies() const;

private:
    QNetworkAccessManager* m_manager;
};

} // namespace caelestia::shell
