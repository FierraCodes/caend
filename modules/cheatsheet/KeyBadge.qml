import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Small keycap-style badge with a key's name
StyledRect {
    id: root

    property alias text: label.text

    implicitWidth: label.implicitWidth + Tokens.padding.small * 2
    implicitHeight: label.implicitHeight + Tokens.padding.extraSmall
    radius: Tokens.rounding.extraSmall
    color: Colours.palette.m3secondaryContainer

    StyledText {
        id: label

        anchors.centerIn: parent
        color: Colours.palette.m3onSecondaryContainer
        font: Tokens.font.label.small
    }
}
