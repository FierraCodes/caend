pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<MenuItem> flashbangItems: [
        MenuItem {
            text: Tr.trCtx("Off", "anti-flashbang strength")
            icon: "brightness_7"
        },
        MenuItem {
            text: Tr.trCtx("Weak", "anti-flashbang strength")
            icon: "brightness_6"
        },
        MenuItem {
            text: Tr.trCtx("Strong", "anti-flashbang strength")
            icon: "brightness_4"
        }
    ]

    readonly property list<string> flashbangValues: ["off", "weak", "strong"]

    function isToggleOn(id: string): bool {
        const item = Config.utilities.quickToggles.values.find(t => t.id === id);
        return item?.enabled ?? false;
    }

    function setToggleOn(id: string, on: bool): void {
        const list = GlobalConfig.utilities.quickToggles;
        for (let i = 0; i < list.count; i++) {
            const item = list.at(i);
            if (item.id === id) {
                item.enabled = on;
                return;
            }
        }
        list.insert({
            id,
            enabled: on
        });
    }

    title: Tr.tr("Utilities")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // General
        SectionHeader {
            first: true
            text: Tr.tr("General")
        }

        ToggleRow {
            first: true
            last: true
            text: Tr.trCtx("Enabled", "toggle label")
            subtext: Tr.tr("Show the utilities panel")
            checked: Config.utilities.enabled
            onToggled: GlobalConfig.utilities.enabled = checked
        }

        // Screen (Hyprland only)
        SectionHeader {
            text: Tr.tr("Screen")
        }

        SelectRow {
            first: true
            last: true
            label: Tr.tr("Anti-flashbang")
            subtext: Tr.tr("Dim bright screens with a shader (Hyprland only)")
            menuItems: root.flashbangItems
            active: root.flashbangItems[Math.max(0, root.flashbangValues.indexOf(GlobalConfig.utilities.antiFlashbang))]
            onSelected: item => GlobalConfig.utilities.antiFlashbang = root.flashbangValues[root.flashbangItems.indexOf(item)]
        }

        // Cards
        SectionHeader {
            text: Tr.tr("Cards")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Keep awake")
            subtext: Tr.tr("Show the idle inhibitor card")
            checked: Config.utilities.cards.keepAwake
            onToggled: GlobalConfig.utilities.cards.keepAwake = checked
        }

        ToggleRow {
            text: Tr.tr("Screen recorder")
            subtext: Tr.tr("Show the screen recorder card")
            checked: Config.utilities.cards.recorder
            onToggled: GlobalConfig.utilities.cards.recorder = checked
        }

        ToggleRow {
            text: Tr.tr("Record microphone")
            subtext: Tr.tr("Mix your default microphone into screen recordings")
            checked: GlobalConfig.utilities.recordMicrophone
            onToggled: GlobalConfig.utilities.recordMicrophone = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Quick toggles")
            subtext: Tr.tr("Show the quick toggles card")
            checked: Config.utilities.cards.quickToggles
            onToggled: GlobalConfig.utilities.cards.quickToggles = checked
        }

        // Quick toggles
        SectionHeader {
            text: Tr.tr("Quick toggles")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Wi-Fi")
            subtext: Tr.tr("Toggle wireless networking")
            disabled: !Config.utilities.cards.quickToggles
            checked: root.isToggleOn("wifi")
            onToggled: root.setToggleOn("wifi", checked)
        }

        ToggleRow {
            text: Tr.tr("Bluetooth")
            subtext: Tr.tr("Toggle the Bluetooth adapter")
            disabled: !Config.utilities.cards.quickToggles
            checked: root.isToggleOn("bluetooth")
            onToggled: root.setToggleOn("bluetooth", checked)
        }

        ToggleRow {
            text: Tr.tr("Microphone")
            subtext: Tr.tr("Mute or unmute the default source")
            disabled: !Config.utilities.cards.quickToggles
            checked: root.isToggleOn("mic")
            onToggled: root.setToggleOn("mic", checked)
        }

        ToggleRow {
            text: Tr.tr("Settings")
            subtext: Tr.tr("Open the settings window")
            disabled: !Config.utilities.cards.quickToggles
            checked: root.isToggleOn("settings")
            onToggled: root.setToggleOn("settings", checked)
        }

        ToggleRow {
            text: Tr.tr("Game mode")
            subtext: Tr.tr("Toggle game mode")
            disabled: !Config.utilities.cards.quickToggles
            checked: root.isToggleOn("gameMode")
            onToggled: root.setToggleOn("gameMode", checked)
        }

        ToggleRow {
            text: Tr.tr("Do not disturb")
            subtext: Tr.tr("Silence notifications")
            disabled: !Config.utilities.cards.quickToggles
            checked: root.isToggleOn("dnd")
            onToggled: root.setToggleOn("dnd", checked)
        }

        ToggleRow {
            text: Tr.tr("VPN")
            subtext: Tr.tr("Connect or disconnect the VPN")
            disabled: !Config.utilities.cards.quickToggles
            checked: root.isToggleOn("vpn")
            onToggled: root.setToggleOn("vpn", checked)
        }

        Repeater {
            model: [
                {
                    id: "wallpaperPlaying",
                    text: Tr.tr("Wallpaper playback"),
                    subtext: Tr.tr("Pause or play a video wallpaper")
                },
                {
                    id: "antiFlashbang",
                    text: Tr.tr("Anti-flashbang"),
                    subtext: Tr.tr("Dim bright screens")
                },
                {
                    id: "powerProfile",
                    text: Tr.tr("Power profile"),
                    subtext: Tr.tr("Cycle power saver, balanced and performance")
                },
                {
                    id: "nightLight",
                    text: Tr.tr("Night light"),
                    subtext: Tr.tr("Warm the screen with hyprsunset")
                },
                {
                    id: "darkMode",
                    text: Tr.tr("Dark mode"),
                    subtext: Tr.tr("Switch between light and dark schemes")
                },
                {
                    id: "colorPicker",
                    text: Tr.tr("Colour picker"),
                    subtext: Tr.tr("Pick a colour from the screen with hyprpicker")
                },
                {
                    id: "screenshot",
                    text: Tr.tr("Screenshot"),
                    subtext: Tr.tr("Open the screenshot picker")
                },
                {
                    id: "keepAwake",
                    text: Tr.tr("Keep awake"),
                    subtext: Tr.tr("Stop the screen from idling or sleeping")
                },
                {
                    id: "screenRecord",
                    text: Tr.tr("Screen record"),
                    subtext: Tr.tr("Start or stop a full screen recording")
                }
            ]

            ToggleRow {
                required property var modelData
                required property int index

                last: index === 8
                text: modelData.text
                subtext: modelData.subtext
                disabled: !Config.utilities.cards.quickToggles
                checked: root.isToggleOn(modelData.id)
                onToggled: root.setToggleOn(modelData.id, checked)
            }
        }

        SectionHeader {
            text: Tr.tr("On-screen display")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Enabled")
            subtext: Tr.tr("Show the volume and brightness OSD")
            checked: Config.osd.enabled
            onToggled: GlobalConfig.osd.enabled = checked
        }

        ToggleRow {
            text: Tr.tr("Brightness")
            subtext: Tr.tr("Include a brightness slider")
            checked: Config.osd.enableBrightness
            onToggled: GlobalConfig.osd.enableBrightness = checked
        }

        ToggleRow {
            text: Tr.tr("Microphone")
            subtext: Tr.tr("Include a microphone slider")
            checked: Config.osd.enableMicrophone
            onToggled: GlobalConfig.osd.enableMicrophone = checked
        }

        StepperRow {
            label: Tr.tr("OSD duration")
            subtext: Tr.tr("Milliseconds the OSD stays after a change")
            value: Config.osd.hideDelay
            from: 250
            to: 10000
            stepSize: 250
            onMoved: v => GlobalConfig.osd.hideDelay = v
        }

        StepperRow {
            last: true
            label: Tr.tr("Caps / Num lock duration")
            subtext: Tr.tr("Milliseconds the caps/num lock pill stays on screen")
            value: GlobalConfig.osd.lockKeysHideDelay
            from: 250
            to: 5000
            stepSize: 250
            onMoved: v => GlobalConfig.osd.lockKeysHideDelay = v
        }
    }
}
