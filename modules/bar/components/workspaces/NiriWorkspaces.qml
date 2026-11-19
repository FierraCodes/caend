pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import M3Shapes
import Caelestia
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// Niri counterpart of Workspaces: one column per output, sorted by index, with window icons
StyledRect {
    id: root

    required property ShellScreen screen
    required property bool fullscreen

    readonly property var wsList: Compositor.niriWorkspaces.filter(w => w.output === root.screen?.name).sort((a, b) => a.idx - b.idx)
    readonly property Item activeItem: {
        CUtils.dependency(repeater.count);
        return repeater.itemAt(wsList.findIndex(w => w.is_active));
    }
    // Horizontal bars turn the whole widget by -90°, so glyphs turn back to stay upright
    readonly property real glyphRotation: Config.bar.position === "top" || Config.bar.position === "bottom" ? 90 : 0

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: column.implicitHeight + Tokens.padding.extraSmall * 2

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    StyledRect {
        x: Tokens.padding.extraSmall
        y: column.y + (root.activeItem?.y ?? 0)
        implicitWidth: column.width
        implicitHeight: root.activeItem?.height ?? 0
        visible: !!root.activeItem && Config.bar.workspaces.activeIndicator && !root.fullscreen
        radius: Tokens.rounding.full
        color: Colours.palette.m3primary

        Behavior on y {
            Anim {}
        }

        Behavior on implicitHeight {
            Anim {}
        }
    }

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.extraSmall
        spacing: Tokens.spacing.extraSmall
        visible: !root.fullscreen

        Repeater {
            id: repeater

            model: root.wsList

            Item {
                id: ws

                required property var modelData

                readonly property bool active: modelData.is_active
                readonly property var windows: Config.bar.workspaces.showWindows ? Compositor.niriWindows.filter(w => w.workspace_id === ws.modelData.id).slice(0, Math.max(0, Config.bar.workspaces.maxWindowIcons)) : []
                readonly property color fg: active ? Colours.palette.m3onPrimary : windows.length > 0 ? Colours.palette.m3onSurface : Colours.layer(Colours.palette.m3outlineVariant, 2)

                width: column.width
                implicitHeight: inner.implicitHeight + (windows.length > 0 ? Tokens.padding.extraSmall : 0)

                Column {
                    id: inner

                    anchors.horizontalCenter: parent.horizontalCenter

                    MaterialShape {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitSize: Tokens.sizes.bar.innerWidth - Tokens.padding.small
                        shape: ws.active ? MaterialShape.Cookie6Sided : ws.windows.length > 0 ? MaterialShape.Square : MaterialShape.Circle
                        color: ws.fg
                        scale: ws.active ? 1 / 2 : ws.windows.length > 0 ? 1 / 3 : 1 / 4

                        Behavior on scale {
                            Anim {}
                        }
                    }

                    Repeater {
                        model: ws.windows

                        MaterialIcon {
                            required property var modelData

                            anchors.horizontalCenter: parent.horizontalCenter
                            grade: 0
                            rotation: root.glyphRotation
                            text: Icons.getAppCategoryIcon(modelData.app_id ?? "", "terminal")
                            color: ws.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Compositor.focusNiriWorkspace(ws.modelData.output, ws.modelData.idx)
                }
            }
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }
}
