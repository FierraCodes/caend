#include "requests.hpp"

#include <qjsvalue.h>
#include <qjsvalueiterator.h>
#include <qloggingcategory.h>
#include <qnetworkaccessmanager.h>
#include <qnetworkcookiejar.h>
#include <qnetworkreply.h>
#include <qnetworkrequest.h>
#include <qqmlengine.h>
#include <qvariant.h>

#include <memory>

namespace {

Q_LOGGING_CATEGORY(lcRequests, "caelestia.requests", QtInfoMsg)

} // namespace

namespace caelestia::shell {

using Qt::StringLiterals::operator""_s;
using Qt::StringLiterals::operator""_ba;

namespace {

QVariantMap responseMetadata(const QNetworkReply* reply) {
    QVariantMap headers;

    for (const auto& [name, value] : reply->rawHeaderPairs()) {
        headers.insert(QString::fromLatin1(name).toLower(), QString::fromLatin1(value));
    }

    return {
        { u"statusCode"_s, reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() },
        { u"headers"_s, headers },
    };
}

} // namespace

Requests::Requests(QObject* parent)
    : QObject(parent)
    , m_manager(new QNetworkAccessManager(this)) {}

void Requests::get(const QUrl& url, const QJSValue& onSuccess, const QJSValue& onError, const QJSValue& headers) const {
    if (!onSuccess.isCallable()) {
        qCWarning(lcRequests) << "get: onSuccess is not callable";
        return;
    }

    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
    request.setAttribute(QNetworkRequest::CookieSaveControlAttribute, QNetworkRequest::Manual);
    request.setRawHeader("Cache-Control"_ba, "no-cache, no-store"_ba);
    request.setRawHeader("Pragma"_ba, "no-cache"_ba);
    request.setRawHeader("Connection"_ba, "close"_ba);

    if (headers.isObject()) {
        QJSValueIterator it(headers);
        while (it.hasNext()) {
            it.next();
            request.setRawHeader(it.name().toUtf8(), it.value().toString().toUtf8());
        }
    }

    auto* reply = m_manager->get(request);

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, onSuccess, onError] {
        const QString body = QString::fromUtf8(reply->readAll());

        QJSValue metadata;
        if (auto* engine = qmlEngine(this))
            metadata = engine->toScriptValue(responseMetadata(reply));

        if (reply->error() == QNetworkReply::NoError) {
            onSuccess.call({ body, metadata });
        } else if (onError.isCallable()) {
            onError.call({ reply->errorString(), metadata });
        } else {
            qCWarning(lcRequests) << "get: request failed with error" << reply->errorString();
        }

        reply->deleteLater();
    });
}

QObject* Requests::stream(const QUrl& url, const QString& body, const QJSValue& onLine, const QJSValue& onDone,
    const QJSValue& headers) const {
    if (!onLine.isCallable()) {
        qCWarning(lcRequests) << "stream: onLine is not callable";
        return nullptr;
    }

    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
    request.setHeader(QNetworkRequest::ContentTypeHeader, u"application/json"_s);

    if (headers.isObject()) {
        QJSValueIterator it(headers);
        while (it.hasNext()) {
            it.next();
            request.setRawHeader(it.name().toUtf8(), it.value().toString().toUtf8());
        }
    }

    auto* reply = m_manager->post(request, body.toUtf8());
    QQmlEngine::setObjectOwnership(reply, QQmlEngine::CppOwnership);

    // Holds a partial line between chunks
    const auto buffer = std::make_shared<QByteArray>();
    const auto emitLines = [buffer, onLine](bool flush) {
        qsizetype newline;
        while ((newline = buffer->indexOf('\n')) >= 0) {
            QJSValue(onLine).call({ QString::fromUtf8(buffer->left(newline)).trimmed() });
            buffer->remove(0, newline + 1);
        }
        if (flush && !buffer->trimmed().isEmpty()) {
            QJSValue(onLine).call({ QString::fromUtf8(*buffer).trimmed() });
            buffer->clear();
        }
    };

    QObject::connect(reply, &QNetworkReply::readyRead, this, [reply, buffer, emitLines] {
        buffer->append(reply->readAll());
        emitLines(false);
    });

    QObject::connect(reply, &QNetworkReply::finished, this, [reply, buffer, emitLines, onDone] {
        buffer->append(reply->readAll());
        emitLines(true);

        if (onDone.isCallable()) {
            const auto error = reply->error() == QNetworkReply::NoError ? QString() : reply->errorString();
            QJSValue(onDone).call({ error, reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() });
        }

        reply->deleteLater();
    });

    return reply;
}

void Requests::resetCookies() const {
    m_manager->setCookieJar(new QNetworkCookieJar(m_manager));
}

} // namespace caelestia::shell
