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
    readonly property bool onRight: Config.bar.position === "right"
    // On the right, x is never 0, so check detachment directly (x > 0 means detached on the left)
    property real offsetScale: (onRight ? content.isDetached : x > 0) || content.hasCurrent ? 0 : 1

    visible: width > 0 && height > 0
    clip: true

    implicitWidth: content.implicitWidth * (1 - offsetScale)
    implicitHeight: content.implicitHeight

    x: content.isDetached ? (parent.width - content.nonAnimWidth) / 2 : onRight ? parent.width - width : 0
    y: {
        if (content.isDetached)
            return (parent.height - content.nonAnimHeight) / 2;

        const off = content.currentCenter - borderThickness - content.nonAnimHeight / 2;
        const diff = parent.height - Math.floor(off + content.nonAnimHeight);
        if (diff < 0)
            return off + diff;
        return Math.max(off, 0);
    }

    Behavior on offsetScale {
        Anim {}
    }

    Behavior on x {
        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Behavior on y {
        enabled: root.offsetScale < 1

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
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: root.onRight ? undefined : parent.left
        anchors.right: root.onRight ? parent.right : undefined
        anchors.leftMargin: (-implicitWidth - 5) * root.offsetScale
        anchors.rightMargin: (-implicitWidth - 5) * root.offsetScale
    }
}
