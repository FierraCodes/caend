import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.images
import qs.services

// end4's material bar media pill: art, artist/title, play/pause, next. Hidden with no player.
StyledRect {
    id: root

    required property ScreenState screenState

    readonly property bool horizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    readonly property var player: Players.active
    readonly property bool playing: player?.isPlaying ?? false
    // Media is the second dashboard tab unless the main tab is turned off
    readonly property int mediaTab: Config.dashboard.showDashboard ? 1 : 0
    readonly property real size: Tokens.sizes.bar.innerWidth - Tokens.padding.small

    visible: !!player
    implicitWidth: !player ? 0 : horizontal ? row.implicitWidth + Tokens.padding.extraSmall * 2 : Tokens.sizes.bar.innerWidth
    implicitHeight: !player ? 0 : horizontal ? Tokens.sizes.bar.innerWidth : column.implicitHeight + Tokens.padding.extraSmall * 2

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    // Body: left opens dashboard > media, middle toggles playback, back/forward skip
    StateLayer {
        radius: Tokens.rounding.full
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
        onClicked: event => {
            if (event.button === Qt.MiddleButton)
                root.player?.togglePlaying();
            else if (event.button === Qt.BackButton)
                root.player?.previous();
            else if (event.button === Qt.ForwardButton)
                root.player?.next();
            else if (root.screenState.dashboard && root.screenState.dashboardTab === root.mediaTab)
                root.screenState.dashboard = false;
            else {
                root.screenState.dashboardTab = root.mediaTab;
                root.screenState.dashboard = true;
            }
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        visible: root.horizontal
        spacing: Tokens.spacing.small

        ClipRect {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: root.size
            implicitHeight: root.size
            radius: Tokens.rounding.full
            color: Colours.palette.m3secondaryContainer

            MaterialIcon {
                anchors.centerIn: parent
                text: "music_note"
                color: Colours.palette.m3onSecondaryContainer
                visible: art.status !== Image.Ready
            }

            FadeImage {
                id: art

                anchors.fill: parent
                source: Players.getArtUrl(root.player)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(root.size * 2, root.size * 2)
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                width: Math.min(implicitWidth, 120)
                text: root.player?.trackTitle ?? ""
                font: Tokens.font.label.small
                color: Colours.palette.m3onSurface
                elide: Text.ElideRight
            }

            StyledText {
                width: Math.min(implicitWidth, 120)
                text: root.player?.trackArtist ?? ""
                visible: text.length > 0
                font: Tokens.font.label.small
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }
        }

        Button {
            implicitWidth: root.size * 1.5
            icon: root.playing ? "pause" : "play_arrow"
            active: root.playing
            onClicked: root.player?.togglePlaying()
        }

        Button {
            icon: "skip_next"
            onClicked: root.player?.next()
            onRightClicked: root.player?.previous()
        }
    }

    // Vertical bars only fit the controls
    Column {
        id: column

        anchors.centerIn: parent
        visible: !root.horizontal
        spacing: Tokens.spacing.extraSmall

        Button {
            icon: root.playing ? "pause" : "play_arrow"
            active: root.playing
            onClicked: root.player?.togglePlaying()
        }

        Button {
            icon: "skip_next"
            onClicked: root.player?.next()
            onRightClicked: root.player?.previous()
        }
    }

    component Button: Item {
        id: button

        required property string icon
        property bool active

        signal clicked
        signal rightClicked

        y: root.horizontal ? (row.height - height) / 2 : 0 // Anchors aren't allowed inside the vertical Column
        implicitWidth: root.size
        implicitHeight: root.size

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.full
            color: button.active ? Colours.palette.m3primary : "transparent"
        }

        StateLayer {
            radius: Tokens.rounding.full
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: event => event.button === Qt.RightButton ? button.rightClicked() : button.clicked()
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: button.icon
            color: button.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
        }
    }
}
