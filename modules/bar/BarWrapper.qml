pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.utils
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen

    // Screen edge the bar sits on: "left" (default), "right", "top" or "bottom"
    readonly property string side: ["right", "top", "bottom"].includes(Config.bar.position) ? Config.bar.position : "left"
    readonly property bool onRight: side === "right"
    readonly property bool horizontal: side === "top" || side === "bottom"
    readonly property bool disabled: Strings.testRegexList(Config.bar.excludedScreens, screen.name)

    // How far the bar currently reaches in from its screen edge
    property real thickness: fullscreen ? 0 : Config.border.thickness
    readonly property int clampedThickness: Math.max(Config.border.minThickness, thickness)
    readonly property int padding: Math.max(Tokens.padding.small, Config.border.thickness)
    readonly property int contentWidth: Tokens.sizes.bar.innerWidth + padding * 2
    readonly property int exclusiveZone: !disabled && (Config.bar.persistent || screenState.bar) ? contentWidth : Config.border.thickness
    readonly property bool shouldBeVisible: !fullscreen && !disabled && (Config.bar.persistent || screenState.bar || isHovered)
    property bool isHovered

    function closeTray(): void {
        (content.item as Bar)?.closeTray();
    }

    // pos is the coordinate along the bar (y for vertical bars, x for horizontal ones)
    function checkPopout(pos: real): void {
        (content.item as Bar)?.checkPopout(pos);
    }

    function handleWheel(pos: real, angleDelta: point): void {
        (content.item as Bar)?.handleWheel(pos, angleDelta);
    }

    clip: true
    visible: thickness > Config.border.thickness
    implicitWidth: horizontal ? 0 : thickness
    implicitHeight: horizontal ? thickness : 0

    states: State {
        name: "visible"
        when: root.shouldBeVisible

        PropertyChanges {
            root.thickness: root.contentWidth
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: "thickness"
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: "thickness"
                type: Anim.Emphasized
            }
        }
    ]

    Loader {
        id: content

        // Anchor to the inner side so the bar slides out past the screen edge while hiding
        anchors.top: root.side === "bottom" || !root.horizontal ? parent.top : undefined
        anchors.bottom: root.side === "top" || !root.horizontal ? parent.bottom : undefined
        anchors.left: root.side === "right" || root.horizontal ? parent.left : undefined
        anchors.right: root.side === "left" || root.horizontal ? parent.right : undefined

        active: root.shouldBeVisible

        sourceComponent: Bar {
            width: root.horizontal ? undefined : root.contentWidth
            height: root.horizontal ? root.contentWidth : undefined
            horizontal: root.horizontal
            screen: root.screen
            screenState: root.screenState
            popouts: root.popouts
            fullscreen: root.fullscreen
        }
    }
}
