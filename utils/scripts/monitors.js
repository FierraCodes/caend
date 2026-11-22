.pragma library

// Pure helpers for services/Monitors.qml (also loaded by tests/monitors.test.mjs).
// A monitor is { name, description, modes, mode, x, y, scale, transform, disabled, vrr, bitdepth, cm }
// where mode/modes are "WIDTHxHEIGHT@REFRESH" strings in the compositor's own refresh format.

var TRANSFORMS = ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"];

function parseMode(mode) {
    const m = /^(\d+)x(\d+)@([\d.]+)/.exec(mode ?? "");
    return m ? { width: +m[1], height: +m[2], refresh: +m[3] } : null;
}

function logicalSize(mon) {
    const mode = parseMode(mon.mode) ?? { width: 1920, height: 1080 };
    const rotated = mon.transform % 2 === 1;
    const scale = mon.scale > 0 ? mon.scale : 1;
    return {
        w: Math.round((rotated ? mode.height : mode.width) / scale),
        h: Math.round((rotated ? mode.width : mode.height) / scale)
    };
}

// `hyprctl monitors all -j`
function fromHyprland(list) {
    return list.map(m => {
        const modes = [...new Set((m.availableModes ?? []).map(s => s.replace(/Hz$/, "")))];
        // A disabled output reports 0x0, so turning it back on uses its best mode instead
        const mode = m.width > 0 ? `${m.width}x${m.height}@${(+m.refreshRate).toFixed(2)}` : modes[0] ?? "preferred";
        return {
            name: m.name,
            description: m.description ?? "",
            modes: modes.includes(mode) || !parseMode(mode) ? modes : [mode, ...modes],
            mode,
            x: m.x,
            y: m.y,
            scale: m.scale,
            transform: m.transform ?? 0,
            disabled: !!m.disabled,
            vrr: !!m.vrr,
            bitdepth: /2101010/.test(m.currentFormat ?? "") ? 10 : 8,
            cm: m.colorManagementPreset ?? "auto"
        };
    });
}

// `niri msg -j outputs`
function fromNiri(outputs) {
    const fmt = mode => `${mode.width}x${mode.height}@${(mode.refresh_rate / 1000).toFixed(3)}`;
    return Object.values(outputs).map(o => {
        const current = o.modes?.[o.current_mode] ?? o.modes?.find(md => md.is_preferred) ?? null;
        // niri-ipc serialises transforms as "Normal", "_90", "Flipped90"...
        const t = String(o.logical?.transform ?? "normal").toLowerCase().replace(/^_/, "").replace(/^flipped(\d)/, "flipped-$1");
        return {
            name: o.name,
            description: [o.make, o.model].filter(s => s && s !== "Unknown").join(" "),
            modes: [...new Set((o.modes ?? []).map(fmt))],
            mode: current ? fmt(current) : o.modes?.[0] ? fmt(o.modes[0]) : "",
            x: o.logical?.x ?? 0,
            y: o.logical?.y ?? 0,
            scale: o.logical?.scale ?? 1,
            transform: Math.max(0, TRANSFORMS.indexOf(t)),
            disabled: !o.logical,
            vrr: !!o.vrr_enabled,
            bitdepth: 8,
            cm: "auto"
        };
    });
}

// The settings a saved rule puts back (not modes/description, which come from the hardware)
function layoutOf(m) {
    return { mode: m.mode, x: m.x, y: m.y, scale: m.scale, transform: m.transform, disabled: m.disabled, vrr: m.vrr, bitdepth: m.bitdepth, cm: m.cm };
}

function hyprConfLine(m) {
    if (m.disabled)
        return `monitor = ${m.name}, disable`;
    let line = `monitor = ${m.name}, ${m.mode}, ${m.x}x${m.y}, ${m.scale}, transform, ${m.transform}, vrr, ${m.vrr ? 1 : 0}`;
    if (m.bitdepth === 10)
        line += ", bitdepth, 10";
    if (m.cm && m.cm !== "auto")
        line += `, cm, ${m.cm}`;
    return line;
}

function hyprLuaLine(m) {
    const q = s => `"${String(s).replace(/["\\]/g, "\\$&")}"`;
    if (m.disabled)
        return `hl.monitor({ output = ${q(m.name)}, disabled = true })`;
    let line = `hl.monitor({ output = ${q(m.name)}, mode = ${q(m.mode)}, position = "${m.x}x${m.y}", scale = ${m.scale}, disabled = false, transform = ${m.transform}, vrr = ${m.vrr ? 1 : 0}`;
    if (m.bitdepth === 10)
        line += ", bitdepth = 10";
    if (m.cm && m.cm !== "auto")
        line += `, cm = ${q(m.cm)}`;
    return line + " })";
}

function niriKdl(m) {
    const q = s => `"${String(s).replace(/["\\]/g, "\\$&")}"`;
    if (m.disabled)
        return `output ${q(m.name)} {\n    off\n}\n`;
    let kdl = `output ${q(m.name)} {\n    mode ${q(m.mode)}\n    scale ${m.scale}\n    transform ${q(TRANSFORMS[m.transform] ?? "normal")}\n    position x=${m.x} y=${m.y}\n`;
    if (m.vrr)
        kdl += "    variable-refresh-rate\n";
    return kdl + "}\n";
}

function overlaps(a, b) {
    const sa = logicalSize(a), sb = logicalSize(b);
    return a.x < b.x + sb.w && a.x + sa.w > b.x && a.y < b.y + sb.h && a.y + sa.h > b.y;
}

// Where `name` lands when dropped at (px, py): flush against the nearest face of another output (sliding
// along that face, with its ends snapping into line within `threshold`), then everything shifted so the layout
// starts at 0,0. Returns { name: {x, y} }, or null when no face has room.
function arrange(mons, name, px, py, threshold) {
    const me = mons.find(m => m.name === name);
    const others = mons.filter(m => m.name !== name && !m.disabled);
    const size = logicalSize(me);
    const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
    // Slide along a face, but line up with the face's ends when close
    const along = (pos, start, len, myLen) => {
        const v = clamp(pos, start - myLen + 1, start + len - 1);
        if (Math.abs(v - start) <= threshold)
            return start;
        if (Math.abs(v + myLen - start - len) <= threshold)
            return start + len - myLen;
        return v;
    };

    let moved = null, best = Infinity;
    for (const o of others) {
        const s = logicalSize(o);
        const ay = along(py, o.y, s.h, size.h), ax = along(px, o.x, s.w, size.w);
        const cands = [
            { x: o.x - size.w, y: ay }, // left
            { x: o.x + s.w, y: ay }, // right
            { x: ax, y: o.y - size.h }, // above
            { x: ax, y: o.y + s.h } // below
        ];
        for (const c of cands) {
            const cand = Object.assign({}, me, { x: Math.round(c.x), y: Math.round(c.y) });
            const d = Math.hypot(cand.x - px, cand.y - py);
            if (d < best && !others.some(other => overlaps(cand, other))) {
                best = d;
                moved = cand;
            }
        }
    }
    if (!others.length)
        moved = Object.assign({}, me, { x: 0, y: 0 });
    if (!moved)
        return null;

    const all = [moved, ...others];
    const minX = Math.min(...all.map(m => m.x)), minY = Math.min(...all.map(m => m.y));
    const out = {};
    for (const m of all)
        out[m.name] = { x: m.x - minX, y: m.y - minY };
    return out;
}
