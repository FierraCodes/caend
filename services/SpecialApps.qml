pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Caelestia.Config
import qs.services

// Named special workspaces from `general.specialWorkspaces`. Toggling one launches its app when
// no matching window exists and moves the new window in once Hyprland reports it.
Singleton {
    id: root

    readonly property list<var> rules: GlobalConfig.general.specialWorkspaces.filter(r => r.enabled ?? true)
    property var pending: ({}) // name -> launch time (ms), cleared when the window shows up

    function ruleFor(name: string): var {
        return rules.find(r => r?.name === name) ?? null;
    }

    function matches(rule: var, cls: string): bool {
        try {
            return !!rule.class && new RegExp(rule.class).test(cls);
        } catch (e) {
            console.warn(`[SpecialApps] Bad class regex for "${rule.name}":`, e);
            return false;
        }
    }

    function moveToSpecial(address: string, name: string): void {
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = "address:0x${address}", workspace = "special:${name}", follow = false })` : `movetoworkspacesilent special:${name},address:0x${address}`);
    }

    function toggle(name: string): void {
        if (!Compositor.capabilities.specialWorkspaces)
            return;
        const rule = ruleFor(name);
        if (rule) {
            const existing = Hypr.toplevels.values.filter(t => matches(rule, t.lastIpcObject.class ?? ""));
            for (const t of existing)
                if (t.workspace?.name !== `special:${name}`)
                    moveToSpecial(t.address, name);
            if (existing.length === 0 && rule.command?.length) {
                pending = Object.assign({}, pending, {
                    [name]: Date.now()
                });
                Quickshell.execDetached(typeof rule.command === "string" ? ["sh", "-c", rule.command] : rule.command);
            }
        }
        Compositor.toggleSpecial(name);
    }

    Connections {
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name !== "openwindow")
                return;
            const [address, , cls] = event.data.split(",");
            for (const name in root.pending) {
                const rule = root.ruleFor(name);
                // Apps that never open a window must not capture a later one forever
                if (!rule || Date.now() - root.pending[name] > 60000 || root.matches(rule, cls)) {
                    if (rule && root.matches(rule, cls))
                        root.moveToSpecial(address, name);
                    const next = Object.assign({}, root.pending);
                    delete next[name];
                    root.pending = next;
                }
            }
        }

        target: Compositor.isHyprland ? Hyprland : null
    }

    IpcHandler {
        function toggle(name: string): void {
            root.toggle(name);
        }

        function list(): string {
            return root.rules.map(r => r.name).join("\n");
        }

        target: "special"
    }
}
