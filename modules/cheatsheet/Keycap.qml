import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// One key of the cheatsheet keyboard. modelData: [label, keysym names, width in units, modifier bit, glyph icon]
StyledRect {
    id: key

    required property var modelData
    required property real unit
    required property int layerMask
    required property var binds
    property bool hovered
    readonly property real units: modelData[2]
    readonly property int modBit: modelData[3] ?? 0
    readonly property bool spacer: modelData[1].length === 0
    readonly property bool bound: binds.length > 0
    readonly property bool modOn: modBit && (layerMask & modBit)

    signal hover(inside: bool)
    signal toggled(bit: int)

    width: unit * units - (spacer ? 0 : unit * 0.12)
    height: unit
    radius: Tokens.rounding.small
    opacity: spacer ? 0 : 1
    color: modOn ? Colours.palette.m3primary : bound ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHighest
    border.width: hovered ? 2 : 0
    border.color: Colours.palette.m3primary

    StateLayer {
        visible: !key.spacer
        color: key.modOn ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
        onContainsMouseChanged: key.hover(containsMouse)
        onClicked: if (key.modBit)
            key.toggled(key.modBit)
    }

    // Action icon for bound keys; glyph for keys like Enter or arrows
    MaterialIcon {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: key.bound && (key.modelData[0] || key.modelData[4]) ? -key.unit * 0.1 : 0
        visible: key.bound || (!key.modelData[0] && key.modelData[4])
        text: key.bound ? key.binds[0].icon : key.modelData[4] ?? ""
        color: key.bound ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
        fill: key.bound ? 1 : 0
        fontStyle: Tokens.font.icon.builders.medium.scale(key.unit / 52).build()
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: key.unit * 0.06
        visible: key.bound && (key.modelData[0] || key.modelData[4])
        text: key.modelData[0] || ""
        color: Colours.palette.m3onSecondaryContainer
        font: Tokens.font.label.builders.small.scale(key.unit / 60).build()
    }

    MaterialIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: key.unit * 0.04
        visible: key.bound && !key.modelData[0] && key.modelData[4]
        text: key.modelData[4] ?? ""
        color: Colours.palette.m3onSecondaryContainer
        fontStyle: Tokens.font.icon.builders.small.scale(key.unit / 60).build()
    }

    StyledText {
        anchors.centerIn: parent
        visible: !key.bound && !!key.modelData[0]
        text: key.modelData[0]
        color: key.modOn ? Colours.palette.m3onPrimary : Colours.palette.m3outline
        font: Tokens.font.body.builders.medium.scale(key.unit / 52).build()
    }
}
