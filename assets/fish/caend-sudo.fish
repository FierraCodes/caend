# caend: interactive sudo asks for its password in the shell's polkit dialog (docs/sudo.md)
# SUDO_ASKPASS comes from the Hyprland/Niri session; over SSH or on a TTY sudo stays in the terminal
if status is-interactive; and test -n "$SUDO_ASKPASS"; and set -q WAYLAND_DISPLAY
    function sudo --wraps sudo --description 'sudo, with the password asked in the caend dialog'
        # Howdy in sudo's PAM stack runs before the dialog exists, so show its scan from outside
        if string match -qr '^\s*auth\s.*pam_(howdy|visage)\.so' </etc/pam.d/sudo 2>/dev/null
            $SUDO_ASKPASS --face $fish_pid &
            disown
        end
        command sudo -A $argv
    end
end
