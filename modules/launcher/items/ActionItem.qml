import QtQuick
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services

// One search result: an app (image), an emoji (glyph) or anything with a material icon
Item {
    id: root

    required property var modelData
    required property var list

    readonly property bool current: ListView.isCurrentItem

    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Tokens.rounding.large
        onClicked: root.modelData?.onClicked(root.list)
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.medium
        anchors.rightMargin: Tokens.padding.medium
        anchors.margins: Tokens.padding.small

        Item {
            id: icon

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: parent.height * 0.8
            implicitHeight: parent.height * 0.8

            IconImage {
                anchors.fill: parent
                visible: !!root.modelData?.image
                asynchronous: true
                source: root.modelData?.image ?? ""
            }

            StyledText {
                anchors.centerIn: parent
                visible: !!root.modelData?.glyph
                text: root.modelData?.glyph ?? ""
                font.pointSize: Tokens.font.body.large.pointSize * 1.5
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: !root.modelData?.image && !root.modelData?.glyph
                text: root.modelData?.icon ?? ""
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.builders.large.scale(1.3).build()
            }
        }

        Item {
            anchors.left: icon.right
            anchors.leftMargin: Tokens.spacing.medium
            anchors.right: trailing.left
            anchors.rightMargin: Tokens.spacing.small
            anchors.verticalCenter: icon.verticalCenter

            implicitHeight: name.implicitHeight + desc.implicitHeight

            StyledText {
                id: name

                width: parent.width
                text: root.modelData?.name ?? ""
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            StyledText {
                id: desc

                width: parent.width
                text: root.modelData?.desc ?? ""
                font: Tokens.font.body.small
                color: Colours.palette.m3outline
                elide: Text.ElideRight

                anchors.top: name.bottom
            }
        }

        // end4 shows the verb (Open, Run, Copy...) on the selected row
        Row {
            id: trailing

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.modelData?.verb ?? ""
                font: Tokens.font.body.small
                color: Colours.palette.m3primary
                opacity: root.current && text ? 1 : 0

                Behavior on opacity {
                    Anim {}
                }
            }

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.modelData?.favourite ?? false
                text: "favorite"
                fill: 1
                color: Colours.palette.m3primary
            }
        }
    }
}
