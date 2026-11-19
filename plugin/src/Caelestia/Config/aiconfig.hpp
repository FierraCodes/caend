#pragma once

#include "settings/objectnode.hpp"
#include "common.hpp"

using Qt::StringLiterals::operator""_s;

namespace caelestia::shell::config {

class AiConfig : public settings::ObjectNode {
    CONFIG_NODE(AiConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, showOnHover, false)
    CONFIG_PROPERTY(int, dragThreshold, 80)
    // Id of the selected model, e.g. "gemini-2.5-flash"; empty picks the first available
    CONFIG_PROPERTY(QString, model, {})
    CONFIG_PROPERTY(qreal, temperature, 0.5)
    // {DISTRO}, {DATETIME}, {WINDOWCLASS} and {DE} are substituted
    CONFIG_PROPERTY(QString, systemPrompt,
        u"You are a helpful assistant inside the user's Linux desktop shell ({DE} on {DISTRO}). It is {DATETIME}. "
        u"The focused window is {WINDOWCLASS}. Be concise and use Markdown."_s)
    // Local Ollama server; its installed models are listed automatically. Empty disables it.
    CONFIG_PROPERTY(QString, ollamaEndpoint, u"http://localhost:11434"_s)
    // Custom OpenAI-compatible providers: [{ "id", "name", "baseUrl", "keyless" (optional) }]
    // e.g. { "id": "together", "baseUrl": "https://api.together.xyz/v1" }, then /model together:<model-id>
    CONFIG_PROPERTY(QVariantList, providers, {})
    // Extra OpenAI-compatible models: [{ "name", "model", "endpoint", "keyId" (optional) }]
    CONFIG_PROPERTY(QVariantList, extraModels, {})
};

} // namespace caelestia::shell::config
