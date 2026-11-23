pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n

// Compositor-neutral front for the shell. Hyprland state comes from `Hypr`;
// Niri state is kept up to date from one long-lived `niri msg -j event-stream`
// (no polling, no process per update). Only touch `Hypr` behind `isHyprland`
// so it is never instantiated on other compositors.
Singleton {
    id: root

    readonly property string name: {
        const env = `${Quickshell.env("XDG_CURRENT_DESKTOP") ?? ""} ${Quickshell.env("XDG_SESSION_DESKTOP") ?? ""}`.toLowerCase();
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || env.includes("hyprland"))
            return "hyprland";
        if (Quickshell.env("NIRI_SOCKET") || env.includes("niri"))
            return "niri";
        return "unknown";
    }
    readonly property bool isHyprland: name === "hyprland"
    readonly property bool isNiri: name === "niri"

    // What the UI may offer. Hide features rather than branching on `name`.
    readonly property Capabilities capabilities: Capabilities {}

    // ---- Windows / workspaces ----

    readonly property string activeWindowTitle: isHyprland ? (Hypr.activeToplevel?.title ?? "") : (niri.focusedWindow?.title ?? "")
    readonly property string activeWindowAppId: isHyprland ? (Hypr.activeToplevel?.lastIpcObject.class ?? "") : (niri.focusedWindow?.app_id ?? "")
    readonly property bool hasActiveWindow: isHyprland ? !!Hypr.activeToplevel : !!niri.focusedWindow
    readonly property var niriWorkspaces: niri.workspaces
    readonly property var niriWindows: niri.windows
    readonly property list<string> niriKbNames: niri.kbNames
    readonly property int niriKbIdx: niri.kbIdx
    readonly property int activeWsId: isHyprland ? Hypr.activeWsId : (niri.focusedWorkspace?.id ?? 1)
    readonly property string focusedOutput: isHyprland ? (Hypr.focusedMonitor?.name ?? "") : (niri.focusedWorkspace?.output ?? "")

    // True if the focused output's visible workspace has a fullscreen window
    readonly property bool focusedHasFullscreen: {
        if (!isHyprland)
            return false; // shortcut: niri IPC has no fullscreen flag yet, add when it does
        const monitor = Hypr.focusedMonitor;
        const specialName = monitor?.lastIpcObject.specialWorkspace?.name;
        const ws = specialName ? Hypr.workspaces.values.find(w => w.name === specialName) : monitor?.activeWorkspace;
        return ws?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
    }

    // ---- Keyboard ----

    readonly property bool capsLock: isHyprland ? Hypr.capsLock : leds.caps
    readonly property bool numLock: isHyprland ? Hypr.numLock : leds.num
    readonly property string kbLayoutFull: isHyprland ? Hypr.kbLayoutFull : (niri.kbNames[niri.kbIdx] ?? Tr.trCtx("Unknown", "keyboard layout"))
    readonly property string kbLayout: kbMap.get(kbLayoutFull) ?? "??"
    readonly property string defaultKbLayout: isHyprland ? Hypr.defaultKbLayout : (kbMap.get(niri.kbNames[0] ?? "") ?? "??")
    // Full xkb layout description -> short code, e.g. "English (US)" -> "us"
    readonly property var kbMap: new Map()

    function anyFullscreen(): bool {
        if (!isHyprland)
            return false;
        return Hypr.monitors.values.some(m => m?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1));
    }

    function isFocusedScreen(screen: ShellScreen): bool {
        if (!screen)
            return false;
        if (isHyprland)
            return Hypr.monitorFor(screen)?.focused ?? false;
        return screen.name === focusedOutput;
    }

    function focusWorkspace(ws: var): void {
        if (isHyprland)
            Hypr.focusWorkspace(ws);
        else if (isNiri)
            niriAction(["focus-workspace", String(ws)]);
    }

    // Niri workspace indices are per output, so focus that output first
    function focusNiriWorkspace(output: string, idx: int): void {
        Quickshell.execDetached(["sh", "-c", 'niri msg action focus-monitor "$1" && niri msg action focus-workspace "$2"', "sh", output, String(idx)]);
    }

    // delta < 0: previous workspace, > 0: next workspace
    function focusWorkspaceRelative(delta: int): void {
        if (isHyprland) {
            const r = `r${delta < 0 ? "-" : "+"}1`;
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "${r}" })` : `workspace ${r}`);
        } else if (isNiri) {
            niriAction([delta < 0 ? "focus-workspace-up" : "focus-workspace-down"]);
        }
    }

    function toggleSpecial(name: string): void {
        if (capabilities.specialWorkspaces)
            Hypr.toggleSpecial(name);
    }

    function setDpms(on: bool): void {
        if (isHyprland)
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.dpms({ action = "${on ? "enable" : "disable"}" })` : `dpms ${on ? "on" : "off"}`);
        else if (isNiri)
            niriAction([on ? "power-on-monitors" : "power-off-monitors"]);
    }

    function niriAction(args: list<string>): void {
        Quickshell.execDetached(["niri", "msg", "action", ...args]);
    }

    FileView {
        path: Quickshell.env("CAELESTIA_XKB_RULES_PATH") || "/usr/share/X11/xkb/rules/base.lst"
        onLoaded: {
            const layoutMatch = text().match(/! layout\n([\s\S]*?)\n\n/);
            if (layoutMatch) {
                for (const line of layoutMatch[1].split("\n")) {
                    if (!line.trim() || line.trim().startsWith("!"))
                        continue;
                    const match = line.match(/^\s*([a-z]{2,})\s+([a-zA-Z() ]+)$/);
                    if (match)
                        root.kbMap.set(match[2], match[1]);
                }
            }

            const variantMatch = text().match(/! variant\n([\s\S]*?)\n\n/);
            if (variantMatch) {
                for (const line of variantMatch[1].split("\n")) {
                    if (!line.trim() || line.trim().startsWith("!"))
                        continue;
                    const match = line.match(/^\s*([a-zA-Z0-9_-]+)\s+([a-z]{2,}): (.+)$/);
                    if (match)
                        root.kbMap.set(match[3], match[2]);
                }
            }
            root.kbMapChanged();
        }
    }

    // ---- Niri backend ----

    QtObject {
        id: niri

        property var workspaces: []
        property var windows: []
        property var focusedWindowId: null
        property list<string> kbNames: []
        property int kbIdx: 0

        readonly property var focusedWorkspace: workspaces.find(w => w.is_focused) ?? null
        readonly property var focusedWindow: windows.find(w => w.id === focusedWindowId) ?? null

        function handle(ev: var): void {
            if (ev.WorkspacesChanged) {
                workspaces = ev.WorkspacesChanged.workspaces;
            } else if (ev.WorkspaceActivated) {
                const {
                    id,
                    focused
                } = ev.WorkspaceActivated;
                const output = workspaces.find(w => w.id === id)?.output;
                workspaces = workspaces.map(w => Object.assign({}, w, {
                        is_active: w.output === output ? w.id === id : w.is_active,
                        is_focused: focused ? w.id === id : w.is_focused
                    }));
            } else if (ev.WindowsChanged) {
                windows = ev.WindowsChanged.windows;
                focusedWindowId = windows.find(w => w.is_focused)?.id ?? null;
            } else if (ev.WindowOpenedOrChanged) {
                const win = ev.WindowOpenedOrChanged.window;
                windows = [...windows.filter(w => w.id !== win.id), win];
                if (win.is_focused)
                    focusedWindowId = win.id;
            } else if (ev.WindowClosed) {
                windows = windows.filter(w => w.id !== ev.WindowClosed.id);
                if (focusedWindowId === ev.WindowClosed.id)
                    focusedWindowId = null;
            } else if (ev.WindowFocusChanged) {
                focusedWindowId = ev.WindowFocusChanged.id;
            } else if (ev.KeyboardLayoutsChanged) {
                kbNames = ev.KeyboardLayoutsChanged.keyboard_layouts.names;
                kbIdx = ev.KeyboardLayoutsChanged.keyboard_layouts.current_idx;
            } else if (ev.KeyboardLayoutSwitched) {
                kbIdx = ev.KeyboardLayoutSwitched.idx;
            }
        }
    }

    Process {
        id: niriEvents

        running: root.isNiri
        command: ["niri", "msg", "-j", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    niri.handle(JSON.parse(line));
                } catch (e) {
                    console.warn("[Compositor] bad niri event:", e);
                }
            }
        }
        onExited: if (root.isNiri)
            niriRestart.start()
    }

    Timer {
        id: niriRestart

        interval: 1000
        onTriggered: niriEvents.running = true
    }

    // Caps/Num lock on non-Hyprland: read keyboard LEDs. Hyprland gets these (and their toasts) from HyprExtras.
    QtObject {
        id: leds

        property string capsPath
        property string numPath
        readonly property bool caps: capsFile.text().trim() === "1"
        readonly property bool num: numFile.text().trim() === "1"

        // Same toasts the Hyprland backend sends from C++
        onCapsChanged: if (GlobalConfig.utilities.toasts.capsLockChanged)
            Toaster.toast(caps ? Tr.tr("Caps lock enabled") : Tr.tr("Caps lock disabled"), caps ? Tr.tr("Caps lock is currently enabled") : Tr.tr("Caps lock is currently disabled"), caps ? "keyboard_capslock_badge" : "keyboard_capslock")
        onNumChanged: if (GlobalConfig.utilities.toasts.numLockChanged)
            Toaster.toast(num ? Tr.tr("Num lock enabled") : Tr.tr("Num lock disabled"), num ? Tr.tr("Num lock is currently enabled") : Tr.tr("Num lock is currently disabled"), num ? "looks_one" : "timer_1")
    }

    Process {
        running: !root.isHyprland
        command: ["sh", "-c", "ls -d /sys/class/leds/*::capslock | head -1; ls -d /sys/class/leds/*::numlock | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [caps, num] = text.trim().split("\n");
                leds.capsPath = caps ? `${caps}/brightness` : "";
                leds.numPath = num ? `${num}/brightness` : "";
            }
        }
    }

    FileView {
        id: capsFile

        path: leds.capsPath
        blockLoading: true
    }

    FileView {
        id: numFile

        path: leds.numPath
        blockLoading: true
    }

    // shortcut: sysfs LEDs send no change events, so re-read the two files (no process spawn); replace if niri ever exposes lock state over IPC
    Timer {
        running: !root.isHyprland && (leds.capsPath || leds.numPath)
        repeat: true
        interval: 300
        onTriggered: {
            capsFile.reload();
            numFile.reload();
        }
    }

    component Capabilities: QtObject {
        readonly property bool specialWorkspaces: root.isHyprland
        readonly property bool layerRules: root.isHyprland
        readonly property bool runtimeOptions: root.isHyprland
        readonly property bool windowActions: root.isHyprland
    }
}
