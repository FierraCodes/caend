import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.images
import qs.services

// Song details for the vertical bar's media pill, which has no room for text
Row {
    id: root

    readonly property var player: Players.active
    readonly property real artSize: Tokens.sizes.bar.innerWidth * 2

    spacing: Tokens.spacing.medium

    ClipRect {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: root.artSize
        implicitHeight: root.artSize
        radius: Tokens.rounding.medium
        color: Colours.palette.m3secondaryContainer

        MaterialIcon {
            anchors.centerIn: parent
            text: "music_note"
            color: Colours.palette.m3onSecondaryContainer
            font.pointSize: Tokens.font.title.large.pointSize
            visible: art.status !== Image.Ready
        }

        FadeImage {
            id: art

            anchors.fill: parent
            source: Players.getArtUrl(root.player)
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(root.artSize * 2, root.artSize * 2)
        }
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter

        StyledText {
            width: Math.min(implicitWidth, 260)
            text: root.player?.trackTitle || Tr.tr("Unknown title")
            font: Tokens.font.title.small
            color: Colours.palette.m3onSurface
            elide: Text.ElideRight
        }

        StyledText {
            width: Math.min(implicitWidth, 260)
            text: root.player?.trackArtist ?? ""
            visible: text.length > 0
            font: Tokens.font.body.medium
            color: Colours.palette.m3onSurfaceVariant
            elide: Text.ElideRight
        }

        StyledText {
            width: Math.min(implicitWidth, 260)
            text: root.player?.trackAlbum ?? ""
            visible: text.length > 0
            font: Tokens.font.body.small
            color: Colours.palette.m3outline
            elide: Text.ElideRight
        }
    }
}
