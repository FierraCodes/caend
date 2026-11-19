pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Caelestia
import Caelestia.Config
import Caelestia.I18n

// fcitx5 integration. fcitx5 has no D-Bus signal for input method switches, but its tray item
// changes icon/tooltip when one happens, so that change triggers a one-shot `fcitx5-remote -n`
Singleton {
    id: root

    readonly property SystemTrayItem item: SystemTray.items.values.find(i => i.id === "Fcitx") ?? null
    readonly property bool available: !!item
    property string current // fcitx5 unique name, e.g. keyboard-us, pinyin, mozc
    readonly property string label: {
        if (!current)
            return "";
        if (current.startsWith("keyboard-"))
            return current.slice(9).split("-")[0].toUpperCase();
        return current.slice(0, 2).toUpperCase();
    }

    function toggle(): void {
        Quickshell.execDetached(["fcitx5-remote", "-t"]);
    }

    function refresh(): void {
        if (available)
            query.running = true;
    }

    onAvailableChanged: refresh()

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
                const name = text.trim();
                if (!name || name === root.current)
                    return;
                const first = !root.current;
                root.current = name;
                if (!first && GlobalConfig.utilities.toasts.inputMethodChanged)
                    // TRANSLATORS: %1 = an fcitx5 input method name, e.g. pinyin or keyboard-us
                    Toaster.toast(Tr.tr("Input method changed"), Tr.tr("Input method changed to: %1").arg(name), "translate");
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
