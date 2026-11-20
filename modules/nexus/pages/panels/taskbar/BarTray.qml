pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Tray")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            first: true
            text: Tr.trCtx("Background", "taskbar tray: draw a background behind the tray")
            checked: Config.bar.tray.background
            onToggled: GlobalConfig.bar.tray.background = checked
        }

        ToggleRow {
            // TRANSLATORS: tint system tray icons with the theme accent colour
            text: Tr.tr("Recolour icons")
            checked: Config.bar.tray.recolour
            onToggled: GlobalConfig.bar.tray.recolour = checked
        }

        ToggleRow {
            text: Tr.trCtx("Compact", "taskbar tray layout")
            checked: Config.bar.tray.compact
            onToggled: GlobalConfig.bar.tray.compact = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Popout on hover")
            subtext: Tr.tr("Show the tray menu popout when hovering")
            checked: Config.bar.popouts.tray
            onToggled: GlobalConfig.bar.popouts.tray = checked
        }

        SectionHeader {
            text: Tr.tr("Pinned icons")
        }

        Repeater {
            id: trayItems

            model: SystemTray.items.values.filter(i => i.status !== Status.Passive)

            ToggleRow {
                required property SystemTrayItem modelData
                required property int index

                first: index === 0
                last: index === trayItems.count - 1
                text: modelData.title || modelData.id
                subtext: Tr.tr("Keep visible while the compact tray is collapsed")
                checked: Config.bar.tray.pinnedIcons.includes(modelData.id)
                onToggled: {
                    const others = GlobalConfig.bar.tray.pinnedIcons.filter(id => id !== modelData.id);
                    GlobalConfig.bar.tray.pinnedIcons = checked ? [...others, modelData.id] : others;
                }
            }
        }
    }
}
