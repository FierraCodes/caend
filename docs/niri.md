# Running caend on Niri

caend detects Niri on its own (`NIRI_SOCKET` / `XDG_CURRENT_DESKTOP`). Niri has no
global-shortcut protocol for clients, so keybinds call the shell over IPC instead.
Add this to `~/.config/niri/config.kdl`:

```kdl
spawn-at-startup "qs" "-c" "caelestia"

binds {
    Mod+Space    { spawn "qs" "-c" "caelestia" "ipc" "call" "drawers" "toggle" "launcher"; }
    Mod+D        { spawn "qs" "-c" "caelestia" "ipc" "call" "drawers" "toggle" "dashboard"; }
    Mod+N        { spawn "qs" "-c" "caelestia" "ipc" "call" "drawers" "toggle" "sidebar"; }
    Mod+Escape   { spawn "qs" "-c" "caelestia" "ipc" "call" "drawers" "toggle" "session"; }
    Mod+L        { spawn "qs" "-c" "caelestia" "ipc" "call" "lock" "lock"; }
    Mod+Shift+S  { spawn "qs" "-c" "caelestia" "ipc" "call" "picker" "openFreeze"; }
}

// The shell draws its drawers on this layer namespace
layer-rule {
    match namespace="^caelestia-drawers$"
}
```

`qs -c caelestia ipc show` lists every IPC target and function.

## What works on Niri today

- Bar active-window title, caps/num lock indicators, keyboard layout, workspace scroll on the bar
- Lock screen state messages, notifications, idle DPMS (`power-off-monitors`)

## Not yet (Hyprland-only for now)

- Workspaces widget and window icons, special workspaces, window-info panel,
  area-picker window snapping, game mode, runtime blur/transparency layer rules
