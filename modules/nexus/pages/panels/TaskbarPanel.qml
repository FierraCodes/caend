pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var entryNames: ({
            logo: Tr.tr("Logo"),
            workspaces: Tr.tr("Workspaces"),
            spacer: Tr.tr("Spacer"),
            activeWindow: Tr.tr("Active window"),
            tray: Tr.tr("Tray"),
            media: Tr.tr("Media"),
            resources: Tr.tr("Resources"),
            weather: Tr.tr("Weather"),
            utilButtons: Tr.tr("Util buttons"),
            clock: Tr.tr("Clock"),
            statusIcons: Tr.tr("Status icons"),
            power: Tr.tr("Power button")
        })

    readonly property list<MenuItem> positionItems: [
        MenuItem {
            text: Tr.trCtx("Left", "bar position")
            icon: "align_horizontal_left"
        },
        MenuItem {
            text: Tr.trCtx("Right", "bar position")
            icon: "align_horizontal_right"
        },
        MenuItem {
            text: Tr.trCtx("Top", "bar position")
            icon: "align_vertical_top"
        },
        MenuItem {
            text: Tr.trCtx("Bottom", "bar position")
            icon: "align_vertical_bottom"
        }
    ]
    readonly property list<string> positionValues: ["left", "right", "top", "bottom"]
    readonly property list<MenuItem> cornerItems: [
        MenuItem {
            text: Tr.trCtx("Hug", "bar corner style")
            icon: "rounded_corner"
        },
        MenuItem {
            text: Tr.trCtx("Float", "bar corner style")
            icon: "padding"
        },
        MenuItem {
            text: Tr.trCtx("Plain", "bar corner style")
            icon: "crop_square"
        }
    ]
    readonly property list<string> cornerValues: ["hug", "float", "plain"]

    title: Tr.tr("Taskbar")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Behaviour
        SectionHeader {
            first: true
            text: Tr.tr("Behaviour")
        }

        SelectRow {
            first: true
            label: Tr.tr("Position")
            subtext: Tr.tr("Which screen edge the bar sits on")
            menuItems: root.positionItems
            active: root.positionItems[Math.max(0, root.positionValues.indexOf(GlobalConfig.bar.position))]
            onSelected: item => GlobalConfig.bar.position = root.positionValues[root.positionItems.indexOf(item)]
        }

        SelectRow {
            label: Tr.tr("Corner style")
            subtext: Tr.tr("Hug the screen frame, float as a pill, or square corners")
            menuItems: root.cornerItems
            active: root.cornerItems[Math.max(0, root.cornerValues.indexOf(GlobalConfig.bar.cornerStyle))]
            onSelected: item => GlobalConfig.bar.cornerStyle = root.cornerValues[root.cornerItems.indexOf(item)]
        }

        ToggleRow {
            text: Tr.tr("Persistent")
            subtext: Tr.tr("Keep the bar visible at all times")
            checked: Config.bar.persistent
            onToggled: GlobalConfig.bar.persistent = checked
        }

        ToggleRow {
            text: Tr.tr("Show on hover")
            subtext: Tr.tr("Reveal the bar when the cursor reaches the screen edge")
            checked: Config.bar.showOnHover
            onToggled: GlobalConfig.bar.showOnHover = checked
        }

        StepperRow {
            last: true
            label: Tr.tr("Drag threshold")
            subtext: Tr.tr("Pixels dragged before the bar reveals")
            value: Config.bar.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.bar.dragThreshold = v
        }

        // Layout
        SectionHeader {
            text: Tr.tr("Layout")
        }

        ListEditor {
            function labelFor(item: var): string {
                return root.entryNames[item.id] ?? item.id;
            }

            function toggledFor(item: var): bool {
                return item.enabled;
            }

            z: 1
            first: true
            values: Config.bar.entries.values
            onItemMoved: (from, to) => GlobalConfig.bar.entries.move(from, to)
            onItemRemoved: index => GlobalConfig.bar.entries.remove(index)
            onItemToggled: (index, checked) => GlobalConfig.bar.entries.at(index).enabled = checked
        }

        DialogSelectButton {
            rootParent: root.flickable
            icon: "add"
            label: Tr.tr("Add entry")
            header: Tr.tr("Add new entry")
            acceptLabel: Tr.trCtx("Add", "button")
            model: Object.keys(root.entryNames).map(k => ({
                        id: k,
                        label: root.entryNames[k]
                    }))
            onAccepted: {
                if (selectedItem)
                    GlobalConfig.bar.entries.insert({
                        id: selectedItem,
                        enabled: true
                    });
            }
        }

        // Components
        SectionHeader {
            text: Tr.tr("Components")
        }

        NavRow {
            first: true
            icon: "workspaces"
            text: Tr.tr("Workspaces")
            subtext: Tr.tr("Indicators, window icons")
            onClicked: root.nState.openSubPage(6)
        }

        NavRow {
            icon: "web_asset"
            text: Tr.tr("Active window")
            subtext: Tr.tr("Title display, popout")
            onClicked: root.nState.openSubPage(7)
        }

        NavRow {
            icon: "widgets"
            text: Tr.tr("Tray")
            subtext: Tr.tr("System tray icons")
            onClicked: root.nState.openSubPage(8)
        }

        NavRow {
            icon: "signal_cellular_alt"
            text: Tr.tr("Status icons")
            subtext: Tr.tr("Visible indicators")
            onClicked: root.nState.openSubPage(9)
        }

        NavRow {
            last: true
            icon: "schedule"
            text: Tr.tr("Clock")
            subtext: Tr.tr("Date, icon, background")
            onClicked: root.nState.openSubPage(10)
        }

        // Scroll actions
        SectionHeader {
            text: Tr.tr("Scroll actions")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Workspaces")
            subtext: Tr.tr("Scroll over the workspace indicator to switch workspaces")
            checked: Config.bar.scrollActions.workspaces
            onToggled: GlobalConfig.bar.scrollActions.workspaces = checked
        }

        ToggleRow {
            text: Tr.tr("Volume")
            subtext: Tr.tr("Scroll on the top half of the bar to adjust volume")
            checked: Config.bar.scrollActions.volume
            onToggled: GlobalConfig.bar.scrollActions.volume = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Brightness")
            subtext: Tr.tr("Scroll on the bottom half of the bar to adjust brightness")
            checked: Config.bar.scrollActions.brightness
            onToggled: GlobalConfig.bar.scrollActions.brightness = checked
        }
    }
}
