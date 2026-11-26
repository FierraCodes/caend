# caend: interactive sudo asks for its password in the shell's polkit dialog (docs/sudo.md)
# SUDO_ASKPASS comes from the Hyprland/Niri session; over SSH or on a TTY sudo stays in the terminal
if status is-interactive; and test -n "$SUDO_ASKPASS"; and set -q WAYLAND_DISPLAY
    function sudo --wraps sudo --description 'sudo, with the password asked in the caend dialog'
        # Howdy in sudo's PAM stack runs before the dialog exists, so show its scan from outside
        set -l face_result
        set -l watcher
        if string match -qr '^\s*auth\s.*pam_(howdy|visage)\.so' </etc/pam.d/sudo 2>/dev/null
            $SUDO_ASKPASS --face $fish_pid &
            set watcher $last_pid
            set face_result $XDG_RUNTIME_DIR/caend-askpass-face-$watcher
            disown
        end
        command sudo -A $argv
        set -l st $status
        # Tells the watcher how a quick sudo ended, so it can show the success tick
        # Only while it still waits, or the file would be left behind (e.g. a cached sudo it already saw)
        test -n "$watcher"; and kill -0 $watcher 2>/dev/null; and echo $st >$face_result
        return $st
    end
end
