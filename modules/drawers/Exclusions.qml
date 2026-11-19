pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components.containers
import qs.modules.bar as Bar

Scope {
    id: root

    required property ShellScreen screen
    required property Bar.BarWrapper bar

    ExclusionZone {
        side: "left"
        anchors.left: true
    }

    ExclusionZone {
        side: "top"
        anchors.top: true
    }

    ExclusionZone {
        side: "right"
        anchors.right: true
    }

    ExclusionZone {
        side: "bottom"
        anchors.bottom: true
    }

    component ExclusionZone: StyledWindow {
        required property string side

        screen: root.screen
        name: "border-exclusion"
        exclusiveZone: root.bar.side === side ? root.bar.exclusiveZone : contentItem.Config.border.thickness
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
    }
}
