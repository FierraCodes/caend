pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components.containers
import qs.services
import qs.modules.bar as Bar

Scope {
    id: root

    required property ShellScreen screen
    required property Bar.BarWrapper bar

    // The open AI drawer reserves its width so windows make room for it, like end4's pinned sidebar
    readonly property int aiZone: (ShellState.forScreen(screen)?.aichat ?? false) && GlobalConfig.ai.enabled ? Tokens.sizes.sidebar.width : 0

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
        exclusiveZone: (root.bar.side === side ? root.bar.exclusiveZone : contentItem.Config.border.thickness) + (side === "left" ? root.aiZone : 0)
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
    }
}
