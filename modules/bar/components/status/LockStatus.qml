import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

GridLayout {
    id: root

    required property color colour
    required property int parentSpacing
    readonly property bool horizontal: Config.bar.position === "top" || Config.bar.position === "bottom"

    property real gap: Compositor.capsLock && Compositor.numLock ? parentSpacing : 0
    // Size along the bar; animated so icons slide in and out
    property real capsHeight: Compositor.capsLock ? (horizontal ? capslockIcon.implicitWidth : capslockIcon.implicitHeight) : 0
    property real numHeight: Compositor.numLock ? (horizontal ? numlockIcon.implicitWidth : numlockIcon.implicitHeight) : 0

    flow: horizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
    rowSpacing: Math.round(gap)
    columnSpacing: Math.round(gap)

    Behavior on gap {
        Anim {
            type: Anim.SlowEffects
        }
    }

    Behavior on capsHeight {
        Anim {
            type: Anim.SlowEffects
        }
    }

    Behavior on numHeight {
        Anim {
            type: Anim.SlowEffects
        }
    }

    Item {
        implicitWidth: root.horizontal ? Math.round(root.capsHeight) : capslockIcon.implicitWidth
        implicitHeight: root.horizontal ? capslockIcon.implicitHeight : Math.round(root.capsHeight)

        MaterialIcon {
            id: capslockIcon

            anchors.centerIn: parent

            scale: Compositor.capsLock ? 1 : 0.5
            opacity: Compositor.capsLock ? 1 : 0

            text: "keyboard_capslock_badge"
            color: root.colour
            fill: 1
            grade: 25

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on scale {
                Anim {}
            }
        }
    }

    Item {
        implicitWidth: root.horizontal ? Math.round(root.numHeight) : numlockIcon.implicitWidth
        implicitHeight: root.horizontal ? numlockIcon.implicitHeight : Math.round(root.numHeight)

        MaterialIcon {
            id: numlockIcon

            anchors.centerIn: parent

            scale: Compositor.numLock ? 1 : 0.5
            opacity: Compositor.numLock ? 1 : 0

            text: "looks_one"
            color: root.colour
            fill: 1
            grade: 25

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on scale {
                Anim {}
            }
        }
    }
}
