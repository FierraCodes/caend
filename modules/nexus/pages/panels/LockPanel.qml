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
            last: true
            text: Tr.tr("Session controls")
            subtext: Tr.tr("Show shutdown, reboot and logout on the lock screen")
            checked: GlobalConfig.lock.enableSessionControls
            onToggled: GlobalConfig.lock.enableSessionControls = checked
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
