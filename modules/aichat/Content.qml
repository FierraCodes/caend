pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

Item {
    id: root

    required property ScreenState screenState

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.padding.small
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "auto_awesome"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.medium
            }

            StyledText {
                Layout.fillWidth: true
                text: Ai.currentModel?.name ?? Tr.tr("No model")
                font: Tokens.font.title.small
                elide: Text.ElideRight
            }

            IconButton {
                type: IconButton.Text
                icon: "swap_horiz"
                onClicked: Ai.send("/model")
            }

            IconButton {
                type: IconButton.Text
                icon: "delete_sweep"
                disabled: Ai.messages.length === 0
                onClicked: Ai.clear()
            }

            IconButton {
                type: IconButton.Text
                icon: "close"
                onClicked: root.screenState.aichat = false
            }
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerLow

            StyledListView {
                id: list

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                clip: true
                spacing: Tokens.spacing.medium

                model: ScriptModel {
                    values: Ai.messages
                }
                onCountChanged: positionViewAtEnd()
                onContentHeightChanged: if (atYEnd || Ai.busy)
                    positionViewAtEnd()

                delegate: Message {}
            }

            StyledText {
                anchors.centerIn: parent
                width: parent.width - Tokens.padding.large * 2
                visible: list.count === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Colours.palette.m3onSurfaceVariant
                text: Tr.tr("Ask anything. Type /help for commands.")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.padding.small
            spacing: Tokens.spacing.small

            StyledTextField {
                id: input

                Layout.fillWidth: true
                type: StyledTextField.Filled
                placeholderText: Tr.tr("Message %1").arg(Ai.currentModel?.name ?? "")
                focus: root.screenState.aichat
                onAccepted: {
                    Ai.send(text);
                    text = "";
                }
                Keys.onEscapePressed: root.screenState.aichat = false
            }

            IconButton {
                icon: Ai.busy ? "stop" : "send"
                onClicked: {
                    if (Ai.busy) {
                        Ai.stop();
                    } else {
                        Ai.send(input.text);
                        input.text = "";
                    }
                }
            }
        }
    }

    component Message: Item {
        id: msg

        required property var modelData
        readonly property bool isUser: modelData.role === "user"
        readonly property bool isInterface: modelData.role === Ai.interfaceRole

        width: ListView.view.width
        implicitHeight: bubble.implicitHeight

        StyledRect {
            id: bubble

            anchors.right: msg.isUser ? parent.right : undefined
            width: msg.isUser ? Math.min(parent.width * 0.85, body.implicitWidth + Tokens.padding.medium * 2) : parent.width
            implicitHeight: column.implicitHeight + Tokens.padding.medium * 2

            radius: Tokens.rounding.medium
            color: msg.isUser ? Colours.palette.m3primaryContainer : msg.isInterface ? Colours.tPalette.m3surfaceContainerHigh : "transparent"

            ColumnLayout {
                id: column

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    visible: !msg.isUser
                    text: msg.isInterface ? Tr.tr("System") : msg.modelData.model
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledText {
                    id: body

                    Layout.fillWidth: true
                    text: msg.modelData.content || (msg.modelData.done ? "" : "…")
                    textFormat: msg.isUser ? Text.PlainText : Text.MarkdownText
                    wrapMode: Text.Wrap
                    color: msg.isUser ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
            }
        }
    }
}
