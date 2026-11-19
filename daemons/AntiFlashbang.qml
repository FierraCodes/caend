import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.services

// Dims bright screens (e.g. a white page in dark mode) with a Hyprland screen shader. The shader samples
// the frame on the GPU, so there are no screenshots or polling. Mode lives in utilities.antiFlashbang.
Scope {
    id: root

    readonly property string mode: GlobalConfig.utilities.antiFlashbang
    readonly property list<string> modes: ["off", "weak", "strong"]

    function apply(): void {
        if (!Compositor.capabilities.runtimeOptions)
            return;
        if (mode === "weak" || mode === "strong")
            Hypr.extras.applyOptions({
                "decoration:screen_shader": Quickshell.shellPath(`assets/shaders/anti-flashbang${mode === "weak" ? "-weak" : ""}.glsl`),
                "debug:damage_tracking": 1 // Full damage tracking leaves stale dimmed regions
            });
        else
            Hypr.extras.message("reload"); // Restores the user's own shader settings
    }

    onModeChanged: {
        apply();
        Toaster.toast(Tr.tr("Anti-flashbang: %1").arg(mode), mode === "off" ? Tr.tr("Screen dimming disabled") : Tr.tr("Bright screens are dimmed"), "brightness_6");
    }
    Component.onCompleted: if (mode !== "off")
        apply()

    Connections {
        function onConfigReloaded(): void {
            if (root.mode !== "off")
                root.apply();
        }

        target: Compositor.isHyprland ? Hypr : null
    }

    IpcHandler {
        function get(): string {
            return root.mode;
        }

        function set(mode: string): void {
            if (root.modes.includes(mode))
                GlobalConfig.utilities.antiFlashbang = mode;
        }

        function cycle(): void {
            GlobalConfig.utilities.antiFlashbang = root.modes[(root.modes.indexOf(root.mode) + 1) % root.modes.length];
        }

        target: "antiFlashbang"
    }
}
