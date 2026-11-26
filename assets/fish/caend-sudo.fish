# caend: interactive sudo asks for its password in the shell's polkit dialog (docs/sudo.md)
# SUDO_ASKPASS comes from the Hyprland/Niri session; over SSH or on a TTY sudo stays in the terminal
if status is-interactive; and test -n "$SUDO_ASKPASS"; and set -q WAYLAND_DISPLAY
    function sudo --wraps sudo --description 'sudo, with the password asked in the caend dialog'
        command sudo -A $argv
    end
end
