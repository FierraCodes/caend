pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services

// Keybind cheatsheet (SUPER + /): a keyboard whose keys show what they do on the current
// modifier layer. Hold any mix of SUPER/CTRL/ALT/SHIFT (or click them) to switch layers,
// hover a key to read its binds. Binds come from the compositor (see services/Keybinds.qml).
Scope {
    id: root

    readonly property int superBit: Keybinds.mod.superKey
    readonly property int ctrlBit: Keybinds.mod.ctrl
    readonly property int altBit: Keybinds.mod.alt
    readonly property int shiftBit: Keybinds.mod.shift

    // [label, keysym names (lower case), width in key units, modifier bit, glyph icon]
    readonly property var rows: buildRows()
    // Set of keysym names drawn on the keyboard
    readonly property var keyboardNames: {
        const names = {};
        for (const row of rows)
            for (const k of row)
                for (const n of k.names)
                    names[n] = true;
        return names;
    }

    function buildRows(): var {
        const rows = [];
        rows.push([["Esc", ["escape"], 1], ["", [], 0.5], ...[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].map(n => [`F${n}`, [`f${n}`], 1]), ["", [], 0.5], ["Print", ["print"], 1.25], ["Del", ["delete"], 1.25]]);
        rows.push([["`", ["grave"], 1], ...["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map(n => [n, [n], 1]), ["-", ["minus"], 1], ["=", ["equal"], 1], ["", ["backspace"], 2, 0, "backspace"], ["PgUp", ["page_up", "prior"], 1.25]]);
        rows.push([["", ["tab"], 1.5, 0, "keyboard_tab"], ..."QWERTYUIOP".split("").map(c => [c, [c.toLowerCase()], 1]), ["[", ["bracketleft"], 1], ["]", ["bracketright"], 1], ["\\", ["backslash"], 1.5], ["PgDn", ["page_down", "next"], 1.25]]);
        rows.push([["", ["caps_lock"], 1.75, 0, "keyboard_capslock"], ..."ASDFGHJKL".split("").map(c => [c, [c.toLowerCase()], 1]), [";", ["semicolon"], 1], ["'", ["apostrophe"], 1], ["", ["return", "enter"], 2.25, 0, "keyboard_return"], ["Home", ["home"], 1.25]]);
        rows.push([["Shift", ["shift_l"], 2.25, shiftBit], ..."ZXCVBNM".split("").map(c => [c, [c.toLowerCase()], 1]), [",", ["comma"], 1], [".", ["period"], 1], ["/", ["slash"], 1], ["Shift", ["shift_r"], 1.75, shiftBit], ["", ["up"], 1, 0, "keyboard_arrow_up"], ["End", ["end"], 1.25]]);
        rows.push([["Ctrl", ["control_l"], 1.5, ctrlBit], ["Super", ["super_l"], 1.25, superBit], ["Alt", ["alt_l"], 1.25, altBit], ["", ["space"], 6, 0, "space_bar"], ["Alt", ["alt_r"], 1.25, altBit], ["Super", ["super_r"], 1.25, superBit], ["Ctrl", ["control_r"], 1.25, ctrlBit], ["", ["left"], 1, 0, "keyboard_arrow_left"], ["", ["down"], 1, 0, "keyboard_arrow_down"], ["", ["right"], 1, 0, "keyboard_arrow_right"], ["", [], 0.25]]);
        // Objects, not tuples: nested JS arrays don't survive a var property / Repeater model intact
        return rows.map(r => r.map(([label, names, units, bit = 0, glyph = ""]) => ({
                        label,
                        names,
                        units,
                        bit,
                        glyph
                    })));
    }

    function modNames(mask: int): list<string> {
        const out = [];
        if (mask & superBit)
            out.push("SUPER");
        if (mask & ctrlBit)
            out.push("CTRL");
        if (mask & altBit)
            out.push("ALT");
        if (mask & shiftBit)
            out.push("SHIFT");
        return out;
    }

    LazyLoader {
        active: Keybinds.open

        StyledWindow {
            id: win

            // Clicked modifiers stick; held ones apply only while held
            property int latched
            property int held
            readonly property int layer: (held | (Keybinds.superHeld ? root.superBit : 0)) || latched
            property var hoveredKey: null

            // keysym name -> binds on this layer
            readonly property var layerBinds: {
                const map = {};
                for (const b of Keybinds.binds)
                    if (b.mods === layer)
                        map[b.key] = [...(map[b.key] ?? []), b];
                return map;
            }
            readonly property var otherBinds: {
                const out = [];
                for (const k of Object.keys(layerBinds))
                    if (!root.keyboardNames[k])
                        out.push(...layerBinds[k]);
                return out;
            }

            function bitFor(key: int): int {
                switch (key) {
                case Qt.Key_Shift:
                    return root.shiftBit;
                case Qt.Key_Control:
                    return root.ctrlBit;
                case Qt.Key_Alt:
                case Qt.Key_AltGr:
                    return root.altBit;
                case Qt.Key_Meta:
                case Qt.Key_Super_L:
                case Qt.Key_Super_R:
                    return root.superBit;
                }
                return 0;
            }

            // Qt modifier flags -> Hyprland modmask bits
            function maskOf(mods: int): int {
                return (mods & Qt.ShiftModifier ? root.shiftBit : 0) | (mods & Qt.ControlModifier ? root.ctrlBit : 0) | (mods & Qt.AltModifier ? root.altBit : 0) | (mods & Qt.MetaModifier ? root.superBit : 0);
            }

            function bindsFor(names: var): var {
                // Plain loops: V4 has no flat/flatMap
                const out = [];
                for (const n of names)
                    out.push(...(layerBinds[n] ?? []));
                return out;
            }

            name: "cheatsheet"
            screen: Quickshell.screens.find(s => Compositor.isFocusedScreen(s)) ?? Quickshell.screens[0]

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            StyledRect {
                anchors.fill: parent
                color: Qt.alpha(Colours.palette.m3scrim, 0.5)

                // Eat clicks outside the card; only the close button (or SUPER + /) closes it
                MouseArea {
                    anchors.fill: parent
                }
            }

            StyledRect {
                id: card

                readonly property real unit: Math.min(52, (win.width - Tokens.padding.extraLargeIncreased * 2) / 16.5)

                anchors.centerIn: parent
                implicitWidth: layout.implicitWidth + Tokens.padding.large * 3
                implicitHeight: layout.implicitHeight + Tokens.padding.large * 3
                radius: Tokens.rounding.extraLarge
                color: Colours.tPalette.m3surfaceContainer

                scale: 0.9
                Component.onCompleted: scale = 1

                Behavior on scale {
                    Anim {}
                }

                Elevation {
                    anchors.fill: parent
                    radius: parent.radius
                    z: -1
                    level: 3
                }

                Item {
                    focus: true
                    Component.onCompleted: forceActiveFocus()

                    Keys.onPressed: event => {
                        if (!event.isAutoRepeat)
                            win.held = win.maskOf(event.modifiers) | win.bitFor(event.key);
                        event.accepted = true;
                    }
                    Keys.onReleased: event => {
                        if (!event.isAutoRepeat)
                            win.held = win.maskOf(event.modifiers) & ~win.bitFor(event.key);
                        event.accepted = true;
                    }
                }

                ColumnLayout {
                    id: layout

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.medium

                    RowLayout {
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: "keyboard"
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.large
                        }

                        StyledText {
                            text: Tr.tr("Keybinds")
                            font: Tokens.font.title.medium
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Repeater {
                            model: [root.superBit, root.ctrlBit, root.altBit, root.shiftBit]

                            StyledRect {
                                id: chip

                                required property int modelData
                                readonly property bool active: win.layer & modelData

                                implicitWidth: chipLabel.implicitWidth + Tokens.padding.large * 2
                                implicitHeight: chipLabel.implicitHeight + Tokens.padding.small * 2
                                radius: Tokens.rounding.full
                                color: active ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHighest

                                StateLayer {
                                    color: chip.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                    onClicked: win.latched ^= chip.modelData
                                }

                                StyledText {
                                    id: chipLabel

                                    anchors.centerIn: parent
                                    text: root.modNames(chip.modelData)[0]
                                    color: chip.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.label.medium
                                }
                            }
                        }

                        IconButton {
                            type: IconButton.Text
                            icon: "close"
                            onClicked: Keybinds.open = false
                        }
                    }

                    // Keyboard
                    Column {
                        spacing: card.unit * 0.12

                        Repeater {
                            model: root.rows

                            Row {
                                id: keyRow

                                required property var modelData

                                spacing: card.unit * 0.12

                                Repeater {
                                    model: keyRow.modelData

                                    Keycap {
                                        unit: card.unit
                                        layerMask: win.layer
                                        binds: win.bindsFor(modelData.names)
                                        hovered: win.hoveredKey === modelData
                                        onHover: inside => {
                                            if (inside)
                                                win.hoveredKey = modelData;
                                            else if (win.hoveredKey === modelData)
                                                win.hoveredKey = null;
                                        }
                                        onToggled: bit => win.latched ^= bit
                                    }
                                }
                            }
                        }
                    }

                    // Non-keyboard binds on this layer (mouse, media keys, ...)
                    Flow {
                        Layout.fillWidth: true
                        Layout.maximumWidth: card.unit * 16
                        visible: win.otherBinds.length > 0
                        spacing: Tokens.spacing.small

                        Repeater {
                            model: win.otherBinds

                            StyledRect {
                                id: other

                                required property var modelData

                                implicitWidth: otherRow.implicitWidth + Tokens.padding.medium * 2
                                implicitHeight: otherRow.implicitHeight + Tokens.padding.small * 2
                                radius: Tokens.rounding.full
                                color: Colours.tPalette.m3surfaceContainerHigh

                                RowLayout {
                                    id: otherRow

                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.small

                                    MaterialIcon {
                                        text: other.modelData.icon
                                        color: Colours.palette.m3secondary
                                    }

                                    StyledText {
                                        text: `${other.modelData.key}  ${other.modelData.label}`
                                        color: Colours.palette.m3onSurfaceVariant
                                        font: Tokens.font.body.small
                                    }
                                }
                            }
                        }
                    }

                    // Details of the hovered key
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.maximumWidth: card.unit * 16
                        implicitHeight: Math.max(card.unit * 1.2, details.implicitHeight + Tokens.padding.medium * 2)
                        radius: Tokens.rounding.large
                        color: Colours.tPalette.m3surfaceContainerHigh

                        ColumnLayout {
                            id: details

                            readonly property var binds: win.hoveredKey ? win.bindsFor(win.hoveredKey.names) : []

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Tokens.padding.large
                            spacing: Tokens.spacing.small

                            StyledText {
                                visible: details.binds.length === 0
                                text: win.hoveredKey ? Tr.tr("Nothing bound to %1 on this layer").arg([...root.modNames(win.layer), win.hoveredKey.label || win.hoveredKey.names[0]].join(" + ")) : Tr.tr("Hold or click SUPER, CTRL, ALT and SHIFT to switch layers. Hover a key to see what it does.")
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.body.medium
                            }

                            Repeater {
                                model: details.binds

                                RowLayout {
                                    id: detail

                                    required property var modelData

                                    spacing: Tokens.spacing.medium

                                    MaterialIcon {
                                        text: detail.modelData.icon
                                        color: Colours.palette.m3primary
                                        fontStyle: Tokens.font.icon.medium
                                    }

                                    StyledText {
                                        text: [...root.modNames(detail.modelData.mods), detail.modelData.key.toUpperCase()].join(" + ")
                                        color: Colours.palette.m3secondary
                                        font: Tokens.font.label.medium
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: detail.modelData.label
                                        elide: Text.ElideRight
                                        font: Tokens.font.body.medium
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
