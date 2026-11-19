import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.services

// end4's bar util buttons: snip, colour picker, mic mute, power profile, screen record
StyledRect {
    id: root

    readonly property bool horizontal: Config.bar.position === "top" || Config.bar.position === "bottom"

    implicitWidth: horizontal ? column.implicitWidth + Tokens.padding.extraSmall * 2 : Tokens.sizes.bar.innerWidth
    implicitHeight: horizontal ? Tokens.sizes.bar.innerWidth : column.implicitHeight + Tokens.padding.extraSmall * 2

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    Grid {
        id: column

        anchors.centerIn: parent
        flow: root.horizontal ? Grid.LeftToRight : Grid.TopToBottom
        rows: root.horizontal ? 1 : -1
        columns: root.horizontal ? -1 : 1
        spacing: Tokens.spacing.extraSmall

        Button {
            icon: "screenshot_region"
            onClicked: Quickshell.execDetached(["qs", "-c", "caelestia", "ipc", "call", "picker", "openFreeze"])
        }

        Button {
            icon: "colorize"
            onClicked: Quickshell.execDetached(["hyprpicker", "-a"])
        }

        Button {
            icon: Audio.sourceMuted ? "mic_off" : "mic"
            active: Audio.sourceMuted
            onClicked: {
                if (Audio.source?.audio)
                    Audio.source.audio.muted = !Audio.source.audio.muted;
            }
        }

        Button {
            icon: PowerProfiles.profile === PowerProfile.PowerSaver ? "energy_savings_leaf" : PowerProfiles.profile === PowerProfile.Performance ? "rocket_launch" : "balance"
            onClicked: {
                const order = [PowerProfile.PowerSaver, PowerProfile.Balanced, ...(PowerProfiles.hasPerformanceProfile ? [PowerProfile.Performance] : [])];
                PowerProfiles.profile = order[(order.indexOf(PowerProfiles.profile) + 1) % order.length];
            }
        }

        Button {
            icon: Recorder.running ? "stop_circle" : "screen_record"
            active: Recorder.running
            onClicked: Recorder.running ? Recorder.stop() : Recorder.start()
        }
    }

    component Button: Item {
        id: button

        required property string icon
        property bool active

        signal clicked

        implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.small
        implicitHeight: implicitWidth

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.full
            color: button.active ? Colours.palette.m3primary : "transparent"
        }

        StateLayer {
            radius: Tokens.rounding.full
            onClicked: button.clicked()
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: button.icon
            color: button.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
        }
    }
}
