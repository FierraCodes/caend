pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n

// LLM chat for the AI sidebar. Requests stream through Caelestia's C++ HTTP client (no curl or scripts);
// API keys live in the desktop keyring via secret-tool and never touch disk or process arguments.
// Formats: "gemini" (Google) and "openai" (OpenAI-compatible: OpenRouter, OpenAI, Anthropic, Mistral, Groq,
// DeepSeek, xAI, Ollama, extra models).
Singleton {
    id: root

    readonly property string interfaceRole: "interface"

    // [{ role: "user" | "assistant" | "interface", content: string, model: string, done: bool }]
    property list<var> messages: []
    property var reply: null // In-flight request, has abort()
    readonly property bool busy: reply !== null

    property var apiKeys: ({})
    property bool keysLoaded

    // Every provider takes any of its model ids as "provider:model", e.g. "openrouter:openai/gpt-4o".
    // format "openai" means an OpenAI-compatible chat completions endpoint.
    readonly property var providers: {
        const list = {
            gemini: {
                name: "Gemini",
                format: "gemini",
                keyLink: "https://aistudio.google.com/app/apikey"
            },
            openrouter: {
                name: "OpenRouter",
                format: "openai",
                endpoint: "https://openrouter.ai/api/v1/chat/completions",
                keyLink: "https://openrouter.ai/keys"
            },
            openai: {
                name: "OpenAI",
                format: "openai",
                endpoint: "https://api.openai.com/v1/chat/completions",
                keyLink: "https://platform.openai.com/api-keys"
            },
            anthropic: {
                name: "Anthropic",
                format: "openai",
                endpoint: "https://api.anthropic.com/v1/chat/completions",
                keyLink: "https://console.anthropic.com/settings/keys"
            },
            mistral: {
                name: "Mistral",
                format: "openai",
                endpoint: "https://api.mistral.ai/v1/chat/completions",
                keyLink: "https://console.mistral.ai/api-keys"
            },
            groq: {
                name: "Groq",
                format: "openai",
                endpoint: "https://api.groq.com/openai/v1/chat/completions",
                keyLink: "https://console.groq.com/keys"
            },
            deepseek: {
                name: "DeepSeek",
                format: "openai",
                endpoint: "https://api.deepseek.com/chat/completions",
                keyLink: "https://platform.deepseek.com/api_keys"
            },
            xai: {
                name: "xAI",
                format: "openai",
                endpoint: "https://api.x.ai/v1/chat/completions",
                keyLink: "https://console.x.ai"
            },
            ollama: {
                name: "Ollama",
                format: "openai",
                endpoint: `${GlobalConfig.ai.ollamaEndpoint.replace(/\/+$/, "")}/v1/chat/completions`,
                keyless: true
            }
        };
        for (const p of GlobalConfig.ai.providers) {
            const base = (p?.baseUrl ?? p?.endpoint ?? "").replace(/\/+$/, "");
            if (!p?.id || !base)
                continue;
            list[p.id] = {
                name: p.name ?? p.id,
                format: "openai",
                endpoint: base.endsWith("/chat/completions") ? base : `${base}/chat/completions`,
                keyless: p.keyless ?? false
            };
        }
        return list;
    }

    // Shown by /model; any other "provider:model" id works too
    property list<var> ollamaModels: []
    readonly property var models: {
        const list = ["gemini:gemini-2.5-flash", "gemini:gemini-2.5-pro", "openrouter:openrouter/auto", "mistral:mistral-medium-latest", "mistral:mistral-small-latest", ...ollamaModels].map(id => resolveModel(id));
        for (const m of GlobalConfig.ai.extraModels) {
            if (!m?.model || !m?.endpoint)
                continue;
            list.push({
                id: m.id ?? m.model,
                name: m.name ?? m.model,
                format: "openai",
                model: m.model,
                endpoint: m.endpoint,
                keyId: m.keyId ?? ""
            });
        }
        return list;
    }
    readonly property var currentModel: models.find(m => m.id === GlobalConfig.ai.model) ?? resolveModel(GlobalConfig.ai.model) ?? models[0]

    readonly property string systemPrompt: {
        const subs = {
            "{DISTRO}": osRelease.prettyName,
            "{DATETIME}": Time.format("dddd d MMMM yyyy, hh:mm"),
            "{WINDOWCLASS}": Compositor.activeWindowAppId || "none",
            "{DE}": Compositor.name
        };
        let prompt = GlobalConfig.ai.systemPrompt;
        for (const key in subs)
            prompt = prompt.split(key).join(subs[key]);
        return prompt;
    }

    // "provider:model" -> model object, or null if the provider is unknown
    function resolveModel(id: string): var {
        const sep = id.indexOf(":");
        const providerId = sep > 0 ? id.slice(0, sep) : "";
        const provider = providers[providerId];
        const model = id.slice(sep + 1);
        if (!provider || !model)
            return null;
        return {
            id,
            name: `${provider.name} ${model}`,
            format: provider.format,
            model,
            endpoint: provider.format === "gemini" ? `https://generativelanguage.googleapis.com/v1beta/models/${model}:streamGenerateContent?alt=sse` : provider.endpoint,
            keyId: provider.keyless ? "" : providerId,
            keyLink: provider.keyLink
        };
    }

    function addMessage(content: string, role: string): void {
        messages = [...messages, {
                role,
                content,
                model: "",
                done: true
            }];
    }

    function clear(): void {
        stop();
        messages = [];
    }

    function stop(): void {
        const r = reply;
        reply = null; // Marks the request as cancelled for its done callback
        r?.abort();
    }

    // Text starting with "/" is a local command, anything else goes to the model
    function send(text: string): void {
        text = text.trim();
        if (!text || busy)
            return;
        if (text.startsWith("/")) {
            runCommand(text);
            return;
        }
        addMessage(text, "user");
        request();
    }

    function runCommand(text: string): void {
        const [cmd, ...rest] = text.slice(1).split(/\s+/);
        const arg = rest.join(" ");

        if (cmd === "clear") {
            clear();
        } else if (cmd === "model") {
            const match = models.find(m => m.id.toLowerCase() === arg.toLowerCase()) ?? resolveModel(arg);
            if (match) {
                GlobalConfig.ai.model = match.id;
                addMessage(Tr.tr("Model set to %1").arg(match.name), interfaceRole);
                if (match.keyId && keysLoaded && !apiKeys[match.keyId])
                    addKeyAdvice(match);
            } else {
                addMessage(Tr.tr("Models:\n\n%1\n\nAny model works as `/model provider:model-id`, e.g. `/model openrouter:openai/gpt-4o`. Providers: %2").arg(models.map(m => `- \`${m.id}\``).join("\n")).arg(Object.keys(providers).join(", ")), interfaceRole);
            }
        } else if (cmd === "key") {
            const model = currentModel;
            if (!model.keyId)
                addMessage(Tr.tr("%1 does not need an API key").arg(model.name), interfaceRole);
            else if (!arg)
                addKeyAdvice(model);
            else
                setKey(model.keyId, arg);
        } else if (cmd === "temp") {
            const value = parseFloat(arg);
            if (isNaN(value) || value < 0 || value > 2) {
                addMessage(Tr.tr("Temperature is %1. Set it with `/temp 0-2`").arg(GlobalConfig.ai.temperature), interfaceRole);
            } else {
                GlobalConfig.ai.temperature = value;
                addMessage(Tr.tr("Temperature set to %1").arg(value), interfaceRole);
            }
        } else if (cmd === "prompt") {
            addMessage(Tr.tr("System prompt:\n\n%1").arg(systemPrompt), interfaceRole);
        } else {
            addMessage(Tr.tr("Commands: `/model [id]`, `/key <key>`, `/temp [0-2]`, `/prompt`, `/clear`"), interfaceRole);
        }
    }

    function addKeyAdvice(model: var): void {
        addMessage(Tr.tr("%1 needs an API key. Get one at %2 and send `/key <your key>`. It is stored in your keyring.").arg(model.name).arg(model.keyLink ?? Tr.tr("the provider's site")), interfaceRole);
    }

    function setKey(keyId: string, key: string): void {
        apiKeys = Object.assign({}, apiKeys, {
            [keyId]: key.trim()
        });
        keyStore.stdinEnabled = true;
        keyStore.running = true;
        addMessage(Tr.tr("API key saved"), interfaceRole);
    }

    function request(): void {
        const model = currentModel;
        const key = model.keyId ? apiKeys[model.keyId] : "";
        if (model.keyId && !key) {
            addKeyAdvice(model);
            return;
        }

        const history = messages.filter(m => m.role !== interfaceRole);
        const temperature = GlobalConfig.ai.temperature;
        let body, headers;
        if (model.format === "gemini") {
            body = {
                contents: history.map(m => ({
                            role: m.role === "assistant" ? "model" : "user",
                            parts: [
                                {
                                    text: m.content
                                }
                            ]
                        })),
                system_instruction: {
                    parts: [
                        {
                            text: systemPrompt
                        }
                    ]
                },
                generationConfig: {
                    temperature
                }
            };
            headers = {
                "x-goog-api-key": key
            };
        } else {
            body = {
                model: model.model,
                stream: true,
                temperature,
                messages: [
                    {
                        role: "system",
                        content: systemPrompt
                    },
                    ...history.map(m => ({
                                role: m.role,
                                content: m.content
                            }))
                ]
            };
            headers = key ? {
                Authorization: `Bearer ${key}`
            } : {};
        }

        const index = messages.length;
        messages = [...messages, {
                role: "assistant",
                content: "",
                model: model.name,
                done: false
            }];

        let raw = ""; // Non-SSE output, i.e. an error body
        reply = Requests.stream(model.endpoint, JSON.stringify(body), line => {
            if (!line.startsWith("data:")) {
                raw += line;
                return;
            }
            const data = line.slice(5).trim();
            if (data === "[DONE]")
                return;
            try {
                const json = JSON.parse(data);
                const chunk = model.format === "gemini" ? (json.candidates?.[0]?.content?.parts ?? []).map(p => p.text ?? "").join("") : json.choices?.[0]?.delta?.content ?? "";
                const error = json.error?.message;
                appendTo(index, error ? `\n\n**${Tr.tr("Error")}**: ${error}` : chunk);
            } catch (e) {
                raw += data;
            }
        }, (error, status) => {
            if (root.reply === null) { // Stopped by the user
                finish(index);
                return;
            }
            if (error || !messages[index]?.content) {
                let detail = raw;
                try {
                    const json = JSON.parse(raw);
                    detail = (Array.isArray(json) ? json[0] : json)?.error?.message ?? raw;
                } catch (e) {}
                appendTo(index, `**${Tr.tr("Error")}${status ? ` ${status}` : ""}**: ${detail || error || Tr.tr("empty response")}`);
                if (status === 400 || status === 401 || status === 403)
                    addKeyAdvice(model);
            }
            finish(index);
        }, headers);
    }

    function appendTo(index: int, text: string): void {
        if (!text || !messages[index])
            return;
        const next = [...messages];
        next[index] = Object.assign({}, next[index], {
            content: next[index].content + text
        });
        messages = next;
    }

    function finish(index: int): void {
        reply = null;
        if (!messages[index])
            return;
        const next = [...messages];
        next[index] = Object.assign({}, next[index], {
            done: true
        });
        messages = next;
    }

    function refreshOllama(): void {
        const base = GlobalConfig.ai.ollamaEndpoint.replace(/\/+$/, "");
        if (!base) {
            ollamaModels = [];
            return;
        }
        Requests.get(`${base}/api/tags`, text => {
            try {
                ollamaModels = JSON.parse(text).models.map(m => `ollama:${m.name}`);
            } catch (e) {
                ollamaModels = [];
            }
        }, () => ollamaModels = []);
    }

    Component.onCompleted: {
        keyLookup.running = true;
        refreshOllama();
    }

    Connections {
        function onOllamaEndpointChanged(): void {
            root.refreshOllama();
        }

        target: GlobalConfig.ai
    }

    Process {
        id: keyLookup

        command: ["secret-tool", "lookup", "application", "caend", "type", "ai-keys"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.apiKeys = text.trim() ? JSON.parse(text) : {};
                } catch (e) {
                    console.warn("[Ai] Keyring entry is not valid JSON, ignoring it");
                }
                root.keysLoaded = true;
            }
        }
    }

    Process {
        id: keyStore

        command: ["secret-tool", "store", "--label=caend AI keys", "application", "caend", "type", "ai-keys"]
        onRunningChanged: {
            if (!running)
                return;
            write(JSON.stringify(root.apiKeys));
            stdinEnabled = false; // Closes stdin so secret-tool saves
        }
    }

    FileView {
        id: osRelease

        readonly property string prettyName: text().match(/^PRETTY_NAME="?([^"\n]*)"?/m)?.[1] ?? "Linux"

        path: "/etc/os-release"
    }
}
