pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

// fcitx5 integration. fcitx5 has no D-Bus signal for input method switches, but its tray item
// changes icon/tooltip when one happens, so that change triggers a one-shot `fcitx5-remote -n`
Singleton {
    id: root

    readonly property SystemTrayItem item: SystemTray.items.values.find(i => i.id === "Fcitx") ?? null
    readonly property bool available: !!item
    property string current // fcitx5 unique name, e.g. keyboard-us, pinyin, mozc

    function toggle(): void {
        Quickshell.execDetached(["fcitx5-remote", "-t"]);
    }

    function refresh(): void {
        if (available)
            query.running = true;
    }

    onAvailableChanged: refresh()
    Component.onCompleted: refresh() // fcitx5 may already be in the tray when the shell starts

    Connections {
        function onIconChanged(): void {
            root.refresh();
        }

        function onTooltipTitleChanged(): void {
            root.refresh();
        }

        function onTooltipDescriptionChanged(): void {
            root.refresh();
        }

        target: root.item
    }

    Process {
        id: query

        command: ["fcitx5-remote", "-n"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.current = text.trim();
            }
        }
    }

    IpcHandler {
        function get(): string {
            return root.current;
        }

        function toggle(): void {
            root.toggle();
        }

        target: "inputMethod"
    }
}
