pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.modules.bar as Bar

Region {
    id: root

    required property Bar.BarWrapper bar
    required property Panels panels
    required property var win

    readonly property real borderThickness: win.contentItem.Config.border.thickness
    readonly property real clampedThickness: win.contentItem.Config.border.clampedThickness
    // Where edge panels meet their edge: the screen edge, or the bar when it is on that side
    readonly property real rightEdge: bar.side === "right" ? win.width - bar.thickness + borderThickness : win.width
    readonly property real topEdge: bar.side === "top" ? bar.thickness - borderThickness : 0
    readonly property real bottomEdge: bar.side === "bottom" ? win.height - bar.thickness + borderThickness : win.height

    x: (bar.side === "left" ? bar.clampedThickness : clampedThickness) + win.dragMaskPadding
    y: (bar.side === "top" ? bar.clampedThickness : clampedThickness) + win.dragMaskPadding
    width: win.width - (bar.horizontal ? clampedThickness : bar.clampedThickness) - clampedThickness - win.dragMaskPadding * 2
    height: win.height - (bar.horizontal ? bar.clampedThickness : clampedThickness) - clampedThickness - win.dragMaskPadding * 2
    intersection: Intersection.Xor

    R {
        readonly property bool fromLeft: root.panels.dashboard.fromLeft
        readonly property real shown: 1 - root.panels.dashboard.offsetScale

        panel: root.panels.dashboard
        x: fromLeft ? root.panels.x - root.borderThickness : panel.x + root.panels.x
        y: fromLeft ? panel.y + root.panels.y : root.topEdge
        width: fromLeft ? panel.width * shown + root.borderThickness : panel.width
        height: fromLeft ? panel.height : panel.height * shown + root.borderThickness
    }

    R {
        panel: root.panels.launcher
        y: root.bottomEdge - height
        height: panel.height * (1 - root.panels.launcher.offsetScale) + root.borderThickness
    }

    R {
        id: sessionRegion

        panel: root.panels.sessionWrapper
        x: root.rightEdge - width
        width: panel.width * (1 - root.panels.session.offsetScale) + root.borderThickness + sidebarRegion.width
    }

    R {
        id: sidebarRegion

        panel: root.panels.sidebar
        x: root.rightEdge - width
        width: panel.width * (1 - root.panels.sidebar.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.osdWrapper
        x: root.rightEdge - width
        width: panel.width * (1 - root.panels.osd.offsetScale) + root.borderThickness + sessionRegion.width
    }

    R {
        panel: root.panels.notifications
        y: root.topEdge
        height: panel.height + root.borderThickness
    }

    R {
        panel: root.panels.utilities
        y: root.bottomEdge - height
        height: panel.height * (1 - root.panels.utilities.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.popoutsWrapper
        width: panel.width * (root.bar.horizontal ? 1 : 1 - root.panels.popoutsWrapper.offsetScale)
        height: panel.height * (root.bar.horizontal ? 1 - root.panels.popoutsWrapper.offsetScale : 1)
    }

    component R: Region {
        required property Item panel

        x: panel.x + root.panels.x
        y: panel.y + root.panels.y
        width: panel.width
        height: panel.height
        intersection: Intersection.Subtract
    }
}
