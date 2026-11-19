pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Polkit
import M3Shapes
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services

// Polkit authentication agent: asks for your password when an app needs root (e.g. pkexec, GParted)
Scope {
    id: root

    readonly property PolkitAgent agent: agentLoader.item as PolkitAgent
    property bool waiting // A response was submitted and polkit has not answered yet

    // Other agents (polkit-gnome, hyprpolkitagent...) register first if autostarted, so stop them before registering ours
    Process {
        running: true
        command: ["pkill", "-f", "polkit-gnome-authentication-agent-1|hyprpolkitagent|polkit-kde-authentication-agent-1|polkit-mate-authentication-agent-1|lxpolkit|lxqt-policykit-agent"]
        onExited: registerDelay.start()
    }

    // polkitd frees the agent slot once it sees the old agent's bus name vanish
    Timer {
        id: registerDelay

        interval: 500
        onTriggered: agentLoader.active = true
    }

    LazyLoader {
        id: agentLoader

        PolkitAgent {
            onAuthenticationRequestStarted: root.waiting = false
        }
    }

    Connections {
        function onAuthenticationFailed(): void {
            root.waiting = false;
        }

        target: root.agent?.flow ?? null
    }

    LazyLoader {
        active: root.agent?.isActive ?? false

        StyledWindow {
            name: "polkit"
            screen: Quickshell.screens.find(s => Compositor.isFocusedScreen(s)) ?? Quickshell.screens[0]

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            StyledRect {
                anchors.fill: parent
                color: Qt.alpha(Colours.palette.m3scrim, 0.5)
            }

            StyledRect {
                id: card

                anchors.centerIn: parent
                width: Math.min(parent.width - Tokens.padding.extraLargeIncreased, 420)
                implicitHeight: layout.implicitHeight + Tokens.padding.large * 3
                radius: Tokens.rounding.extraLarge
                color: Colours.palette.m3surfaceContainerHigh

                scale: 0.9
                Component.onCompleted: scale = 1

                Behavior on scale {
                    Anim {}
                }

                Elevation {
                    anchors.fill: parent
                    radius: parent.radius
                    z: -1
                    level: 3
                }

                ColumnLayout {
                    id: layout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large * 1.5
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "security"
                        color: Colours.palette.m3secondary
                        fontStyle: Tokens.font.icon.large
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Tr.tr("Authentication required")
                        font: Tokens.font.body.large
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.agent?.flow?.message ?? ""
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    }

                    StyledTextField {
                        id: input

                        readonly property bool masked: !(root.agent?.flow?.responseVisible ?? false)
                        readonly property list<int> shapes: {
                            const shapes = [MaterialShape.Slanted, MaterialShape.Arch, MaterialShape.Fan, MaterialShape.Arrow, MaterialShape.SemiCircle, MaterialShape.Triangle, MaterialShape.Diamond, MaterialShape.ClamShell, MaterialShape.Pentagon, MaterialShape.Gem, MaterialShape.Sunny, MaterialShape.VerySunny, MaterialShape.Cookie4Sided, MaterialShape.Ghostish, MaterialShape.SoftBurst];
                            for (let i = shapes.length - 1; i > 0; i--) {
                                const j = Math.floor(Math.random() * (i + 1));
                                [shapes[i], shapes[j]] = [shapes[j], shapes[i]];
                            }
                            return shapes;
                        }
                        readonly property real shapeSize: Tokens.font.body.medium.pointSize

                        Layout.fillWidth: true
                        focus: true
                        enabled: !root.waiting
                        placeholderText: (root.agent?.flow?.inputPrompt ?? "").trim().replace(/:$/, "") || Tr.tr("Password")
                        echoMode: masked ? TextInput.Password : TextInput.Normal
                        // Masked input is drawn as end4-style shapes, so hide the real dots and cursor
                        color: masked ? "transparent" : Colours.palette.m3onSurface
                        hideCursor: masked
                        isError: root.agent?.flow?.failed ?? false
                        errorText: Tr.tr("Wrong password, try again")
                        onAccepted: submit.clicked()
                        Keys.onEscapePressed: root.agent?.flow?.cancelAuthenticationRequest()
                        onEnabledChanged: if (enabled) {
                            text = "";
                            forceActiveFocus();
                        }

                        Row {
                            x: input.leftPadding
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: (input.topPadding - input.bottomPadding) / 2
                            spacing: Tokens.spacing.extraSmall
                            visible: input.masked

                            Repeater {
                                // Only as many shapes as fit in the field
                                // Index list so ScriptModel keeps existing shapes and only animates new ones
                                model: ScriptModel {
                                    values: [...Array(Math.max(0, Math.min(input.text.length, Math.floor((input.width - input.leftPadding - input.rightPadding) / (input.shapeSize + Tokens.spacing.extraSmall) - 1)))).keys()]
                                }

                                // Same pop-in as the lockscreen: grow in wide, then settle at the shape's own size
                                Item {
                                    id: char

                                    required property int index

                                    implicitWidth: input.shapeSize
                                    implicitHeight: input.shapeSize

                                    SequentialAnimation {
                                        running: true

                                        ParallelAnimation {
                                            Anim {
                                                target: char
                                                property: "opacity"
                                                from: 0
                                                to: 1
                                                type: Anim.DefaultEffects
                                            }
                                            Anim {
                                                target: char
                                                property: "scale"
                                                from: 0
                                                to: 1
                                                type: Anim.FastSpatial
                                            }
                                            Anim {
                                                target: char
                                                property: "implicitWidth"
                                                from: input.shapeSize
                                                to: input.shapeSize * 1.3
                                                type: Anim.DefaultEffects
                                            }
                                        }
                                        PauseAnimation {
                                            duration: 180 * Tokens.anim.durations.scale
                                        }
                                        ParallelAnimation {
                                            Anim {
                                                target: charShape
                                                property: "scale"
                                                to: 2 / 3
                                                type: Anim.FastSpatial
                                            }
                                            Anim {
                                                target: char
                                                property: "implicitWidth"
                                                to: input.shapeSize
                                                type: Anim.DefaultEffects
                                            }
                                        }
                                    }

                                    MaterialShape {
                                        id: charShape

                                        anchors.centerIn: parent
                                        implicitSize: input.shapeSize * 1.5
                                        shape: input.shapes[char.index % input.shapes.length]
                                        color: Colours.palette.m3onSurface
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: Tokens.spacing.medium

                        TextButton {
                            text: Tr.trCtx("Cancel", "button")
                            type: TextButton.Text
                            onClicked: root.agent?.flow?.cancelAuthenticationRequest()
                        }

                        TextButton {
                            id: submit

                            text: Tr.trCtx("Authenticate", "button")
                            type: TextButton.Text
                            disabled: root.waiting || !input.text
                            onClicked: {
                                root.waiting = true;
                                root.agent?.flow?.submit(input.text);
                            }
                        }
                    }
                }
            }
        }
    }
}
