pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property alias layout: layout
    readonly property alias items: items
    readonly property alias expandIcon: expandIcon

    readonly property int padding: Config.bar.tray.background ? Tokens.padding.medium : Tokens.padding.extraSmall
    readonly property int spacing: Config.bar.tray.background ? Tokens.spacing.medium : Tokens.spacing.extraSmall

    readonly property bool horizontal: Config.bar.position === "top" || Config.bar.position === "bottom"

    property bool expanded
    // Pinned icons sort first, so a collapsed compact tray shows them by clipping the rest
    readonly property int pinnedCount: Config.bar.tray.compact ? items.model.values.filter(i => GlobalConfig.bar.tray.pinnedIcons.includes(i.id)).length : 0

    // Items share one size, so the pinned run is a fraction of the layout
    readonly property real pinnedLength: items.count > 0 ? (horizontal ? layout.implicitWidth : layout.implicitHeight) * pinnedCount / items.count : 0

    // Target size along the bar, ignoring the running animation
    readonly property real nonAnimLength: {
        const layoutLength = horizontal ? layout.implicitWidth : layout.implicitHeight;
        if (!Config.bar.tray.compact)
            return layoutLength + padding * 2;
        const pad = (Config.bar.tray.background ? Tokens.padding.extraSmall : 0) + padding;
        const iconLength = horizontal ? expandIcon.implicitWidth : expandIcon.implicitHeight;
        if (expanded)
            return iconLength + layoutLength + spacing + pad;
        if (pinnedCount > 0)
            return iconLength + pinnedLength + spacing * 2 + pad;
        return Math.max(Config.bar.tray.background ? Tokens.sizes.bar.innerWidth : 0, iconLength + pad);
    }

    clip: true
    visible: width > 0 && height > 0

    implicitWidth: horizontal ? nonAnimLength : Tokens.sizes.bar.innerWidth
    implicitHeight: horizontal ? Tokens.sizes.bar.innerWidth : nonAnimLength

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, (Config.bar.tray.background && items.count > 0) ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    Grid {
        id: layout

        anchors.horizontalCenter: root.horizontal ? undefined : parent.horizontalCenter
        anchors.verticalCenter: root.horizontal ? parent.verticalCenter : undefined
        anchors.top: root.horizontal ? undefined : parent.top
        anchors.left: root.horizontal ? parent.left : undefined
        anchors.topMargin: root.padding
        anchors.leftMargin: root.padding
        columns: root.horizontal ? Math.max(1, items.count) : 1
        spacing: Tokens.spacing.small

        add: Transition {
            Anim {
                properties: "scale"
                from: 0
                to: 1
                easing: Tokens.anim.standardDecel
            }
        }

        move: Transition {
            Anim {
                properties: "scale"
                to: 1
                easing: Tokens.anim.standardDecel
            }
            Anim {
                properties: "x,y"
            }
        }

        Repeater {
            id: items

            model: ScriptModel {
                values: SystemTray.items.values.filter(i => i.status !== Status.Passive && !GlobalConfig.bar.tray.hiddenIcons.includes(i.id)).sort((a, b) => GlobalConfig.bar.tray.pinnedIcons.includes(b.id) - GlobalConfig.bar.tray.pinnedIcons.includes(a.id))
            }

            TrayItem {
                required property int index

                opacity: root.expanded || !Config.bar.tray.compact || index < root.pinnedCount ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }
        }
    }

    Loader {
        id: expandIcon

        asynchronous: true

        anchors.horizontalCenter: root.horizontal ? undefined : parent.horizontalCenter
        anchors.verticalCenter: root.horizontal ? parent.verticalCenter : undefined
        anchors.bottom: root.horizontal ? undefined : parent.bottom
        anchors.right: root.horizontal ? parent.right : undefined

        active: Config.bar.tray.compact && items.count > 0

        sourceComponent: Item {
            implicitWidth: expandIconInner.implicitWidth - (root.horizontal ? Tokens.padding.small : 0)
            implicitHeight: expandIconInner.implicitHeight - (root.horizontal ? 0 : Tokens.padding.small)

            MaterialIcon {
                id: expandIconInner

                property real endMargin: Config.bar.tray.background ? Tokens.padding.extraSmall : -Tokens.padding.small

                anchors.horizontalCenter: root.horizontal ? undefined : parent.horizontalCenter
                anchors.verticalCenter: root.horizontal ? parent.verticalCenter : undefined
                anchors.bottom: root.horizontal ? undefined : parent.bottom
                anchors.right: root.horizontal ? parent.right : undefined
                anchors.bottomMargin: endMargin
                anchors.rightMargin: endMargin
                text: "expand_less"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
                // Points towards the hidden icons: up on vertical bars, left on horizontal ones
                rotation: (root.horizontal ? -90 : 0) + (root.expanded ? 180 : 0)

                Behavior on rotation {
                    Anim {}
                }

                Behavior on endMargin {
                    Anim {}
                }
            }
        }
    }

    Behavior on implicitWidth {
        enabled: root.horizontal

        Anim {}
    }

    Behavior on implicitHeight {
        enabled: !root.horizontal

        Anim {}
    }
}
