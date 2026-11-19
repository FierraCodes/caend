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

// NetworkManager asks the shell (as its secret agent) for Wi-Fi and 802.1X/RADIUS credentials.
// Also asks for the account when joining an 802.1X network that has no profile yet (see Nmcli.addEnterprise).
Scope {
    id: root

    readonly property bool creating: Nmcli.enterpriseSsid !== ""
    // The first request for a profile just created from this prompt is answered with what was typed
    readonly property bool autoAnswer: NetworkAgent.active && !NetworkAgent.retry && Nmcli.enterprisePending?.ssid === NetworkAgent.connectionName
    readonly property list<string> fields: creating ? ["identity", "password"] : NetworkAgent.fields
    readonly property bool enterprise: creating || NetworkAgent.settingName === "802-1x"

    readonly property var labels: ({
            psk: Tr.tr("Password"),
            "wep-key0": Tr.tr("WEP key"),
            identity: Tr.tr("Username"),
            password: Tr.tr("Password"),
            "private-key-password": Tr.tr("Private key password")
        })

    function cancel(): void {
        if (creating)
            Nmcli.enterpriseSsid = "";
        else
            NetworkAgent.cancel();
    }

    Connections {
        function onRequestChanged(): void {
            if (!root.autoAnswer)
                return;
            const secrets = {};
            for (const f of NetworkAgent.fields)
                secrets[f] = f === "identity" ? NetworkAgent.prefill.identity ?? "" : Nmcli.enterprisePending.password;
            Nmcli.enterprisePending = null;
            NetworkAgent.submit(secrets);
        }

        target: NetworkAgent
    }

    LazyLoader {
        active: root.creating || (NetworkAgent.active && !root.autoAnswer)

        StyledWindow {
            id: win

            function submit(): void {
                const secrets = {};
                for (let i = 0; i < inputs.count; i++) {
                    const field = inputs.itemAt(i) as StyledTextField;
                    secrets[root.fields[i]] = field.text;
                }
                if (root.creating)
                    Nmcli.addEnterprise(Nmcli.enterpriseSsid, secrets.identity, secrets.password);
                else
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
                        text: root.enterprise ? "badge" : "wifi_password"
                        color: Colours.palette.m3secondary
                        fontStyle: Tokens.font.icon.large
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Tr.tr("Connect to %1").arg(root.creating ? Nmcli.enterpriseSsid : NetworkAgent.connectionName)
                        font: Tokens.font.body.large
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: !root.creating && NetworkAgent.retry ? Tr.tr("Those details didn't work, try again") : root.enterprise ? Tr.tr("This network needs your account (802.1X)") : Tr.tr("This network needs a password")
                        color: !root.creating && NetworkAgent.retry ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        id: inputs

                        model: root.fields

                        StyledTextField {
                            required property string modelData
                            required property int index

                            Layout.fillWidth: true
                            focus: index === 0
                            placeholderText: root.labels[modelData] ?? modelData
                            text: root.creating ? "" : NetworkAgent.prefill[modelData] ?? ""
                            echoMode: modelData === "identity" ? TextInput.Normal : TextInput.Password
                            onAccepted: win.submit()
                            Keys.onEscapePressed: root.cancel()
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
                            onClicked: root.cancel()
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
