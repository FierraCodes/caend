# sudo in the polkit dialog

caend asks for sudo's password in the same dialog as polkit (the shape-masked password card),
instead of in the terminal. It uses sudo's own askpass support, so real sudo still checks the
password: sudoers rules, the 5-minute timestamp, `pam_faillock` and `/etc/pam.d/sudo` all work as before.

## How it works

1. `caend-askpass` (installed to `/usr/bin`) is the `SUDO_ASKPASS` helper.
2. When sudo needs a password it runs the helper, which asks the running shell over IPC
   (`qs -c caelestia ipc call sudo ask ...`) to open the dialog, showing the command sudo was given.
3. The password comes back through a private FIFO in `$XDG_RUNTIME_DIR/caend-askpass/`
   (never on a command line) and the helper prints it for sudo. Cancel or Escape makes sudo fail.
4. A wrong password shows the dialog again with "Wrong password, try again", as sudo retries.

If the shell isn't running (a TTY, SSH), the helper asks in the terminal instead.

Face unlock doesn't apply here: sudo checks the password itself, so the dialog only asks for a
password. If you add Howdy to `/etc/pam.d/sudo` yourself, sudo tries your face first and only opens
the dialog when that fails. caend never edits `/etc/pam.d`.

## Setup

On a fresh install this needs nothing:

- **Hyprland**: `hypr/hyprland/env.lua` sets `SUDO_ASKPASS` when it finds `caend-askpass` on `PATH`.
  Set `sudoAskpass` in `~/.config/caelestia/hypr-vars.lua` to a path to use another helper, or to
  `false` to keep sudo in the terminal.
- **fish**: `/usr/share/fish/vendor_conf.d/caend-sudo.fish` makes interactive `sudo` run `sudo -A`
  while `SUDO_ASKPASS` and `WAYLAND_DISPLAY` are set. A `sudo` function in your own config wins.
- Apps started without a terminal (scripts from the launcher, keybinds) use the helper on their own:
  sudo picks askpass by itself when there's no terminal and `SUDO_ASKPASS` is set.

**Niri**: add the variable to `~/.config/niri/config.kdl`:

```kdl
environment {
    SUDO_ASKPASS "/usr/bin/caend-askpass"
}
```

**bash / zsh**: add to `~/.bashrc` or `~/.zshrc`:

```sh
[ -n "$SUDO_ASKPASS" ] && [ -n "$WAYLAND_DISPLAY" ] && alias sudo='sudo -A'
```

Tools that call `/usr/bin/sudo` from their own process (e.g. `paru`, `makepkg`) still ask in the
terminal unless they pass `-A` (for paru, try `SudoFlags = -A` in `~/.config/paru/paru.conf`).

## Safety

Any program running as you can already draw a fake password window, so the helper adds no new
access, but do read the command in the dialog before you type. The shell only writes answers to
FIFOs under `$XDG_RUNTIME_DIR/caend-askpass/`, and the password goes to the helper on stdin.
