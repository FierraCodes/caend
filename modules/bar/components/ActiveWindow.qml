pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property var bar
    required property Brightness.Monitor monitor
    property color colour: Colours.palette.m3primary

    readonly property string windowTitle: {
        const title = Compositor.activeWindowTitle;
        if (!title)
            return Tr.trCtx("Desktop", "shown when no window is focused");
        if (Config.bar.activeWindow.compact) {
            // " - " (standard hyphen), " — " (em dash), " – " (en dash)
            const parts = title.split(/\s+[\-\u2013\u2014]\s+/);
            if (parts.length > 1)
                return parts[parts.length - 1].trim();
        }
        return title;
    }

    readonly property bool horizontal: bar.horizontal
    // Space left along the bar once the other entries are laid out
    readonly property int maxHeight: {
        const otherModules = bar.children.filter(c => c.entryId && c.item !== this && c.entryId !== "spacer");
        const otherHeight = otherModules.reduce((acc, curr) => acc + (curr.item.nonAnimLength ?? (horizontal ? curr.width : curr.height)), 0);
        // Length - 2 cause repeater counts as a child
        return (horizontal ? bar.width : bar.height) - otherHeight - bar.spacing * (bar.children.length - 1) - bar.vPadding * 2;
    }
    property Title current: text1

    clip: true
    implicitWidth: horizontal ? icon.implicitWidth + current.implicitWidth + Tokens.spacing.small : Math.max(icon.implicitWidth, current.implicitHeight)
    implicitHeight: horizontal ? Math.max(icon.implicitHeight, current.implicitHeight) : icon.implicitHeight + current.implicitWidth + Tokens.spacing.small

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: !Config.bar.activeWindow.showOnHover

        sourceComponent: MouseArea {
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onPositionChanged: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent && popouts.currentName !== "activewindow")
                    popouts.hasCurrent = false;
            }
            onClicked: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent) {
                    popouts.hasCurrent = false;
                } else {
                    popouts.currentName = "activewindow";
                    popouts.currentCenter = root.bar.centerOf(root);
                    popouts.hasCurrent = true;
                }
            }
        }
    }

    MaterialIcon {
        id: icon

        anchors.horizontalCenter: root.horizontal ? undefined : parent.horizontalCenter
        anchors.verticalCenter: root.horizontal ? parent.verticalCenter : undefined

        animate: true
        text: Icons.getAppCategoryIcon(Compositor.activeWindowAppId, "desktop_windows")
        color: root.colour
    }

    Title {
        id: text1
    }

    Title {
        id: text2
    }

    TextMetrics {
        id: metrics

        text: root.windowTitle
        font: root.Tokens.font.body.builders.small.letterSpacing(1.4).build()
        elide: Qt.ElideRight
        elideWidth: root.maxHeight - (root.horizontal ? icon.width + Tokens.spacing.small : icon.height)

        onTextChanged: {
            const next = root.current === text1 ? text2 : text1;
            next.text = elidedText;
            root.current = next;
        }
        onElideWidthChanged: root.current.text = elidedText
    }

    Behavior on implicitWidth {
        enabled: root.horizontal

        Anim {}
    }

    Behavior on implicitHeight {
        enabled: !root.horizontal

        Anim {}
    }

    component Title: StyledText {
        id: text

        // Vertical bars: below the icon, rotated. Horizontal bars: beside it, upright.
        anchors.horizontalCenter: root.horizontal ? undefined : icon.horizontalCenter
        anchors.top: root.horizontal ? undefined : icon.bottom
        anchors.verticalCenter: root.horizontal ? icon.verticalCenter : undefined
        anchors.left: root.horizontal ? icon.right : undefined
        anchors.topMargin: Tokens.spacing.small
        anchors.leftMargin: Tokens.spacing.small

        font: metrics.font
        color: root.colour
        opacity: root.current === this ? 1 : 0
        horizontalAlignment: Text.AlignLeft

        transform: [
            Translate {
                x: !root.horizontal && root.Config.bar.activeWindow.inverted ? -text.implicitWidth + text.implicitHeight : 0
            },
            Rotation {
                angle: root.horizontal ? 0 : root.Config.bar.activeWindow.inverted ? 270 : 90
                origin.x: text.implicitHeight / 2
                origin.y: text.implicitHeight / 2
            }
        ]

        width: root.horizontal ? implicitWidth : implicitHeight
        height: root.horizontal ? implicitHeight : implicitWidth

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }
}
