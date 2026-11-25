pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Compositor binds, normalised for the keybind cheatsheet.
// Hyprland: `j/binds` from HyprExtras, refreshed by C++ on configreloaded (so user binds count too).
// Niri: the `binds {}` block of config.kdl, re-read when the file changes.
// Each entry: { mods: bitmask (see Mod), key: lower-case keysym name, label, icon }
Singleton {
    id: root

    // Hyprland modmask bits; Niri binds are mapped onto the same ones
    readonly property QtObject mod: QtObject {
        readonly property int shift: 1
        readonly property int ctrl: 4
        readonly property int alt: 8
        readonly property int superKey: 64
    }

    readonly property var binds: Compositor.isHyprland ? fromHypr(Hypr.extras.binds) : Compositor.isNiri ? fromNiri(niriConfig.text()) : []

    // Cheatsheet state lives here so the launcher shortcut can see it (see daemons/Shortcuts.qml)
    property bool open
    // Hyprland eats a lone SUPER press for the launcher bind, so the launcher shortcut reports it instead
    property bool superHeld

    onOpenChanged: if (!open)
        superHeld = false

    function fromHypr(raw: var): var {
        return (raw ?? []).filter(b => !b.non_consuming && !b.catch_all && !b.submap && b.key).map(b => {
            const label = b.description || `${b.dispatcher} ${b.arg}`.trim();
            return {
                mods: b.modmask & (mod.shift | mod.ctrl | mod.alt | mod.superKey),
                key: b.key.toLowerCase(),
                label,
                icon: iconFor(label)
            };
        });
    }

    // shortcut: ignores `include` files and binds split over several lines; enough for the stock niri config
    function fromNiri(text: string): var {
        const block = text.match(/^\s*binds\s*\{([\s\S]*?)^\}/m);
        if (!block)
            return [];
        const mods = {
            mod: mod.superKey,
            super: mod.superKey,
            win: mod.superKey,
            ctrl: mod.ctrl,
            control: mod.ctrl,
            shift: mod.shift,
            alt: mod.alt
        };
        const out = [];
        for (const line of block[1].split("\n")) {
            const m = line.match(/^\s*([A-Za-z0-9_+]+)\s*([^{]*)\{\s*(.*?)\s*\}?\s*$/);
            if (!m || m[1].startsWith("//"))
                continue;
            const parts = m[1].split("+");
            const key = parts.pop().toLowerCase();
            let mask = 0;
            for (const p of parts)
                mask |= mods[p.toLowerCase()] ?? 0;
            const title = m[2].match(/hotkey-overlay-title="([^"]*)"/)?.[1];
            const label = title || m[3].replace(/;$/, "").replace(/"/g, "");
            out.push({
                mods: mask,
                key,
                label,
                icon: iconFor(label)
            });
        }
        return out;
    }

    // First match wins, so put specific words before general ones
    readonly property var iconRules: [[/cheatsheet|hotkey/i, "keyboard"], [/launcher/i, "apps"], [/session|power off|quit/i, "power_settings_new"], [/sidebar/i, "view_sidebar"], [/notif/i, "notifications_off"], [/panels|dashboard/i, "dashboard"], [/restart|reload/i, "restart_alt"], [/kill/i, "dangerous"], [/lock group/i, "lock"], [/lock/i, "lock"], [/settings|nexus/i, "settings"], [/move window.*workspace|move-window-to|move-column-to/i, "move_item"], [/workspace|focus-workspace/i, "workspaces"], [/cycle|group/i, "tab"], [/focus left|focus-column-left/i, "arrow_back"], [/focus right|focus-column-right/i, "arrow_forward"], [/focus up|focus-window-up/i, "arrow_upward"], [/focus down|focus-window-down/i, "arrow_downward"], [/move window|move-/i, "open_with"], [/width|height|resize|size/i, "aspect_ratio"], [/drag/i, "drag_pan"], [/center/i, "filter_center_focus"], [/picture/i, "picture_in_picture"], [/pin/i, "push_pin"], [/fullscreen|maximi/i, "fullscreen"], [/float/i, "flip_to_front"], [/close/i, "close"], [/special/i, "star"], [/system monitor|sysmon/i, "monitor_heart"], [/music/i, "music_note"], [/communication/i, "forum"], [/todo/i, "checklist"], [/terminal|alacritty|foot|kitty/i, "terminal"], [/browser|firefox|zen/i, "language"], [/editor|code/i, "code"], [/file/i, "folder"], [/audio settings|pavucontrol/i, "tune"], [/screenshot|screen-shot/i, "screenshot_region"], [/record/i, "videocam"], [/colou?r/i, "colorize"], [/brightness up/i, "brightness_high"], [/brightness/i, "brightness_low"], [/play|pause/i, "play_pause"], [/next track/i, "skip_next"], [/previous track/i, "skip_previous"], [/stop/i, "stop"], [/microphone/i, "mic_off"], [/mute/i, "volume_off"], [/volume up/i, "volume_up"], [/volume/i, "volume_down"], [/sleep|suspend/i, "bedtime"], [/clipboard/i, "content_paste"], [/emoji/i, "mood"], [/notification/i, "notifications"]]

    function iconFor(label: string): string {
        for (const [re, icon] of iconRules)
            if (re.test(label))
                return icon;
        return "bolt";
    }

    FileView {
        id: niriConfig

        path: Compositor.isNiri ? `${Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`}/niri/config.kdl` : ""
        watchChanges: true
        onFileChanged: reload()
    }

    IpcHandler {
        function toggle(): void {
            root.open = !root.open;
        }

        target: "cheatsheet"
    }
}
