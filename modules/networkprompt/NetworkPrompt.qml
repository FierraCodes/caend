pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services

// NetworkManager asks the shell (as its secret agent) for Wi-Fi and 802.1X/RADIUS credentials
Scope {
    id: root

    readonly property var labels: ({
            psk: Tr.tr("Password"),
            "wep-key0": Tr.tr("WEP key"),
            identity: Tr.tr("Username"),
            password: Tr.tr("Password"),
            "private-key-password": Tr.tr("Private key password")
        })

    LazyLoader {
        active: NetworkAgent.active

        StyledWindow {
            id: win

            function submit(): void {
                const secrets = {};
                for (let i = 0; i < inputs.count; i++) {
                    const field = inputs.itemAt(i) as StyledTextField;
                    secrets[NetworkAgent.fields[i]] = field.text;
                }
                NetworkAgent.submit(secrets);
            }

            name: "network-prompt"
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
                anchors.centerIn: parent
                width: Math.min(parent.width - Tokens.padding.extraLargeIncreased, 420)
                implicitHeight: layout.implicitHeight + Tokens.padding.large * 3
                radius: Tokens.rounding.extraLarge
                color: Colours.tPalette.m3surfaceContainerHigh

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
                        text: NetworkAgent.settingName === "802-1x" ? "badge" : "wifi_password"
                        color: Colours.palette.m3secondary
                        fontStyle: Tokens.font.icon.large
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Tr.tr("Connect to %1").arg(NetworkAgent.connectionName)
                        font: Tokens.font.body.large
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: NetworkAgent.retry ? Tr.tr("Those details didn't work, try again") : NetworkAgent.settingName === "802-1x" ? Tr.tr("This network needs your account (802.1X)") : Tr.tr("This network needs a password")
                        color: NetworkAgent.retry ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        id: inputs

                        model: NetworkAgent.fields

                        StyledTextField {
                            required property string modelData
                            required property int index

                            Layout.fillWidth: true
                            focus: index === 0
                            placeholderText: root.labels[modelData] ?? modelData
                            text: NetworkAgent.prefill[modelData] ?? ""
                            echoMode: modelData === "identity" ? TextInput.Normal : TextInput.Password
                            onAccepted: win.submit()
                            Keys.onEscapePressed: NetworkAgent.cancel()
                            Component.onCompleted: if (index === 0)
                                forceActiveFocus()
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: Tokens.spacing.medium

                        TextButton {
                            text: Tr.trCtx("Cancel", "button")
                            type: TextButton.Text
                            onClicked: NetworkAgent.cancel()
                        }

                        TextButton {
                            text: Tr.trCtx("Connect", "button")
                            type: TextButton.Text
                            onClicked: win.submit()
                        }
                    }
                }
            }
        }
    }
}
