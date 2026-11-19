pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.modules.launcher.services

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property var panels

    readonly property bool shouldBeActive: screenState.launcher && Config.launcher.enabled

    readonly property bool floating: Config.launcher.floating
    property real fullHeight: content.implicitHeight

    readonly property real maxHeight: {
        if (floating)
            return screen.height * 0.6;
        let max = screen.height - Config.border.thickness * 2 + Tokens.padding.extraLarge;
        if (screenState.dashboard)
            max -= panels.dashboard.nonAnimHeight;
        return max;
    }

    property real offsetScale: shouldBeActive ? 0 : 1

    onShouldBeActiveChanged: {
        if (shouldBeActive)
            fullHeight = Qt.binding(() => content.implicitHeight);
        else
            fullHeight = fullHeight; // Break binding during close anim
    }

    visible: offsetScale < 1
    // Docked: slides out of the bottom edge. Floating: unfolds downwards from its top edge
    anchors.bottomMargin: floating ? 0 : (-implicitHeight - 5) * offsetScale
    implicitHeight: floating ? fullHeight * (1 - offsetScale) : fullHeight
    clip: floating
    implicitWidth: content.implicitWidth || 630 // Hard coded fallback for first open
    opacity: 1 - offsetScale

    Component.onCompleted: Qt.callLater(() => Apps) // Load apps on init

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            screenState: root.screenState
            panels: root.panels
            maxHeight: root.maxHeight
            floating: root.floating
        }
    }
}
