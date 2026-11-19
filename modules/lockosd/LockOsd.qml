pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.services

// Small pill near the bottom centre of the focused screen when caps/num lock changes
Scope {
    id: root

    property string icon
    property string text
    property bool shown
    property bool ready // Ignores the initial lock states reported at startup

    function show(icon: string, text: string): void {
        if (!ready)
            return;
        root.icon = icon;
        root.text = text;
        shown = true;
        hideTimer.restart();
    }

    Connections {
        function onCapsLockChanged(): void {
            const on = Compositor.capsLock;
            root.show(on ? "keyboard_capslock_badge" : "keyboard_capslock", on ? Tr.tr("Caps lock on") : Tr.tr("Caps lock off"));
        }

        function onNumLockChanged(): void {
            const on = Compositor.numLock;
            root.show(on ? "looks_one" : "timer_1", on ? Tr.tr("Num lock on") : Tr.tr("Num lock off"));
        }

        target: Compositor
    }

    Timer {
        running: true
        interval: 2000
        onTriggered: root.ready = true
    }

    Timer {
        id: hideTimer

        interval: 1500
        onTriggered: root.shown = false
    }

    Variants {
        model: Quickshell.screens

        StyledWindow {
            id: win

            required property ShellScreen modelData

            screen: modelData
            name: "lock-osd"
            visible: pill.opacity > 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            mask: Region {}

            anchors.bottom: true
            margins.bottom: Math.round(modelData.height * 0.18)
            implicitWidth: pill.implicitWidth + 20
            implicitHeight: pill.implicitHeight + 20

            StyledRect {
                id: pill

                anchors.centerIn: parent
                implicitWidth: row.implicitWidth + Tokens.padding.large * 2
                implicitHeight: row.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.full
                color: Colours.tPalette.m3surfaceContainer
                opacity: root.shown && Compositor.isFocusedScreen(win.modelData) ? 1 : 0
                scale: opacity > 0 ? 1 : 0.9

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                Row {
                    id: row

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.icon
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.medium
                        fill: 1
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.text
                        font: Tokens.font.body.medium
                    }
                }
            }
        }
    }
}
