pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar.components
import qs.modules.bar.popouts as BarPopouts
import qs.modules.bar.components.workspaces

GridLayout {
    id: root

    required property ShellScreen screen
    required property bool horizontal
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    readonly property int vPadding: Tokens.padding.large
    readonly property int spacing: Tokens.spacing.medium

    // Coordinate along the bar's long axis
    function along(p: point): real {
        return horizontal ? p.x : p.y;
    }

    function centerOf(item: Item): real {
        return along(item.mapToItem(root, item.width / 2, item.height / 2));
    }

    // Child of `item` at bar coordinate `pos`, probing the middle of the cross axis
    function childAlong(item: Item, pos: real): Item {
        if (horizontal)
            return item.childAt(mapToItem(item, pos, 0).x, item.height / 2);
        return item.childAt(item.width / 2, mapToItem(item, 0, pos).y);
    }

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        for (let i = 0; i < repeater.count; i++) {
            const tray = (repeater.itemAt(i) as EntryWrapper)?.item as Tray;
            if (tray)
                tray.expanded = false;
        }
    }

    function checkPopout(pos: real): void {
        const ch = childAlong(root, pos) as EntryWrapper;

        if (ch?.entryId !== "tray")
            closeTray();

        if (!ch) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.entryId;
        const start = horizontal ? ch.x : ch.y;

        if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items = (ch.item as StatusIcons).items;
            const icon = childAlong(items, pos);
            if (icon) {
                popouts.currentName = icon.name;
                popouts.currentCenter = Qt.binding(() => centerOf(icon));
                popouts.hasCurrent = true;
            }
        } else if (id === "tray" && Config.bar.popouts.tray) {
            const tray = ch.item as Tray;
            const probe = horizontal ? mapToItem(tray.expandIcon, pos, tray.implicitHeight / 2) : mapToItem(tray.expandIcon, tray.implicitWidth / 2, pos);
            const layoutLength = horizontal ? tray.layout.implicitWidth : tray.layout.implicitHeight;
            const index = Math.floor(((pos - start - tray.padding * 2 + tray.spacing) / layoutLength) * tray.items.count);
            if (!Config.bar.tray.compact || (!tray.expandIcon.contains(probe) && (tray.expanded || index < tray.pinnedCount))) {
                const trayItem = tray.items.itemAt(index);
                if (trayItem) {
                    popouts.currentName = `traymenu${index}`;
                    popouts.currentCenter = Qt.binding(() => centerOf(trayItem));
                    popouts.hasCurrent = true;
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
                tray.expanded = true;
            }
        } else if (id === "media" && !horizontal && Players.active) {
            // A side bar's media pill has no room for text, so the details live in a popout
            popouts.currentName = id;
            popouts.currentCenter = Qt.binding(() => centerOf(ch.item as Item));
            popouts.hasCurrent = true;
        } else if (id === "activeWindow" && Config.bar.popouts.activeWindow && Config.bar.activeWindow.showOnHover) {
            popouts.currentName = id.toLowerCase();
            popouts.currentCenter = centerOf(ch.item as Item);
            popouts.hasCurrent = true;
        }
    }

    function handleWheel(pos: real, angleDelta: point): void {
        const ch = childAlong(root, pos) as EntryWrapper;
        if (ch?.entryId === "workspaces" && Config.bar.scrollActions.workspaces) {
            // Workspace scroll
            if (Compositor.isHyprland) {
                const mon = Hypr.monitorFor(screen);
                const specialWs = mon?.lastIpcObject.specialWorkspace.name;
                if (specialWs?.length > 0) {
                    Compositor.toggleSpecial(specialWs.slice(8));
                    return;
                }
                if (angleDelta.y > 0 && !(mon?.activeWorkspace?.id > 1))
                    return;
            }
            Compositor.focusWorkspaceRelative(angleDelta.y > 0 ? -1 : 1);
        } else if (pos < (horizontal ? screen.width : screen.height) / 2 && Config.bar.scrollActions.volume) {
            // Volume scroll on top/left half
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            // Brightness scroll on bottom half
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
        }
    }

    flow: horizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
    rowSpacing: spacing
    columnSpacing: spacing

    Repeater {
        id: repeater

        model: ScriptModel {
            values: root.Config.bar.entries.values.filter(e => e.enabled)
        }

        DelegateChooser {
            role: "id"

            DelegateChoice {
                roleValue: "spacer"
                delegate: EntryWrapper {
                    Layout.fillHeight: !root.horizontal
                    Layout.fillWidth: root.horizontal
                }
            }
            DelegateChoice {
                roleValue: "logo"
                delegate: EntryWrapper {
                    OsIcon {
                        objectName: "taskbarLogo"
                    }
                }
            }
            DelegateChoice {
                roleValue: "workspaces"
                delegate: EntryWrapper {
                    // Horizontal bars reuse the vertical widget turned on its side; Workspace counter-rotates its glyphs
                    Item {
                        implicitWidth: root.horizontal ? workspaces.implicitHeight : workspaces.implicitWidth
                        implicitHeight: root.horizontal ? workspaces.implicitWidth : workspaces.implicitHeight

                        Loader {
                            id: workspaces

                            objectName: "taskbarWorkspaces"
                            anchors.centerIn: parent
                            rotation: root.horizontal ? -90 : 0
                            sourceComponent: Compositor.isNiri ? niriWs : hyprWs
                        }

                        Component {
                            id: hyprWs

                            Workspaces {
                                screen: root.screen
                                fullscreen: root.fullscreen
                            }
                        }

                        Component {
                            id: niriWs

                            NiriWorkspaces {
                                screen: root.screen
                                fullscreen: root.fullscreen
                            }
                        }
                    }
                }
            }
            DelegateChoice {
                roleValue: "activeWindow"
                delegate: EntryWrapper {
                    ActiveWindow {
                        objectName: "taskbarActiveWindow"
                        bar: root
                        monitor: Brightness.getMonitorForScreen(root.screen)
                    }
                }
            }
            DelegateChoice {
                roleValue: "tray"
                delegate: EntryWrapper {
                    Tray {
                        objectName: "taskbarTray"
                    }
                }
            }
            DelegateChoice {
                roleValue: "clock"
                delegate: EntryWrapper {
                    Clock {
                        objectName: "taskbarClock"
                    }
                }
            }
            DelegateChoice {
                roleValue: "statusIcons"
                delegate: EntryWrapper {
                    StatusIcons {
                        objectName: "taskbarStatusIcons"
                    }
                }
            }
            DelegateChoice {
                roleValue: "resources"
                delegate: EntryWrapper {
                    BarResources {}
                }
            }
            DelegateChoice {
                roleValue: "weather"
                delegate: EntryWrapper {
                    BarWeather {
                        screenState: root.screenState
                    }
                }
            }
            DelegateChoice {
                roleValue: "media"
                delegate: EntryWrapper {
                    BarMedia {
                        screenState: root.screenState
                    }
                }
            }
            DelegateChoice {
                roleValue: "utilButtons"
                delegate: EntryWrapper {
                    UtilButtons {}
                }
            }
            DelegateChoice {
                roleValue: "power"
                delegate: EntryWrapper {
                    Power {
                        objectName: "taskbarPowerButton"
                        screenState: root.screenState
                    }
                }
            }
        }
    }

    component EntryWrapper: Item {
        required property var modelData
        required property int index
        default property Item item
        readonly property string entryId: modelData.id

        readonly property real startMargin: index === 0 ? root.vPadding : 0
        readonly property real endMargin: index === repeater.count - 1 ? root.vPadding : 0

        Layout.topMargin: root.horizontal ? 0 : startMargin
        Layout.bottomMargin: root.horizontal ? 0 : endMargin
        Layout.leftMargin: root.horizontal ? startMargin : 0
        Layout.rightMargin: root.horizontal ? endMargin : 0
        Layout.alignment: Qt.AlignCenter

        implicitWidth: item?.implicitWidth ?? 0
        implicitHeight: item?.implicitHeight ?? 0

        children: item
    }
}
