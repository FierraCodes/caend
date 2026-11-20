// node tests/monitors.test.mjs
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const src = readFileSync(new URL("../utils/scripts/monitors.js", import.meta.url), "utf8").replace(".pragma library", "");
const M = new Function(`${src}; return { parseMode, logicalSize, fromHyprland, fromNiri, hyprConfLine, hyprLuaLine, niriKdl, arrange };`)();

const a = { name: "DP-1", mode: "2560x1440@165.00", x: 0, y: 0, scale: 1, transform: 0, disabled: false, vrr: true, bitdepth: 10, cm: "hdr" };
const b = { name: "HDMI-A-1", mode: "1920x1080@60.00", x: 2560, y: 0, scale: 1.5, transform: 1, disabled: false, vrr: false, bitdepth: 8, cm: "auto" };

assert.deepEqual(M.logicalSize(b), { w: 720, h: 1280 });
assert.equal(M.hyprConfLine(a), "monitor = DP-1, 2560x1440@165.00, 0x0, 1, transform, 0, vrr, 1, bitdepth, 10, cm, hdr");
assert.equal(M.hyprConfLine({ ...b, disabled: true }), "monitor = HDMI-A-1, disable");
assert.equal(M.hyprLuaLine(b), 'hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60.00", position = "2560x0", scale = 1.5, disabled = false, transform = 1, vrr = 0 })');
assert.match(M.niriKdl(b), /transform "90"\n    position x=2560 y=0\n}/);

// Drop b slightly left of a's right edge: snaps flush, no overlap
assert.deepEqual(M.arrange([a, b], "HDMI-A-1", 2540, 10, 50), { "HDMI-A-1": { x: 2560, y: 0 }, "DP-1": { x: 0, y: 0 } });
// Drop b to the left of a: layout is shifted so it starts at 0
assert.deepEqual(M.arrange([a, b], "HDMI-A-1", -700, 0, 50), { "HDMI-A-1": { x: 0, y: 0 }, "DP-1": { x: 720, y: 0 } });
// Drop b on top of a, nearer a's bottom: pushed flush below a, sliding along its face
assert.deepEqual(M.arrange([a, b], "HDMI-A-1", 500, 1300, 10), { "HDMI-A-1": { x: 500, y: 1440 }, "DP-1": { x: 0, y: 0 } });
// Drop b far away to the right with a gap: still lands flush on a's right face
assert.deepEqual(M.arrange([a, b], "HDMI-A-1", 4000, 5, 10), { "HDMI-A-1": { x: 2560, y: 0 }, "DP-1": { x: 0, y: 0 } });

const niri = M.fromNiri({ "DP-2": { name: "DP-2", make: "Dell", model: "U27", modes: [{ width: 2560, height: 1440, refresh_rate: 59951, is_preferred: true }], current_mode: 0, vrr_enabled: false, logical: { x: 10, y: 0, scale: 1.25, transform: "Flipped90" } } });
assert.equal(niri[0].mode, "2560x1440@59.951");
assert.equal(niri[0].transform, 5);
assert.equal(niri[0].description, "Dell U27");

const hypr = M.fromHyprland([{ name: "eDP-1", width: 1920, height: 1200, refreshRate: 60.002, x: 0, y: 0, scale: 1, transform: 0, disabled: false, vrr: false, availableModes: ["1920x1200@60.00Hz", "1920x1200@48.00Hz"], currentFormat: "XRGB8888" }]);
assert.equal(hypr[0].mode, "1920x1200@60.00");
assert.deepEqual(hypr[0].modes, ["1920x1200@60.00", "1920x1200@48.00"]);

// Re-enabling a disabled Hyprland output must not send its reported 0x0 mode
const off = M.fromHyprland([{ name: "HDMI-A-1", width: 0, height: 0, refreshRate: 0, x: 0, y: 0, scale: 1, disabled: true, availableModes: ["1920x1080@60.00Hz", "1920x1080@144.00Hz"] }]);
assert.equal(off[0].mode, "1920x1080@60.00");
assert.match(M.hyprLuaLine({ ...off[0], disabled: false }), /mode = "1920x1080@60.00".*disabled = false/);

console.log("monitors tests passed");
