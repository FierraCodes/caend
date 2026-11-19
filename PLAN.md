# caend merge plan

caend = **Caelestia shell** (FierraCodes/caelestia-shell, fork of caelestia-dots/shell) merged with
**end4-pC** (FierraCodes/end4-pC, pctrade's fork of end-4's illogical-impulse), running on **Hyprland and Niri**.

This is a read-only analysis of both repos at their current `main` (caelestia `e72df8e`, end4-pC `7b282b8`).

---

## 1. The two codebases at a glance

| | caelestia-shell | end4-pC |
|---|---|---|
| Toolkit | Quickshell + **C++ QML plugin** (`plugin/src/Caelestia/*`, built with CMake, Qt6 ShaderTools/Multimedia/Sql/DBus/Network) | Pure QML + **Python/bash scripts** (`scripts/*`), no compiled code |
| Entry | `shell.qml` → `Background`, `Drawers`, `AreaPicker`, `Lock` + daemons | `shell.qml` → `PanelFamilyLoader` → `panelFamilies/IllogicalImpulseFamily.qml` |
| UI architecture | One fullscreen "drawers" layer per screen (`modules/drawers/*`) with masked regions; bar, launcher, dashboard, sidebar, OSD, session, notifs all slide out of the screen border | Separate PanelWindow per module (`modules/ii/*`), toggled via `GlobalStates` |
| Config | Typed C++ settings tree (`plugin/src/Caelestia/Config`, `Settings`), file `~/.config/caelestia/shell.json`, per-monitor overrides, schema + quarantine of bad values | One big `JsonAdapter` in `modules/common/Config.qml` (~1060 lines), file under end4-pC's own config dir |
| Theming | `services/Colours.qml` reads `~/.local/state/caelestia/scheme.json`; generation is done by the external **`caelestia` CLI** (`caelestia scheme set`, `caelestia wallpaper`) | `services/MaterialThemeLoader.qml` + `scripts/colors/switchwall.sh` → **matugen** + `generate_colors_material.py`; also templates for KDE/Kvantum/terminal/VS Code |
| Settings UI | `modules/nexus` (separate settings window, page registry) | `modules/ii/settings` + `SettingsPages`/`SettingsSearchIndex` services |
| Compositor | **Hyprland only.** `services/Hypr.qml` wraps `Quickshell.Hyprland`; C++ `hyprextras`/`hyprdevices` talk to the Hyprland socket | **Hyprland + partial Niri.** `services/WM.qml` picks `HyprlandBackend` or `NiriBackend`; `NiriConfig`, `NiriXkb`, `NiriOverview` exist |
| Install dependency | caelestia-cli, caelestia-dots | Requires illogical-impulse (end-4/dots-hyprland) installed underneath |

---

## 1b. v1 scope: Fierra's picks (2026-11-19)

> "Basically Caelestia's bar with end4's customizability." This list **overrides §3** where they differ: anything not here is out of v1.

**From end4-pC** (ported as caelestia-style rewrites, see the ground rule in §3):

| Feature | end4 source | Port notes | Niri |
|---|---|---|---|
| Bar options (position, corner styles, auto-hide, widget choice...) | `Config.options.bar.*`, `modules/ii/bar`, `verticalBar` | Applied to **caelestia's bar**; needs orientation-aware drawers first (see Config parity) | yes |
| Quick settings | `modules/ii/sidebarRight` (`quickToggles`, `QuickSliders`, wifi/bt/vpn, night light, volume mixer) | Becomes a caelestia drawer/popout; reuse caelestia services (Audio, Nmcli, VPN, Brightness) | yes (night light via wlsunset/gammastep) |
| AI sidebar + rest of left sidebar | `modules/ii/sidebarLeft`, `services/Ai.qml`, `Translation`, `Booru` | Drawer left of the bar (decided earlier) | yes |
| Spotlight search / start menu | `modules/ii/overview` `SearchWidget`/`SearchBar` + `services/LauncherSearch.qml` | Merge its search providers (math, web, emoji, clipboard, actions) into caelestia's launcher; keep the launcher's look | yes |
| Anti-flashbang | `services/HyprlandAntiFlashbangShader.qml` (sets `decoration:screen_shader`) | Small Hyprland-only toggle service | **no** (Niri has no screen shaders), hide option |
| Lockscreen | `modules/ii/lock`, `modules/common/panels/lock` | Replace caelestia's lock UI with end4's layout, keep caelestia's `Pam.qml` auth | yes (ext-session-lock) |
| Polkit agent | `modules/ii/polkit`, `services/PolkitService.qml` | Caelestia has none, port as-is restyled | yes |
| Screenshotter | `modules/ii/regionSelector` (rect/circle select, options toolbar, OCR/search/record actions) | Replaces caelestia `areapicker`; keep caelestia's freeze-mode + `CUtils.saveItem` | yes, window snapping Hyprland-only |

**From caelestia** (keep as-is, make configurable):

| Feature | Where | Work needed |
|---|---|---|
| Workspace window icons | `modules/bar/components/workspaces` (`showWindows`, `maxWindowIcons`) | Move to `Compositor.toplevels` for Niri |
| Special workspaces (music, comms...) that launch their app | `Hypr.toggleSpecial`, `cycleSpecialWorkspace`; app launch currently lives in the dots' Hyprland config | New typed config list `specialWorkspaces: [{ name, icon, apps: [cmd...], keybind }]`. On toggle: if the workspace is empty, launch its apps. Editable from nexus. Niri has no special workspaces, so emulate with a named workspace + focus-back toggle |
| Caps/Num lock OSD + indicators | `Hypr.capsLock/numLock`, lock `StateMessage`, bar status | Via `Compositor` keyboard API (Niri: read `/sys/class/leds`) |

Everything else from §3 (dock, overview grid, OSK, translator, presets, football...) is **post-v1**.

## 2. Recommendation: Caelestia as the base, end4 features ported in

**Base = caelestia-shell.** Reasons:

- Its compositor surface is small and already centralised. Outside `services/Hypr.qml`, modules use about 20 `Hypr.*` members (`capsLock`, `numLock`, `activeToplevel`, `workspaces`, `dispatch`, `monitorFor`, `kbLayout*`, `toggleSpecial`, `focusWorkspace`, ...). Swapping that one singleton for a compositor-neutral one is a contained job.
- The typed C++ config, image cache, audio visualiser, sysinfo services and shaders are things end4 does in scripts or not at all. Porting them *into* end4 would be much harder than porting end4's QML features *onto* caelestia.
- end4-pC is not standalone: it assumes illogical-impulse is installed. caend should not inherit that.

**From end4-pC we take the idea and code of its WM abstraction** (`services/WM.qml` + `HyprlandBackend.qml` + `NiriBackend.qml`), plus selected feature modules (below).

The alternative (end4 as base, re-skin with caelestia drawers) is viable since end4 already half-supports Niri, but its Hyprland coupling is wider (60 QML files touch Hyprland APIs, 72 `compositor ===` branches) and you'd lose the C++ plugin.

---

### Ground rule: port end4's *features*, not its code

Fierra's goal: Caelestia's smoothness with end4's integration and customizability. Fierra also reports that end4-pC stutters every few minutes. The code backs that up: end4-pC declares about **238 `Process {}` blocks** (shelling out to bash/python) and 31 services with timers, while caelestia has about **33**. Caelestia does the heavy work in its C++ plugin instead.

So every end4 feature that comes over gets rewritten in the caelestia style:
- No polling `Timer` + `Process` loops. Use events (D-Bus, file watches, compositor event streams) or a C++ `Service` in `plugin/src/Caelestia/Services`.
- Long-lived helpers (one process that streams JSON), not a new process per tick.
- UI built from caelestia components and animation tokens, so it moves like the rest of the shell.
- Settings exposed through caelestia's typed config + nexus pages, so end4-level customizability doesn't mean end4-style config sprawl.

## 3. Component-by-component picks

| Area | Take from | Notes |
|---|---|---|
| **Bar** | caelestia `modules/bar` | Keep the drawers-attached bar. Port end4 widgets as bar components where wanted: `DynamicIsland`, lyrics, resource monitor, `HyprlandXkbIndicator` (rewritten against the new `Compositor` keyboard API). |
| **Workspaces widget** | caelestia `bar/components/workspaces` | Rewrite data source to `Compositor.workspaces`; special workspaces are Hyprland-only (hide on Niri). |
| **Launcher** | caelestia `modules/launcher` | Better integrated (apps via C++ `appdb`, qalculator, schemes, wallpapers). Optionally add end4 `LauncherSearch` actions (emoji, clipboard via `Cliphist`, web search). |
| **Notifications** | caelestia `services/Notifs.qml` + `modules/notifications` + sidebar notif dock | Feature-equivalent; caelestia's grouping/dock is nicer. Drop end4 `Notifications.qml`. |
| **Right sidebar / quick toggles** | caelestia `modules/sidebar` + `modules/utilities` for layout; port end4 quick toggles (`sidebarRight/quickToggles`), night light (`Hyprsunset` → abstract, see §5), EQ/EasyEffects | |
| **Left sidebar (AI, translator, booru, notes, todo)** | end4 `modules/ii/sidebarLeft` + `services/Ai.qml`, `Translation`, `Booru`, `Todo`, `Notes` | No caelestia equivalent. **Decided (Fierra): a caelestia drawer that slides out from the left screen edge, outside the bar**, so the layout reads `AI sidebar | caelestia bar | windows`. When it opens, the bar and the drawers' border shift right by the panel width (same drawer mechanics as `modules/drawers`, with the bar's exclusion zone growing). Restyle with caelestia components. |
| **Dashboard** | caelestia `modules/dashboard` | Add end4 extras as tabs if wanted: Football, WorldClock, Presets. |
| **Overview** | end4 `modules/ii/overview` (`Overview.qml` for Hyprland, `NiriOverview.qml` for Niri) | Caelestia has none. Uses `WM`/`HyprlandData` already, so it ports after §5. |
| **Dock** | end4 `modules/ii/dock` | Caelestia has none. Make it optional. |
| **OSD / session / lock** | caelestia (`osd`, `session`, `lock` with PAM) | end4 versions redundant. |
| **Polkit agent, on-screen keyboard, screen translator, region selector, desktop widgets** | end4 | Caelestia lacks polkit + OSK + translator. Caelestia `areapicker` replaces end4 `regionSelector`. |
| **Wallpaper selector** | caelestia launcher wallpaper list + end4 `OnlineWallpapers`/`WallhavenSearch` as an extra source | |
| **Services** (audio, brightness, network, players, weather, battery, bluetooth) | caelestia | Delete end4 duplicates (`Audio`, `Brightness`, `Network`, `MprisController`, `Weather`, `Battery`). Keep end4-only ones listed above plus `Cliphist`, `Emojis`, `Updates`, `PolkitService`, `Ydotool`, `LyricsService` (compare with caelestia C++ `lyrics.cpp` first; likely drop end4's). |
| **Settings app** | caelestia `nexus` | Add pages for ported features. Port end4 `HyprlandConfig`/`NiriConfig` editors as a "Compositor" page. |
| **Presets gallery** (end4-pCpresets) | Defer | Tied to end4's config layout and the pctrade presets repo. Revisit after config is unified. |
| **AI / cloud usage widgets** (`ClaudeUsage`, `CodexUsage`, `GoogleCloud`) | Optional, later | Personal extras. |

---

### Config parity goal (Fierra, 2026-11-19)

**Every customization option end4-pC has should exist in caend**, including bar position. Scale: end4-pC's `modules/common/Config.qml` declares about **745** properties; caelestia's C++ config has about **295** `CONFIG_PROPERTY` entries. A lot overlap, but expect a few hundred new typed options plus nexus pages.

How to get there:
1. **Parity table first.** Mechanically list every end4 `Config.options.*` key, map it to an existing caelestia key or mark it "new", and group it by feature. That becomes the porting checklist and keeps settings from being forgotten.
2. **Bar position is the big structural one.** end4 has `bar.bottom`, `vertical` layouts (`verticalBar`), `cornerStyle` (hug/float/plain/M3/panel/split), `autoHide`. Caelestia's bar is always a vertical bar on the left edge, and `modules/drawers` (`Exclusions`, `Regions`, `Panels`, border) assumes that. Add `bar.position: left|right|top|bottom` and make the drawers, the border and the popouts orientation-aware *before* porting other bar options. Corner styles and auto-hide come after that.
3. Everything else is additive: one typed config node + one nexus page per ported feature, done as part of that feature's port.

## 4. Architecture and dependency conflicts

1. **Config systems.** caelestia's typed C++ `Config` vs end4's `Config.options.*` JsonAdapter. Every end4 module reads `Config.options.x.y`. Plan: add new typed nodes to the C++ config (`plugin/src/Caelestia/Config/*config.hpp`) for each ported feature, then mechanically rewrite `Config.options.foo` → caelestia's `GlobalConfig.foo` access. Do not run two config files.
2. **Styling tokens.** end4 uses `Appearance.*` (`modules/common/Appearance.qml`) and its own widget set (`modules/common/widgets`, ~100 widgets). caelestia uses `Colours`/tokens from its plugin and `components/*`. Ported modules must be restyled onto caelestia components; a temporary `Appearance` shim mapping to caelestia tokens can speed up the first port.
3. **Colour generation.** caelestia depends on the external `caelestia` CLI (Python) writing `scheme.json`; end4 runs matugen + Python. Pick **one**: keep the caelestia CLI as the generator (the shell already listens to it), and port end4's extra *templates* (KDE, Kvantum, terminal, VS Code in `scripts/colors`, `scripts/kvantum`) as post-hooks. Dropping matugen removes a dependency.
4. **Window model.** Caelestia draws everything in one `drawers` layer with an input mask; end4 opens separate PanelWindows. Ported end4 panels (AI sidebar, dock, overview) should either become drawers (consistent look, more work) or stay as standalone layer windows (faster). Decided: sidebar → drawer (see §3); suggest overview and dock → standalone.
5. **Build.** caend needs CMake + Qt6 dev packages for the plugin; end4's Python scripts need their own venv (`scripts/lib`, materialyoucolor, etc.). Keep Python only for features that need it (AI, booru, football, thumbnails).
6. **Paths / names.** caelestia uses `~/.config/caelestia`, `~/.local/state/caelestia`, QML module `Caelestia.*`, layer namespace `caelestia-drawers`. Decide early whether caend renames these (`caend`) or stays compatible with caelestia-cli. Renaming the C++ module URI is a big diff; recommend keeping `Caelestia.*` QML URIs and renaming only user-facing paths/app id.
7. **Licences.** Both are GPL-3.0, so combining is fine; keep both copyright notices.
8. **Upstream tracking.** caelestia is very active; caend should keep caelestia as a git remote and merge it, so keep changes to caelestia files small and put new stuff in new files.

---

## 5. Hyprland-specific code and the Niri abstraction

### 5.1 Introduce `services/Compositor.qml`

Replace caelestia's `Hypr` singleton with a `Compositor` singleton modelled on end4's `WM.qml`: detect via `XDG_CURRENT_DESKTOP`, instantiate `HyprlandBackend` or `NiriBackend`, proxy a common API. Keep `Hypr` as a thin alias during migration so modules can move one at a time.

Common API (union of what caelestia modules use today and what end4's `WM` already exposes):

| Member | Hyprland | Niri |
|---|---|---|
| `workspaces`, `focusedWorkspace`, `activeWsId` | `Quickshell.Hyprland` | `niri msg -j event-stream` (`WorkspacesChanged`, `WorkspaceActivated`) |
| `toplevels`, `activeToplevel`, `toplevelsForWs()` | `Hyprland.toplevels` | event-stream `WindowsChanged`/`WindowFocusChanged`; or `Quickshell.Wayland.ToplevelManager` for both |
| `monitors`, `focusedMonitor`, `monitorFor(screen)` | `Hyprland.monitors` | `niri msg -j outputs` + `focused-output` |
| `focusWorkspace(id)`, `focusWindow`, `closeWindow`, `moveWindowToWorkspace` | `Hyprland.dispatch` (lua or legacy syntax, see `usingLua`) | `niri msg action ...` (already in end4 `NiriBackend.qml`) |
| `switchWorkspaceRelative(dir)` | `workspace r±1` | `focus-workspace-up/down` |
| Keyboard: `capsLock`, `numLock`, `kbLayout`, `kbLayoutFull` | C++ `HyprExtras`/`HyprDevices` | end4 `NiriXkb.qml` (`KeyboardLayoutsChanged`); caps/num lock not exposed by niri, read from `/sys/class/leds/*::capslock` |
| `fullscreenOnMonitor` | ws `hasfullscreen` | window `is_fullscreen`? fall back to false |
| `toggleSpecial`, `cycleSpecialWorkspace` | special workspaces | **No equivalent** → hide UI / no-op (`capabilities.specialWorkspaces = false`) |
| `dispatch(raw)` | raw | not supported; callers must use typed methods |
| `configReloaded` signal | `configreloaded` event | `ConfigLoaded` event |

Add a `capabilities` object (`specialWorkspaces`, `layerRules`, `globalShortcuts`, `focusGrab`, `overview`) so UI can hide features rather than branching on compositor names everywhere.

Implementation tip: a Niri event-stream reader is simplest in QML (`Process` + `SplitParser` on `niri msg -j event-stream`), which end4 already does. Later it can move into the C++ plugin next to `hyprextras.cpp` for speed.

### 5.2 Hyprland-only touchpoints in caelestia to fix

| File(s) | What's Hyprland-specific | Niri plan |
|---|---|---|
| `services/Hypr.qml` | the whole singleton | becomes `HyprlandBackend` behind `Compositor` |
| `plugin/src/Caelestia/Services/hyprextras.*`, `hyprdevices.*` | Hyprland socket (keyboards, options, `hyprctl` style requests) | keep for Hyprland; add a Niri path for keyboard state |
| `daemons/Shortcuts.qml`, `components/misc/CustomShortcut.qml` | `GlobalShortcut` from `Quickshell.Hyprland` (appid `caelestia`) | Niri has no global-shortcut protocol for clients; use `IpcHandler` (caelestia already does this for lock, areapicker and players) + `qs ipc call ...` bound in niri `config.kdl` `binds {}`. Ship a sample KDL snippet. Works on Hyprland too, so consider IPC everywhere. |
| `modules/drawers/ContentWindow.qml` | `HyprlandFocusGrab`, `HyprlandMonitor` | use `WlrLayershell.keyboardFocus: Exclusive/OnDemand` when grab unsupported |
| `services/Colours.qml` (lines ~86-91) | sets Hyprland `layerrule` for blur/transparency on `caelestia-drawers` | Niri: `layer-rule` in KDL (static); skip at runtime, ship snippet |
| `modules/bar/components/workspaces/*` | special workspaces, `Hypr.workspaces` objects (`lastIpcObject`) | use normalized workspace objects; Niri workspaces are per-output and dynamic |
| `modules/windowinfo/*` | Hyprland client props (`lastIpcObject`: pid, floating, xwayland...) | show the subset niri provides |
| `modules/bar/popouts/kblayout`, `ActiveWindow` popout | Hyprland keyboard + toplevel | `Compositor` keyboard/toplevel API |
| `daemons/GameMode.qml` | toggles Hyprland animations/blur via keyword | Hyprland-only; hide on Niri |
| `modules/areapicker` | Hyprland clients for window snapping | use `Compositor.toplevels` geometry; niri `windows` gives layout size but not absolute position in older versions, so snap-to-window may be Hyprland-only |
| `modules/lock/center` | Hyprland kb state | via `Compositor` |

### 5.3 Hyprland-only touchpoints in end4 features being ported

- `services/HyprlandData.qml` (still used directly by 11 modules), `HyprlandKeybinds`, `HyprlandOptions`, `HyprlandXkb`, `HyprlandConfig`, `Hyprsunset`, `HyprlandAntiFlashbangShader`, `GlassLayers`/`GlassFloating`, `scripts/hyprland/*`.
- Port rule: anything that reads state goes through `Compositor`; anything that edits compositor config stays compositor-specific and lives in the settings "Compositor" page (`HyprlandConfig` ↔ `NiriConfig`, which writes `~/.config/niri/qssettings/settings.json` included from `config.kdl`).
- `Hyprsunset` (night light): use `hyprsunset` on Hyprland, `wlsunset`/`gammastep` on Niri behind one `NightLight` service.
- Keybind cheatsheet: `HyprlandKeybinds` parses Hyprland config; Niri needs a KDL `binds` parser, or hide the cheatsheet on Niri at first.
- end4 already disables the overview and lock wallpaper on Niri (`shell.qml`); `NiriOverview.qml` exists and should be the Niri implementation of the overview.

---

## 6. Suggested order of work

1. **Bootstrap caend from caelestia-shell** (add caelestia upstream as a remote, keep history). Rename user-facing app id / paths per §4.6. Build the plugin and confirm it runs on Hyprland.
2. **Compositor abstraction** (§5.1): add `Compositor` + `HyprlandBackend` (wrapping current `Hypr`), migrate every `Hypr.*` call, then add `NiriBackend` (start from end4's file). Replace `GlobalShortcut` with `IpcHandler`. Milestone: bar, launcher, notifs, OSD, lock, session working on Niri.
3. **Port end4 standalone features** one per PR, each with its config node and nexus page: overview (+Niri), polkit, dock, left sidebar (AI/translator/todo/notes), clipboard/emoji launcher actions, OSK, desktop widgets.
4. **Theming extras**: end4 KDE/Kvantum/terminal/VS Code templates as hooks on the caelestia scheme generator.
5. **Compositor config page**: port `HyprlandConfig` + `NiriConfig` editors, night light abstraction, keybind cheatsheet.
6. **Optional**: presets gallery, online wallpapers, football/AI usage widgets.

## 7. Open questions for Fierra

- Keep compatibility with `caelestia-cli` (scheme/wallpaper generation), or fork the CLI into caend too?
- Rename runtime paths to `caend` (clean, but breaks caelestia-cli interop) or keep `caelestia`?
- ~~Should end4's left-sidebar features become a drawer or stay standalone panels?~~ **Answered:** drawer, opening to the left of the bar (`AI sidebar | bar | windows`).
- Which end4 extras actually matter to you (AI chat, booru, football, presets, dock)? The plan treats AI sidebar, overview, dock and polkit as must-haves and the rest as optional.
