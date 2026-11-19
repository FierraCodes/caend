pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n

// Extra launcher results in the shape ActionItem shows: web search, shell commands and clipboard history
Singleton {
    id: root

    property list<string> clipboardEntries: [] // Raw `cliphist list` lines: "<id>\t<preview>"

    function web(query: string): var {
        query = query.trim();
        return {
            name: Tr.tr("Search the web"),
            desc: query || Tr.tr("Type something to search for"),
            icon: "travel_explore",
            onClicked: list => {
                if (!query)
                    return;
                list.screenState.launcher = false;
                Qt.openUrlExternally(GlobalConfig.launcher.webSearchUrl.replace("%s", encodeURIComponent(query)));
            }
        };
    }

    function shell(command: string): list<var> {
        command = command.trim();
        const run = (list, inTerminal) => {
            if (!command)
                return;
            list.screenState.launcher = false;
            // Keeps the terminal open after the command so its output can be read
            Quickshell.execDetached(inTerminal ? [...GlobalConfig.general.apps.terminal, "sh", "-c", `${command}; exec "\${SHELL:-sh}"`] : ["sh", "-c", command]);
        };
        return [
            {
                name: Tr.tr("Run command"),
                desc: command || Tr.tr("Type a shell command"),
                icon: "play_arrow",
                onClicked: list => run(list, false)
            },
            {
                name: Tr.tr("Run in terminal"),
                desc: command || Tr.tr("Type a shell command"),
                icon: "terminal",
                onClicked: list => run(list, true)
            }
        ];
    }

    function clipboard(query: string): list<var> {
        query = query.trim().toLowerCase();
        return clipboardEntries.filter(e => !query || e.toLowerCase().includes(query)).slice(0, 50).map(entry => {
            const preview = entry.slice(entry.indexOf("\t") + 1);
            return {
                name: preview.slice(0, 120),
                desc: Tr.tr("Copy to clipboard"),
                icon: preview.startsWith("[[ binary data") ? "image" : "content_paste",
                onClicked: list => {
                    list.screenState.launcher = false;
                    // Entry passed as an argument, never spliced into the script
                    Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", entry]);
                }
            };
        });
    }

    function reloadClipboard(): void {
        cliphist.running = true;
    }

    Process {
        id: cliphist

        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.clipboardEntries = text.split("\n").filter(l => l.trim())
        }
    }
}
