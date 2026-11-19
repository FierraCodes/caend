pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
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

    property bool waiting // A response was submitted and polkit has not answered yet

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: root.waiting = false
    }

    Connections {
        function onAuthenticationFailed(): void {
            root.waiting = false;
        }

        target: agent.flow
    }

    LazyLoader {
        active: agent.isActive

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
                        text: agent.flow?.message ?? ""
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    }

                    StyledTextField {
                        id: input

                        Layout.fillWidth: true
                        focus: true
                        enabled: !root.waiting
                        placeholderText: (agent.flow?.inputPrompt ?? "").trim().replace(/:$/, "") || Tr.tr("Password")
                        echoMode: agent.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                        isError: agent.flow?.failed ?? false
                        errorText: Tr.tr("Wrong password, try again")
                        onAccepted: submit.clicked()
                        Keys.onEscapePressed: agent.flow?.cancelAuthenticationRequest()
                        onEnabledChanged: if (enabled) {
                            text = "";
                            forceActiveFocus();
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: Tokens.spacing.medium

                        TextButton {
                            text: Tr.trCtx("Cancel", "button")
                            type: TextButton.Text
                            onClicked: agent.flow?.cancelAuthenticationRequest()
                        }

                        TextButton {
                            id: submit

                            text: Tr.trCtx("Authenticate", "button")
                            type: TextButton.Text
                            disabled: root.waiting || !input.text
                            onClicked: {
                                root.waiting = true;
                                agent.flow?.submit(input.text);
                            }
                        }
                    }
                }
            }
        }
    }
}
