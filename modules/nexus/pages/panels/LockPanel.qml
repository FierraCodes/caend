pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Lock screen")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("General")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Lock on startup")
            subtext: Tr.tr("Lock the screen when the shell starts")
            checked: GlobalConfig.lock.lockOnStartup
            onToggled: GlobalConfig.lock.lockOnStartup = checked
        }

        ToggleRow {
            text: Tr.tr("Unlock keyring")
            subtext: Tr.tr("Unlock the GNOME login keyring with the password used to unlock the screen")
            checked: GlobalConfig.lock.unlockKeyring
            onToggled: GlobalConfig.lock.unlockKeyring = checked
        }

        ToggleRow {
            text: Tr.tr("Hide notifications")
            subtext: Tr.tr("Only show notification content after unlocking")
            checked: Config.lock.hideNotifs
            onToggled: GlobalConfig.lock.hideNotifs = checked
        }

        ToggleRow {
            text: Tr.tr("Use wallpaper")
            subtext: Tr.tr("Show the wallpaper instead of a blurred screenshot")
            checked: Config.lock.useWallpaper
            onToggled: GlobalConfig.lock.useWallpaper = checked
        }

        ToggleRow {
            text: Tr.tr("Recolour logo")
            subtext: Tr.tr("Tint the logo with the colour scheme")
            checked: Config.lock.recolourLogo
            onToggled: GlobalConfig.lock.recolourLogo = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Session controls")
            subtext: Tr.tr("Show shutdown, reboot and logout on the lock screen")
            checked: GlobalConfig.lock.enableSessionControls
            onToggled: GlobalConfig.lock.enableSessionControls = checked
        }

        SectionHeader {
            text: Tr.tr("Idle")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Lock before sleep")
            subtext: Tr.tr("Lock the screen before the system suspends")
            checked: Config.general.idle.lockBeforeSleep
            onToggled: GlobalConfig.general.idle.lockBeforeSleep = checked
        }

        ToggleRow {
            text: Tr.tr("Stay awake while audio plays")
            subtext: Tr.tr("Pause idle timeouts during playback")
            checked: Config.general.idle.inhibitWhenAudio
            onToggled: GlobalConfig.general.idle.inhibitWhenAudio = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Stay awake while charging")
            subtext: Tr.tr("Pause idle timeouts on AC power")
            checked: Config.general.idle.inhibitWhenCharging
            onToggled: GlobalConfig.general.idle.inhibitWhenCharging = checked
        }

        SectionHeader {
            text: Tr.tr("Other unlock methods")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Fingerprint")
            subtext: Tr.tr("Unlock with fprintd")
            checked: GlobalConfig.lock.enableFprint
            onToggled: GlobalConfig.lock.enableFprint = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Face (Howdy)")
            subtext: Tr.tr("Unlock with Howdy face recognition")
            checked: GlobalConfig.lock.enableHowdy
            onToggled: GlobalConfig.lock.enableHowdy = checked
        }
    }
}
