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
import qs.modules.lock as Lock

// Recent notifications on the main dash page. Binds straight to the Notifs
// service (event-driven), and reuses the lock screen's grouped notif cards.
ColumnLayout {
    id: root

    // Not implicitWidth: ColumnLayout overwrites that with its children's width.
    // Cards match popup notifications (Content.qml: width - padding - clampedPadding).
    readonly property real cardWidth: Tokens.sizes.notifs.width + Tokens.padding.large - Math.max(0, Math.min(Tokens.padding.large - Config.border.thickness, Tokens.padding.large))

    anchors.fill: parent
    anchors.margins: Tokens.padding.large

    spacing: Tokens.spacing.medium

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
            Layout.fillWidth: true
            text: Notifs.notClosed.length > 0 ? Tr.trN("%n notification", "%n notifications", Notifs.notClosed.length) : Tr.tr("Notifications")
            color: Colours.palette.m3outline
            font: Tokens.font.mono.builders.small.weight(Font.Medium).build()
            elide: Text.ElideRight
        }

        IconButton {
            isRound: true
            icon: "clear_all"
            type: IconButton.Text
            font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
            enabled: Notifs.notClosed.length > 0
            opacity: enabled ? 1 : 0
            onClicked: {
                for (const n of Notifs.notClosed.slice())
                    n.close();
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
    }

    ClipRect {
        Layout.fillWidth: true
        Layout.fillHeight: true

        radius: Tokens.rounding.medium
        color: "transparent"

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Tokens.spacing.small
            opacity: list.count > 0 ? 0 : 1
            visible: opacity > 0

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "notifications_off"
                color: Colours.palette.m3outlineVariant
                font.pointSize: Tokens.font.title.large.pointSize * 1.5
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Tr.tr("No notifications")
                color: Colours.palette.m3outlineVariant
                font: Tokens.font.mono.builders.large.weight(Font.Medium).build()
            }

            Behavior on opacity {
                Anim {
                    type: Anim.StandardLarge
                }
            }
        }

        StyledListView {
            id: list

            anchors.fill: parent
            spacing: Tokens.spacing.small
            clip: true

            // Notifs.list is newest-first, so groups are too.
            model: ScriptModel {
                values: [...new Set(Notifs.notClosed.map(n => n.appName))]
            }

            delegate: Lock.NotifGroup {}

            add: Transition {
                Anim {
                    type: Anim.DefaultEffects
                    property: "opacity"
                    from: 0
                    to: 1
                }
                Anim {
                    property: "scale"
                    from: 0
                    to: 1
                }
            }

            remove: Transition {
                Anim {
                    type: Anim.DefaultEffects
                    property: "opacity"
                    to: 0
                }
                Anim {
                    property: "scale"
                    to: 0.6
                }
            }

            displaced: Transition {
                Anim {
                    type: Anim.DefaultEffects
                    properties: "opacity,scale"
                    to: 1
                }
                Anim {
                    property: "y"
                }
            }
        }
    }
}
