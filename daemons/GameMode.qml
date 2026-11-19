import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import Caelestia.State
import qs.services

Scope {
    id: root

    function applyGameMode(): void {
        if (!Compositor.capabilities.runtimeOptions)
            return;
        Hypr.extras.applyOptions(GlobalConfig.utilities.gameMode.options);
    }

    function syncState(enableDisable: bool): void {
        if (RuntimeState.gameMode) {
            root.applyGameMode();
            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(Tr.tr("Game mode enabled"), Tr.tr("Disabled Hyprland animations, blur, gaps and shadows"), "gamepad");
        } else if (enableDisable && Compositor.capabilities.runtimeOptions) {
            Hypr.extras.message("reload");
            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(Tr.tr("Game mode disabled"), Tr.tr("Hyprland settings restored"), "gamepad");
        }
    }

    Component.onCompleted: syncState(false)

    Connections {
        function onGameModeChanged(): void {
            root.syncState(true);
        }

        target: RuntimeState
    }

    Connections {
        function onConfigReloaded(): void {
            if (RuntimeState.gameMode)
                root.applyGameMode();
        }

        target: Compositor.isHyprland ? Hypr : null
    }

    IpcHandler {
        function isEnabled(): bool {
            return RuntimeState.gameMode;
        }

        function toggle(): void {
            RuntimeState.gameMode = !RuntimeState.gameMode;
        }

        function enable(): void {
            RuntimeState.gameMode = true;
        }

        function disable(): void {
            RuntimeState.gameMode = false;
        }

        target: "gameMode"
    }
}
