pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Config
import qs.components

// AI chat drawer, slides in from the left screen edge
Item {
    id: root

    required property ScreenState screenState

    readonly property bool shouldBeActive: screenState.aichat && GlobalConfig.ai.enabled
    property real offsetScale: shouldBeActive ? 0 : 1

    visible: offsetScale < 1
    anchors.leftMargin: (-implicitWidth - 5) * offsetScale
    implicitWidth: Tokens.sizes.sidebar.width
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        anchors.fill: parent
        anchors.rightMargin: Tokens.padding.large
        anchors.margins: CUtils.clamp(anchors.rightMargin - Config.border.thickness, 0, anchors.rightMargin)

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            screenState: root.screenState
        }
    }
}
