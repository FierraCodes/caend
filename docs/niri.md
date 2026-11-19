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
    Mod+A        { spawn "qs" "-c" "caelestia" "ipc" "call" "drawers" "toggle" "aichat"; }
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

- Bar workspaces (per output, sorted by index) with window icons; click to focus, scroll to switch
- Active-window title and preview popout, keyboard layout popout and switching
- Caps/num lock indicators and OSD, notifications, lock screen, idle DPMS (`power-off-monitors`)
- The AI drawer reserves its width while open, so windows make room for it

## Not yet (Hyprland-only for now)

- Special workspaces, window-info panel, area-picker window snapping, keybind search
- Game mode, anti-flashbang shader, runtime blur/transparency layer rules
  (add blur for `caelestia-drawers` in your own `layer-rule` if your Niri version supports it)
- Clicking outside an open drawer does not close it (Niri has no focus-grab protocol); use the bind again or Escape
