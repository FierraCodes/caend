pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Launcher")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // General
        SectionHeader {
            first: true
            text: Tr.tr("General")
        }

        ToggleRow {
            first: true
            text: Tr.trCtx("Enabled", "toggle label")
            checked: Config.launcher.enabled
            onToggled: GlobalConfig.launcher.enabled = checked
        }

        ToggleRow {
            text: Tr.tr("Show on hover")
            subtext: Tr.tr("Reveal when the cursor reaches the screen edge")
            checked: Config.launcher.showOnHover
            onToggled: GlobalConfig.launcher.showOnHover = checked
        }

        ToggleRow {
            text: Tr.tr("Floating")
            subtext: Tr.tr("Float near the top of the screen like Spotlight, instead of rising from the bottom edge")
            checked: Config.launcher.floating
            onToggled: GlobalConfig.launcher.floating = checked
        }

        TextFieldRow {
            id: prefixRow

            last: true
            label: Tr.tr("Action prefix")
            subtext: Tr.tr("Prefix used to run actions in the launcher")
            errorText: Tr.tr("Prefix must not be alphanumeric")
            value: GlobalConfig.launcher.actionPrefix === "/" ? "" : GlobalConfig.launcher.actionPrefix // TODO: replace with empty only when not loaded once loaded state is exposed
            placeholderText: "/"
            maximumLength: 1
            smallField: true
            validate: /^[^a-zA-Z0-9\s]$/
            onEditingFinished: value => {
                if (!field.valid)
                    return;
                /// TODO: replace with GlobalConfig.launcher.resetOption("actionPrefix") on empty commit when reset is fixed
                GlobalConfig.launcher.actionPrefix = value || "/";
                if (GlobalConfig.launcher.actionPrefix === "/")
                    clear();
            }
        }

        // Search (end4-style prefixes)
        SectionHeader {
            text: Tr.tr("Search")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Show command, math and web results")
            subtext: Tr.tr("Add them to every search, not only when a prefix is typed")
            checked: GlobalConfig.launcher.showDefaultActionsWithoutPrefix
            onToggled: GlobalConfig.launcher.showDefaultActionsWithoutPrefix = checked
        }

        TextFieldRow {
            label: Tr.tr("Web search URL")
            subtext: Tr.tr("%s is replaced with the search")
            value: GlobalConfig.launcher.webSearchUrl
            placeholderText: "https://duckduckgo.com/?q=%s"
            onEditingFinished: value => GlobalConfig.launcher.webSearchUrl = value || "https://duckduckgo.com/?q=%s"
        }

        Repeater {
            model: [
                {
                    key: "appPrefix",
                    label: Tr.tr("Apps only")
                },
                {
                    key: "mathPrefix",
                    label: Tr.tr("Math")
                },
                {
                    key: "webPrefix",
                    label: Tr.tr("Web search")
                },
                {
                    key: "shellPrefix",
                    label: Tr.tr("Run command")
                },
                {
                    key: "clipboardPrefix",
                    label: Tr.tr("Clipboard history")
                },
                {
                    key: "emojiPrefix",
                    label: Tr.tr("Emoji")
                },
                {
                    key: "symbolPrefix",
                    label: Tr.tr("Material symbols")
                },
                {
                    key: "keybindPrefix",
                    label: Tr.tr("Keybinds")
                }
            ]

            TextFieldRow {
                required property var modelData
                required property int index

                last: index === 7
                label: Tr.tr("%1 prefix").arg(modelData.label)
                errorText: Tr.tr("Prefix must not be alphanumeric")
                value: GlobalConfig.launcher[modelData.key]
                maximumLength: 1
                smallField: true
                validate: /^[^a-zA-Z0-9\s]$/
                onEditingFinished: value => {
                    if (field.valid)
                        GlobalConfig.launcher[modelData.key] = value;
                }
            }
        }

        // Display
        SectionHeader {
            text: Tr.tr("Display")
        }

        StepperRow {
            first: true
            label: Tr.tr("Max items shown")
            value: Config.launcher.maxShown
            from: 1
            to: 20
            stepSize: 1
            onMoved: v => GlobalConfig.launcher.maxShown = v
        }

        StepperRow {
            label: Tr.tr("Max wallpapers")
            value: Config.launcher.maxWallpapers
            from: 1
            to: 30
            stepSize: 1
            onMoved: v => GlobalConfig.launcher.maxWallpapers = v
        }

        StepperRow {
            last: true
            label: Tr.tr("Drag threshold")
            subtext: Tr.tr("Pixels dragged before the launcher opens")
            value: Config.launcher.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.launcher.dragThreshold = v
        }

        // Behaviour
        SectionHeader {
            text: Tr.tr("Behaviour")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Vim keybinds")
            subtext: Tr.tr("Navigate results with Ctrl+hjkl")
            checked: GlobalConfig.launcher.vimKeybinds
            onToggled: GlobalConfig.launcher.vimKeybinds = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Enable dangerous actions")
            subtext: Tr.tr("Allow actions that shut down or log out")
            checked: GlobalConfig.launcher.enableDangerousActions
            onToggled: GlobalConfig.launcher.enableDangerousActions = checked
        }

        // Fuzzy search
        SectionHeader {
            text: Tr.tr("Fuzzy search")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Apps")
            checked: GlobalConfig.launcher.useFuzzy.apps
            onToggled: GlobalConfig.launcher.useFuzzy.apps = checked
        }

        ToggleRow {
            text: Tr.tr("Actions")
            checked: GlobalConfig.launcher.useFuzzy.actions
            onToggled: GlobalConfig.launcher.useFuzzy.actions = checked
        }

        ToggleRow {
            text: Tr.tr("Schemes")
            checked: GlobalConfig.launcher.useFuzzy.schemes
            onToggled: GlobalConfig.launcher.useFuzzy.schemes = checked
        }

        ToggleRow {
            text: Tr.tr("Variants")
            checked: GlobalConfig.launcher.useFuzzy.variants
            onToggled: GlobalConfig.launcher.useFuzzy.variants = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Wallpapers")
            checked: GlobalConfig.launcher.useFuzzy.wallpapers
            onToggled: GlobalConfig.launcher.useFuzzy.wallpapers = checked
        }
    }
}
