import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.services

// end4's bar util buttons: snip, colour picker, mic mute, power profile, screen record
StyledRect {
    id: root

    // Horizontal bars turn the whole widget by -90°, so glyphs turn back to stay upright
    readonly property real glyphRotation: Config.bar.position === "top" || Config.bar.position === "bottom" ? 90 : 0

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: column.implicitHeight + Tokens.padding.extraSmall * 2

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    Column {
        id: column

        anchors.centerIn: parent
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
            rotation: root.glyphRotation
            text: button.icon
            color: button.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
        }
    }
}
