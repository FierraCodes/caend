local vars = require("variables")

-- Themes
hl.env("QT_QPA_PLATFORMTHEME", "qtengine")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("XCURSOR_THEME", vars.cursorTheme)
hl.env("XCURSOR_SIZE", vars.cursorSize)

-- Toolkit backends
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland,x11,windows")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- XDG specifications
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Others
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")
-- Run the shell from a local caend build instead of the installed plugin
if vars.devBuildDir then
    hl.env("QML2_IMPORT_PATH", vars.devBuildDir .. "/qml")
    hl.env("CAELESTIA_LIB_DIR", vars.devBuildDir .. "/lib")
end

-- sudo asks for its password in the shell's polkit dialog (docs/sudo.md)
local askpass = vars.sudoAskpass
if askpass == nil then
    for dir in (os.getenv("PATH") or ""):gmatch("[^:]+") do
        local f = io.open(dir .. "/caend-askpass", "r")
        if f then
            f:close()
            askpass = dir .. "/caend-askpass"
            break
        end
    end
    -- A dev checkout symlinked to ~/.config/hypr isn't installed, so use the helper next to it
    local checkout = os.getenv("HOME") .. "/.config/hypr/../assets/caend-askpass"
    local f = not askpass and io.open(checkout, "r")
    if f then
        f:close()
        askpass = checkout
    end
end
-- Empty when turned off, so an inherited value doesn't keep caend's sudo on
hl.env("SUDO_ASKPASS", askpass or "")

-- caend's sudo goes first on PATH, so sudo run by scripts (e.g. cachy-update) uses the dialog too
if askpass then
    local home = os.getenv("HOME")
    local dirs = { home .. "/.config/quickshell/caelestia/assets/bin", home .. "/.config/hypr/../assets/bin" }
    for dir in (os.getenv("XDG_CONFIG_DIRS") or "/etc/xdg"):gmatch("[^:]+") do
        table.insert(dirs, dir .. "/quickshell/caelestia/assets/bin")
    end
    local path = os.getenv("PATH") or ""
    for _, dir in ipairs(dirs) do
        local f = io.open(dir .. "/sudo", "r")
        if f then
            f:close()
            -- A config reload runs this again with the PATH it set
            if not (":" .. path .. ":"):find(":" .. dir .. ":", 1, true) then
                hl.env("PATH", dir .. ":" .. path)
            end
            break
        end
    end
end
