pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.services
import qs.utils

// end4's bar resources: CPU, CPU temperature, memory, disk. Polling only runs while this entry exists.
StyledRect {
    id: root

    readonly property bool horizontal: Config.bar.position === "top" || Config.bar.position === "bottom"

    implicitWidth: horizontal ? grid.implicitWidth + Tokens.padding.medium * 2 : Tokens.sizes.bar.innerWidth
    implicitHeight: horizontal ? Tokens.sizes.bar.innerWidth : grid.implicitHeight + Tokens.padding.medium * 2

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    ServiceRef {
        service: Cpu
    }

    ServiceRef {
        service: Memory
    }

    ServiceRef {
        service: Storage
    }

    Grid {
        id: grid

        anchors.centerIn: parent
        flow: root.horizontal ? Grid.LeftToRight : Grid.TopToBottom
        rows: root.horizontal ? 1 : -1
        columns: root.horizontal ? -1 : 1
        spacing: root.horizontal ? Tokens.spacing.medium : Tokens.spacing.small

        Stat {
            icon: "memory"
            value: Strings.percentOne(Cpu.percentage)
            alert: Cpu.percentage > 0.9
        }

        Stat {
            icon: Cpu.temperature > 90 ? "thermometer_alert" : "thermometer"
            value: Units.formatSensorTemp(Cpu.temperature)
            alert: Cpu.temperature > 90
        }

        Stat {
            icon: "memory_alt"
            value: Strings.percentOne(Memory.percentage)
            alert: Memory.percentage > 0.9
        }

        Stat {
            icon: "hard_drive"
            value: Strings.percentOne(Storage.percentage)
            alert: Storage.percentage > 0.9
        }
    }

    component Stat: Grid {
        required property string icon
        required property string value
        property bool alert

        flow: root.horizontal ? Grid.LeftToRight : Grid.TopToBottom
        rows: root.horizontal ? 1 : -1
        columns: root.horizontal ? -1 : 1
        spacing: Tokens.spacing.extraSmall
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        MaterialIcon {
            text: parent.icon
            color: parent.alert ? Colours.palette.m3error : Colours.palette.m3primary
        }

        StyledText {
            text: parent.value
            font: Tokens.font.label.small
            color: Colours.palette.m3onSurface
        }
    }
}
