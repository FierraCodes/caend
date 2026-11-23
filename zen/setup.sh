#!/usr/bin/env bash
# Theme Zen Browser with the caelestia colour scheme. Safe to re-run.
# The caelestia CLI regenerates the colours on every scheme/wallpaper change; Zen applies them on restart.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/theme"
marker='@import "caend-zen.css";'

# 1. Register the CLI template (symlink so `git pull` updates it).
mkdir -p "$config/caelestia/templates"
ln -sfn "$here/caend-zen.css" "$config/caelestia/templates/caend-zen.css"

# 2. Generate it once from the current scheme (any `scheme set` re-applies all templates).
if command -v caelestia >/dev/null; then
    caelestia scheme set -m "$(caelestia scheme get -m)" || echo "warning: 'caelestia scheme set' failed; change scheme once to generate colours" >&2
else
    echo "warning: caelestia CLI not found; colours appear after it is installed and a scheme is set" >&2
fi

# 3. Hook every Zen profile (native, XDG and Flatpak layouts).
found=0
for root in "$HOME/.zen" "$config/zen" "$HOME/.var/app/app.zen_browser.zen/.zen"; do
    for profile in "$root"/*/; do
        [[ -f "$profile/prefs.js" || -f "$profile/times.json" ]] || continue
        found=1
        mkdir -p "$profile/chrome"
        ln -sfn "$state/caend-zen.css" "$profile/chrome/caend-zen.css"

        css="$profile/chrome/userChrome.css"
        if ! grep -qxF "$marker" "$css" 2>/dev/null; then
            # @import must come before any other rule, so prepend.
            { echo "$marker"; cat "$css" 2>/dev/null || true; } > "$css.tmp" && mv "$css.tmp" "$css"
        fi

        pref='user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
        grep -qxF "$pref" "$profile/user.js" 2>/dev/null || echo "$pref" >> "$profile/user.js"
        echo "Themed Zen profile: $profile"
    done
done

if ((found)); then
    echo "Done. Restart Zen to apply (and after each scheme change)."
else
    echo "No Zen profile found. Start Zen once, close it, then re-run this script." >&2
    exit 1
fi
