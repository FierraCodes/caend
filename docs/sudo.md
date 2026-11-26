# sudo in the polkit dialog

caend asks for sudo's password in the same dialog as polkit (the shape-masked password card),
instead of in the terminal. It uses sudo's own askpass support, so real sudo still checks the
password: sudoers rules, the 5-minute timestamp, `pam_faillock` and `/etc/pam.d/sudo` all work as before.

## How it works

1. The session puts caend's `sudo` (`assets/bin/sudo`) first on `PATH`. It runs the real sudo with
   `-A`, so every sudo uses the helper: typed in any shell, or run by a script like `cachy-update`,
   `paru` or `makepkg`. It leaves `-S` (password on stdin) and `-n` (never ask) alone.
2. `caend-askpass` (installed to `/usr/bin`) is the `SUDO_ASKPASS` helper.
3. When sudo needs a password it runs the helper, which asks the running shell over IPC
   (`qs -c caelestia ipc call sudo ask ...`) to open the dialog, showing the command sudo was given.
4. The password comes back through a private FIFO in `$XDG_RUNTIME_DIR/caend-askpass/`
   (never on a command line) and the helper prints it for sudo. Cancel or Escape makes sudo fail.
5. A wrong password shows the dialog again with "Wrong password, try again", as sudo retries.

If the shell isn't running (a TTY, SSH), the helper asks in the terminal instead.

### Face unlock

sudo runs its own PAM stack, so face unlock only happens if Howdy is in `/etc/pam.d/sudo`. caend
never edits `/etc/pam.d`; to add it yourself (same `sufficient` line as for polkit, so misses fall
through to the password and don't count towards `pam_faillock`):

```sh
sudo cp /etc/pam.d/sudo /etc/pam.d/sudo.bak
sudo sed -i '0,/^auth/s//auth       sufficient   pam_howdy.so\nauth/' /etc/pam.d/sudo
```

Howdy runs inside sudo before the password prompt, so caend's sudo starts `caend-askpass --face`
next to the real sudo. It shows the same Face ID scan as the polkit dialog while sudo waits (skipped when
sudo's timestamp is still fresh), the success tick when the command starts, and the password field
once Howdy gives up.

## Setup

On a fresh install this needs nothing:

- **Hyprland**: `hypr/hyprland/env.lua` sets `SUDO_ASKPASS` when it finds `caend-askpass` on `PATH`.
  Set `sudoAskpass` in `~/.config/caelestia/hypr-vars.lua` to a path to use another helper, or to
  `false` to keep sudo in the terminal.
  When it's set, it also puts caend's `sudo` first on `PATH` (from `~/.config/quickshell/caelestia/assets/bin`
  or `/usr/share/caend/bin`), for every shell and script started in the session.
- Apps started without a terminal (scripts from the launcher, keybinds) use the helper on their own:
  sudo picks askpass by itself when there's no terminal and `SUDO_ASKPASS` is set.

**Niri**: Niri can't add to `PATH`, so set the helper in `~/.config/niri/config.kdl` and put caend's
`sudo` first on `PATH` in your shell config:

```kdl
environment {
    SUDO_ASKPASS "/usr/bin/caend-askpass"
}
```

```sh
# fish (~/.config/fish/config.fish)
fish_add_path -gpm /usr/share/caend/bin
# bash / zsh (~/.bashrc, ~/.zshrc)
export PATH="/usr/share/caend/bin:$PATH"
```

Only programs that run `/usr/bin/sudo` by its full path skip caend's `sudo`; with a terminal they
ask there, without one sudo uses the helper by itself.

## Safety

Any program running as you can already draw a fake password window, so the helper adds no new
access, but do read the command in the dialog before you type. The shell only writes answers to
FIFOs under `$XDG_RUNTIME_DIR/caend-askpass/`, and the password goes to the helper on stdin.
