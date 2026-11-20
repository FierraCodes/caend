pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    property string selectedName
    readonly property var mon: Monitors.monitors.find(m => m.name === selectedName) ?? Monitors.monitors[0] ?? null

    // "WxH" -> modes at that size, highest refresh first
    readonly property var modesBySize: {
        const out = {};
        for (const mode of root.mon?.modes ?? []) {
            const p = Monitors.parseMode(mode);
            if (!p)
                continue;
            const key = `${p.width}x${p.height}`;
            out[key] = [...(out[key] ?? []), mode];
        }
        for (const k in out)
            out[k].sort((a, b) => Monitors.parseMode(b).refresh - Monitors.parseMode(a).refresh);
        return out;
    }
    readonly property string currentSize: {
        const p = Monitors.parseMode(root.mon?.mode ?? "");
        return p ? `${p.width}x${p.height}` : "";
    }

    readonly property list<string> transformLabels: [Tr.trCtx("Normal", "display rotation"), "90°", "180°", "270°", Tr.trCtx("Flipped", "display rotation"), Tr.tr("Flipped 90°"), Tr.tr("Flipped 180°"), Tr.tr("Flipped 270°")]
    readonly property list<string> colourModes: ["auto", "srgb", "wide", "edid", "hdr", "hdredid"]

    function change(changes: var): void {
        if (root.mon)
            Monitors.set(root.mon.name, changes);
    }

    title: Tr.tr("Display")

    Component.onCompleted: Monitors.refresh()

    Item {
        width: root.flickable.width
        implicitHeight: content.implicitHeight + (Monitors.snapshot ? confirm.height + Tokens.spacing.large : 0)

        ColumnLayout {
            id: content

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: root.cappedWidth
            spacing: Tokens.spacing.extraSmall / 2

            Variants {
                id: monitorItems

                model: Monitors.monitors

                MenuItem {
                    required property var modelData

                    text: modelData.description ? `${modelData.name} · ${modelData.description}` : modelData.name
                    icon: modelData.disabled ? "desktop_access_disabled" : "monitor"
                    value: modelData.name
                }
            }

            Variants {
                id: sizeItems

                // shortcut: menus don't scroll, so only the 8 largest sizes (plus the current one) fit; add scrolling to Menu if people need tiny modes
                model: {
                    const sizes = Object.keys(root.modesBySize).sort((a, b) => {
                        const [aw, ah] = a.split("x"), [bw, bh] = b.split("x");
                        return bw * bh - aw * ah || bw - aw;
                    }).slice(0, 8);
                    return sizes.includes(root.currentSize) || !root.currentSize ? sizes : [...sizes, root.currentSize];
                }

                MenuItem {
                    required property string modelData

                    text: modelData.replace("x", " × ")
                    value: modelData
                }
            }

            Variants {
                id: refreshItems

                // One entry per whole Hz (144 and 143.97 look the same), highest first, so the menu fits on screen
                model: {
                    const seen = new Set();
                    return (root.modesBySize[root.currentSize] ?? []).filter(mode => {
                        const hz = Math.round(Monitors.parseMode(mode).refresh);
                        const keep = mode === root.mon?.mode || !seen.has(hz);
                        seen.add(hz);
                        return keep;
                    });
                }

                MenuItem {
                    required property string modelData

                    text: `${+Monitors.parseMode(modelData).refresh.toFixed(2)} Hz`
                    value: modelData
                }
            }

            Variants {
                id: transformItems

                model: root.transformLabels.map((label, i) => ({
                            label,
                            i
                        }))

                MenuItem {
                    required property var modelData

                    text: modelData.label
                    value: modelData.i
                }
            }

            Variants {
                id: depthItems

                model: [8, 10]

                MenuItem {
                    required property int modelData

                    text: Tr.tr("%1-bit").arg(modelData)
                    value: modelData
                }
            }

            Variants {
                id: colourItems

                model: root.colourModes

                MenuItem {
                    required property string modelData

                    text: modelData === "auto" ? Tr.trCtx("Auto", "colour mode") : modelData.toUpperCase().replace("HDREDID", "HDR (EDID)").replace("SRGB", "sRGB")
                    value: modelData
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: !Monitors.supported
                text: Tr.tr("Display settings need Hyprland or Niri.")
                color: Colours.palette.m3outline
                font: Tokens.font.body.large
                wrapMode: Text.WordWrap
            }

            SectionHeader {
                first: true
                visible: Monitors.monitors.length > 0
                text: Tr.tr("Arrangement")
            }

            // Drag outputs to arrange them; they snap to each other's edges
            ConnectedRect {
                id: canvas

                readonly property real pad: Tokens.padding.extraLarge
                readonly property var active: Monitors.monitors.filter(m => !m.disabled)
                readonly property var bounds: {
                    if (!active.length)
                        return {
                            x: 0,
                            y: 0,
                            w: 1920,
                            h: 1080
                        };
                    const rects = active.map(m => Object.assign({
                            x: m.x,
                            y: m.y
                        }, Monitors.logicalSize(m)));
                    const x = Math.min(...rects.map(r => r.x)), y = Math.min(...rects.map(r => r.y));
                    return {
                        x,
                        y,
                        w: Math.max(...rects.map(r => r.x + r.w)) - x,
                        h: Math.max(...rects.map(r => r.y + r.h)) - y
                    };
                }
                readonly property real k: Math.min((width - pad * 2) / bounds.w, (height - pad * 2) / bounds.h)

                Layout.fillWidth: true
                visible: Monitors.monitors.length > 0
                implicitHeight: 240
                first: true
                last: true

                Repeater {
                    model: canvas.active

                    StyledRect {
                        id: outputRect

                        required property var modelData
                        readonly property var size: Monitors.logicalSize(modelData)
                        readonly property bool selected: modelData.name === root.mon?.name
                        property real dx
                        property real dy

                        x: (canvas.width - canvas.bounds.w * canvas.k) / 2 + (modelData.x - canvas.bounds.x) * canvas.k + dx
                        y: (canvas.height - canvas.bounds.h * canvas.k) / 2 + (modelData.y - canvas.bounds.y) * canvas.k + dy
                        z: drag.pressed ? 1 : 0
                        implicitWidth: size.w * canvas.k
                        implicitHeight: size.h * canvas.k
                        radius: Tokens.rounding.small
                        color: selected ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHighest
                        border.width: selected ? 2 : 0
                        border.color: Colours.palette.m3primary

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - Tokens.padding.small * 2
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: outputRect.modelData.name
                                color: outputRect.selected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                font: Tokens.font.label.medium
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: outputRect.modelData.mode.replace(/@.*/, "").replace("x", " × ")
                                color: outputRect.selected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3outline
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: drag

                            property point start

                            anchors.fill: parent
                            preventStealing: true // otherwise the page's flickable takes the drag
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            onPressed: e => {
                                root.selectedName = outputRect.modelData.name;
                                start = mapToItem(canvas, e.x, e.y);
                            }
                            onPositionChanged: e => {
                                const p = mapToItem(canvas, e.x, e.y);
                                outputRect.dx = p.x - start.x;
                                outputRect.dy = p.y - start.y;
                            }
                            onReleased: {
                                const dx = outputRect.dx, dy = outputRect.dy;
                                outputRect.dx = outputRect.dy = 0; // reset first so a failed drop never leaves the tile stranded
                                if (Math.hypot(dx, dy) > 3)
                                    Monitors.arrange(outputRect.modelData.name, outputRect.modelData.x + dx / canvas.k, outputRect.modelData.y + dy / canvas.k, 24 / canvas.k);
                            }
                            onCanceled: outputRect.dx = outputRect.dy = 0
                        }
                    }
                }
            }

            SectionHeader {
                visible: !!root.mon
                text: Tr.tr("Output")
            }

            SelectRow {
                z: 6
                first: true
                visible: !!root.mon
                label: Tr.tr("Display")
                subtext: Tr.tr("Click an output above or pick it here")
                menuItems: monitorItems.instances
                active: menuItems.find(i => i.value === root.mon?.name) ?? null
                fallbackIcon: "monitor"
                fallbackText: root.mon?.name ?? ""
                onSelected: item => root.selectedName = item.value
            }

            ToggleRow {
                visible: !!root.mon
                last: root.mon?.disabled ?? false
                text: Tr.tr("Enabled")
                subtext: Tr.tr("The last enabled display can't be turned off")
                checked: !(root.mon?.disabled ?? false)
                onToggled: root.change({
                    disabled: !checked
                })
            }

            SelectRow {
                z: 5
                visible: !!root.mon && !root.mon.disabled
                label: Tr.tr("Resolution")
                menuItems: sizeItems.instances
                active: menuItems.find(i => i.value === root.currentSize) ?? null
                fallbackText: root.currentSize
                onSelected: item => root.change({
                        mode: root.modesBySize[item.value][0]
                    })
            }

            SelectRow {
                z: 4
                visible: !!root.mon && !root.mon.disabled
                label: Tr.tr("Refresh rate")
                menuItems: refreshItems.instances
                active: menuItems.find(i => i.value === root.mon?.mode) ?? null
                fallbackText: root.mon?.mode.replace(/.*@/, "") ?? ""
                onSelected: item => root.change({
                        mode: item.value
                    })
            }

            StepperRow {
                visible: !!root.mon && !root.mon.disabled
                label: Tr.tr("Scale")
                subtext: Tr.tr("Size of everything on this display (%)")
                value: Math.round((root.mon?.scale ?? 1) * 100)
                from: 50
                to: 300
                stepSize: 5
                onMoved: v => root.change({
                        scale: v / 100
                    })
            }

            SelectRow {
                z: 3
                visible: !!root.mon && !root.mon.disabled
                label: Tr.tr("Rotation")
                menuItems: transformItems.instances
                menuOnTop: true
                active: menuItems[root.mon?.transform ?? 0] ?? null
                onSelected: item => root.change({
                        transform: item.value
                    })
            }

            ToggleRow {
                visible: !!root.mon && !root.mon.disabled
                last: !Compositor.isHyprland
                text: Tr.tr("Variable refresh rate")
                subtext: Tr.tr("Adaptive sync (FreeSync / G-Sync) if the display supports it")
                checked: root.mon?.vrr ?? false
                onToggled: root.change({
                    vrr: checked
                })
            }

            SelectRow {
                z: 2
                visible: !!root.mon && !root.mon.disabled && Compositor.isHyprland
                label: Tr.tr("Colour depth")
                menuItems: depthItems.instances
                menuOnTop: true
                active: menuItems.find(i => i.value === root.mon?.bitdepth) ?? null
                onSelected: item => root.change({
                        bitdepth: item.value
                    })
            }

            SelectRow {
                z: 1
                last: true
                visible: !!root.mon && !root.mon.disabled && Compositor.isHyprland
                label: Tr.tr("Colour mode")
                subtext: Tr.tr("HDR needs 10-bit colour and an HDR display")
                menuItems: colourItems.instances
                menuOnTop: true
                active: menuItems.find(i => i.value === root.mon?.cm) ?? null
                fallbackText: root.mon?.cm ?? ""
                onSelected: item => root.change({
                        cm: item.value
                    })
            }

            SectionHeader {
                visible: Monitors.supported
                text: Tr.tr("Saving")
            }

            InfoRow {
                first: true
                last: true
                visible: Monitors.supported
                icon: "save"
                label: Tr.tr("Kept settings are written to %1").arg(Monitors.configPath.replace(Quickshell.env("HOME"), "~"))
                subtext: Tr.tr("Add this line to your compositor config once: %1").arg(Monitors.includeLine)
            }
        }

        // Unconfirmed change: keep it or let it roll back
        ConnectedRect {
            id: confirm

            // Pinned to the bottom of the visible area so it can't be scrolled out of sight
            x: content.x
            y: root.flickable.contentY + root.flickable.height - height - Tokens.padding.large
            z: 2
            width: content.width
            visible: !!Monitors.snapshot
            first: true
            last: true
            color: Colours.palette.m3secondaryContainer
            implicitHeight: confirmRow.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: confirmRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "timer"
                    color: Colours.palette.m3onSecondaryContainer
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Keep these display settings? Reverting in %1 s").arg(Monitors.secondsLeft)
                    color: Colours.palette.m3onSecondaryContainer
                    font: Tokens.font.body.small
                    wrapMode: Text.WordWrap
                }

                TextButton {
                    type: TextButton.Text
                    isRound: true
                    text: Tr.trCtx("Revert", "button")
                    onClicked: Monitors.revert()
                }

                TextButton {
                    isRound: true
                    text: Tr.trCtx("Keep", "button")
                    onClicked: Monitors.keep()
                }
            }
        }
    }
}
