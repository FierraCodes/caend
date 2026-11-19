pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("AI chat")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("General")
        }

        ToggleRow {
            first: true
            text: Tr.trCtx("Enabled", "toggle label")
            subtext: Tr.tr("Show the AI chat drawer on the left edge")
            checked: Config.ai.enabled
            onToggled: GlobalConfig.ai.enabled = checked
        }

        ToggleRow {
            text: Tr.tr("Show on hover")
            subtext: Tr.tr("Reveal when the cursor reaches the left edge")
            checked: Config.ai.showOnHover
            onToggled: GlobalConfig.ai.showOnHover = checked
        }

        StepperRow {
            last: true
            label: Tr.tr("Drag threshold")
            subtext: Tr.tr("Pixels dragged before the drawer opens")
            value: Config.ai.dragThreshold
            from: 0
            to: 300
            stepSize: 10
            onMoved: v => GlobalConfig.ai.dragThreshold = v
        }

        SectionHeader {
            text: Tr.tr("Model")
        }

        TextFieldRow {
            first: true
            label: Tr.tr("Model")
            subtext: Tr.tr("e.g. gemini-2.5-flash or openrouter:deepseek/deepseek-chat. Empty picks the first available")
            value: GlobalConfig.ai.model
            onEditingFinished: value => GlobalConfig.ai.model = value
        }

        StepperRow {
            label: Tr.tr("Temperature")
            subtext: Tr.tr("Higher is more creative, lower is more focused")
            value: Config.ai.temperature
            from: 0
            to: 2
            stepSize: 0.1
            onMoved: v => GlobalConfig.ai.temperature = Math.round(v * 10) / 10
        }

        TextFieldRow {
            label: Tr.tr("System prompt")
            subtext: Tr.tr("{DE}, {DISTRO}, {DATETIME} and {WINDOWCLASS} are filled in")
            value: GlobalConfig.ai.systemPrompt
            onEditingFinished: value => GlobalConfig.ai.systemPrompt = value
        }

        TextFieldRow {
            last: true
            label: Tr.tr("Ollama endpoint")
            subtext: Tr.tr("Local models are listed from here. Empty disables Ollama")
            value: GlobalConfig.ai.ollamaEndpoint
            placeholderText: "http://localhost:11434"
            onEditingFinished: value => GlobalConfig.ai.ollamaEndpoint = value
        }

        SectionHeader {
            text: Tr.tr("Keys and providers")
        }

        InfoRow {
            first: true
            last: true
            icon: "key"
            label: Tr.tr("API keys")
            subtext: Tr.tr("Type /key <provider> <key> in the chat. Keys are stored in your keyring. Custom providers go in ai.providers in shell.json")
        }
    }
}
