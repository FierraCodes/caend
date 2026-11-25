pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.services
import qs.utils

// end4-style search results, in the shape ActionItem shows:
// { name, desc, icon (material symbol), image (icon path), glyph (text icon), verb, favourite, onClicked(list) }
Singleton {
    id: root

    property list<string> clipboardEntries: [] // Raw `cliphist list` lines: "<id>\t<preview>"
    property var keybinds: []
    readonly property list<string> emojis: emojiFile.text().split("\n").filter(l => l && !l.startsWith("#"))
    readonly property list<string> symbols: symbolFile.text().split("\n").filter(l => l && !l.startsWith("#"))

    // Every word of the query must appear somewhere in the line
    function matches(line: string, query: string): bool {
        line = line.toLowerCase();
        return query.toLowerCase().split(/\s+/).every(w => line.includes(w));
    }

    function copy(text: string): var {
        return list => {
            list.screenState.launcher = false;
            Quickshell.clipboardText = text;
        };
    }

    // The mixed list end4 shows without a prefix: math, apps, actions, then a command and a web search
    function mixed(text: string): list<var> {
        const conf = GlobalConfig.launcher;
        const query = text.trim();
        const isMath = /^[\d(.]/.test(query);
        const apps = Apps.search(text).map(app);
        if (!query)
            return apps;

        const actions = Actions.query(conf.actionPrefix + text).slice(0, 3).map(a => ({
                    name: a.name,
                    desc: a.desc,
                    icon: a.icon,
                    verb: Tr.tr("Run"),
                    onClicked: list => a.onClicked(list)
                }));
        const results = [...(isMath ? [math(query)] : []), ...apps, ...actions];
        if (conf.showDefaultActionsWithoutPrefix)
            results.push(shell(query)[0], ...(isMath ? [] : [math(query)]), web(query));
        return results;
    }

    function app(entry: DesktopEntry): var {
        return {
            name: entry.name,
            desc: entry.comment || entry.genericName || entry.name,
            image: Quickshell.iconPath(entry.icon, "image-missing"),
            verb: Tr.tr("Open"),
            favourite: Strings.testRegexList(GlobalConfig.launcher.favouriteApps, entry.id),
            onClicked: list => {
                Apps.launch(entry);
                list.screenState.launcher = false;
            }
        };
    }

    // Qalculator.result updates asynchronously, so callers must evaluate this inside a binding
    function math(expr: string): var {
        return {
            name: expr ? (Qalculator.result || Tr.tr("Calculating...")) : Tr.tr("Type an expression to calculate"),
            desc: Tr.tr("Math result"),
            icon: "calculate",
            verb: Tr.tr("Copy"),
            onClicked: list => {
                list.screenState.launcher = false;
                Quickshell.clipboardText = Qalculator.rawResult;
            }
        };
    }

    function web(query: string): var {
        query = query.trim();
        return {
            name: query || Tr.tr("Type something to search for"),
            desc: Tr.tr("Web search"),
            icon: "travel_explore",
            verb: Tr.tr("Search"),
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
                name: command || Tr.tr("Type a shell command"),
                desc: Tr.tr("Command"),
                icon: "terminal",
                verb: Tr.tr("Run"),
                onClicked: list => run(list, false)
            },
            {
                name: command || Tr.tr("Type a shell command"),
                desc: Tr.tr("Run in terminal"),
                icon: "open_in_new",
                verb: Tr.tr("Run"),
                onClicked: list => run(list, true)
            }
        ];
    }

    function clipboard(query: string): list<var> {
        query = query.trim();
        return clipboardEntries.filter(e => !query || matches(e, query)).slice(0, 50).map(entry => {
            const preview = entry.slice(entry.indexOf("\t") + 1);
            return {
                name: preview.slice(0, 120),
                desc: Tr.tr("#%1 · Shift+Del to remove").arg(entry.slice(0, entry.indexOf("\t"))),
                entry,
                icon: preview.startsWith("[[ binary data") ? "image" : "content_paste",
                verb: Tr.tr("Copy"),
                onClicked: list => {
                    list.screenState.launcher = false;
                    // Entry passed as an argument, never spliced into the script
                    Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", entry]);
                }
            };
        });
    }

    function emoji(query: string): list<var> {
        query = query.trim();
        return emojis.filter(l => !query || matches(l, query)).slice(0, 50).map(line => {
            const [glyph, name] = line.split("\t");
            return {
                name,
                desc: Tr.tr("Emoji"),
                glyph,
                verb: Tr.tr("Copy"),
                onClicked: copy(glyph)
            };
        });
    }

    function symbol(query: string): list<var> {
        query = query.trim();
        return symbols.filter(l => !query || matches(l, query)).slice(0, 50).map(line => {
            const [name, tags] = line.split("\t");
            return {
                name,
                desc: tags ?? "",
                icon: name,
                verb: Tr.tr("Copy"),
                onClicked: copy(name)
            };
        });
    }

    function keybind(query: string): list<var> {
        query = query.trim();
        if (!Compositor.isHyprland)
            return [
                {
                    name: Tr.tr("Keybind search needs Hyprland"),
                    desc: Tr.tr("Niri does not expose its binds"),
                    icon: "keyboard_off",
                    onClicked: () => {}
                }
            ];
        return keybinds.filter(b => !query || matches(`${b.combo} ${b.description}`, query)).map(b => ({
                    name: b.description,
                    desc: b.combo,
                    icon: "keyboard",
                    verb: Tr.tr("Copy"),
                    onClicked: copy(b.combo)
                }));
    }

    function deleteClipboard(entry: string): void {
        clipboardEntries = clipboardEntries.filter(e => e !== entry);
        // Entry passed as an argument, never spliced into the script
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "sh", entry]);
    }

    function reloadClipboard(): void {
        cliphist.running = true;
    }

    function reloadKeybinds(): void {
        if (Compositor.isHyprland)
            binds.running = true;
    }

    FileView {
        id: emojiFile

        path: `${Quickshell.shellDir}/assets/data/emoji.txt`
    }

    FileView {
        id: symbolFile

        path: `${Quickshell.shellDir}/assets/data/symbols.txt`
    }

    Process {
        id: cliphist

        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.clipboardEntries = text.split("\n").filter(l => l.trim())
        }
    }

    Process {
        id: binds

        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const mods = [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]];
                try {
                    root.keybinds = JSON.parse(text).filter(b => b.has_description).map(b => ({
                                description: b.description,
                                combo: [...mods.filter(([bit]) => b.modmask & bit).map(([, n]) => n), b.key].join(" + ")
                            }));
                } catch (e) {
                    root.keybinds = [];
                }
            }
        }
    }
}
