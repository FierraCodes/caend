pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.modules.bar.popouts // Need to import this module so the Wrapper type is the same as others

Item {
    id: root

    required property ShellScreen screen
    required property real borderThickness

    readonly property alias content: content
    readonly property string side: ["right", "top", "bottom"].includes(Config.bar.position) ? Config.bar.position : "left"
    readonly property bool horizontal: side === "top" || side === "bottom"
    // Only on the left is x 0 when attached, so elsewhere check detachment directly (x > 0 means detached on the left)
    property real offsetScale: (side === "left" ? x > 0 : content.isDetached) || content.hasCurrent ? 0 : 1

    // Keep the popout centred on the hovered item along the bar, clamped to the panel area
    function alongBar(size: real, space: real): real {
        const off = content.currentCenter - borderThickness - size / 2;
        const diff = space - Math.floor(off + size);
        if (diff < 0)
            return off + diff;
        return Math.max(off, 0);
    }

    visible: width > 0 && height > 0
    clip: true

    implicitWidth: content.implicitWidth * (horizontal ? 1 : 1 - offsetScale)
    implicitHeight: content.implicitHeight * (horizontal ? 1 - offsetScale : 1)

    x: {
        if (content.isDetached)
            return (parent.width - content.nonAnimWidth) / 2;
        if (horizontal)
            return alongBar(content.nonAnimWidth, parent.width);
        return side === "right" ? parent.width - width : 0;
    }
    y: {
        if (content.isDetached)
            return (parent.height - content.nonAnimHeight) / 2;
        if (!horizontal)
            return alongBar(content.nonAnimHeight, parent.height);
        return side === "bottom" ? parent.height - height : 0;
    }

    Behavior on offsetScale {
        Anim {}
    }

    // On the right/bottom the position follows the animated size, so a separate position animation would lag
    // behind it and pull the popout off the bar. Only animate it there when moving to or from detached mode.
    Behavior on x {
        enabled: root.side === "right" ? root.content.isDetached : !root.horizontal || root.offsetScale < 1

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Behavior on y {
        enabled: root.side === "bottom" ? root.content.isDetached : root.horizontal || root.offsetScale < 1

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Wrapper {
        id: content

        screen: root.screen
        offsetScale: root.offsetScale

        // Slide in from the bar's side
        anchors.verticalCenter: root.horizontal ? undefined : parent.verticalCenter
        anchors.horizontalCenter: root.horizontal ? parent.horizontalCenter : undefined
        anchors.left: root.side === "left" ? parent.left : undefined
        anchors.right: root.side === "right" ? parent.right : undefined
        anchors.top: root.side === "top" ? parent.top : undefined
        anchors.bottom: root.side === "bottom" ? parent.bottom : undefined
        anchors.leftMargin: (-implicitWidth - 5) * root.offsetScale
        anchors.rightMargin: (-implicitWidth - 5) * root.offsetScale
        anchors.topMargin: (-implicitHeight - 5) * root.offsetScale
        anchors.bottomMargin: (-implicitHeight - 5) * root.offsetScale
    }
}
