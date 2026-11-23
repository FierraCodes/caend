pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components.misc
import qs.services

// end4-style recorder: wf-recorder for a region or the focused output, with system audio and/or mic.
// The process lives as long as the recording, so its running state needs no polling.
Singleton {
    id: root

    readonly property bool running: proc.running
    readonly property bool paused: false // wf-recorder can't pause
    property real elapsed
    property int refCount // Kept for Ref users; nothing to poll anymore
    property string file
    property bool pendingSound

    // $1 file, $2 geometry ("x,y wxh", empty = whole output), $3 output, $4 system audio, $5 mic
    readonly property string script: `mkdir -p "$(dirname "$1")"
sysmon="$(pactl get-default-sink 2>/dev/null).monitor"
micsrc="$(pactl get-default-source 2>/dev/null)"
mods=""
audio=""
if [ "$4" = 1 ] && [ "$5" = 1 ]; then
    m=$(pactl load-module module-null-sink sink_name=caend_rec_mix sink_properties=device.description=CaendRecordMix) && mods="$m"
    m=$(pactl load-module module-loopback source="$sysmon" sink=caend_rec_mix latency_msec=30) && mods="$mods $m"
    m=$(pactl load-module module-loopback source="$micsrc" sink=caend_rec_mix latency_msec=30) && mods="$mods $m"
    audio=caend_rec_mix.monitor
elif [ "$4" = 1 ]; then
    audio="$sysmon"
elif [ "$5" = 1 ]; then
    audio="$micsrc"
fi
file="$1"; geom="$2"; out="$3"
set -- --pixel-format yuv420p -f "$file"
if [ -n "$geom" ]; then set -- "$@" --geometry "$geom"; else set -- "$@" -o "$out"; fi
[ -n "$audio" ] && set -- "$@" "--audio=$audio"
wf-recorder "$@" &
pid=$!
trap 'kill -INT "$pid" 2>/dev/null' INT TERM
wait "$pid"
wait "$pid"
code=$?
for m in $mods; do pactl unload-module "$m"; done
exit $code`

    // Region recordings pick their area with the shell's area picker, which calls startRegion()
    signal regionRequested

    function start(region = false, sound = false): void {
        if (running)
            return;
        pendingSound = sound;
        if (region)
            regionRequested();
        else
            launch("", Compositor.focusedOutput);
    }

    function startRegion(geometry: string): void {
        launch(geometry, "");
    }

    function stop(): void {
        proc.signal(2); // SIGINT lets wf-recorder finalise the file
    }

    function togglePause(): void {
    }

    function launch(geometry: string, output: string): void {
        file = `${Paths.recsdir}/recording_${Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh.mm.ss")}.mp4`;
        elapsed = 0;
        proc.command = ["sh", "-c", script, "sh", file, geometry, output, pendingSound ? "1" : "0", GlobalConfig.utilities.recordMicrophone ? "1" : "0"];
        proc.running = true;
    }

    Process {
        id: proc

        onRunningChanged: {
            if (running)
                Quickshell.execDetached(["notify-send", "-a", "caelestia", Tr.tr("Recording started"), root.file.split("/").pop()]);
        }
        onExited: code => {
            if (code === 127)
                Quickshell.execDetached(["notify-send", "-a", "caelestia", Tr.tr("Recording failed"), Tr.tr("Needs wf-recorder")]);
            else
                Quickshell.execDetached(["notify-send", "-a", "caelestia", Tr.tr("Recording saved"), root.file]);
        }
    }

    // For keybinds: qs -c caelestia ipc call recorder toggle region-sound
    IpcHandler {
        function toggle(mode: string): void {
            if (root.running)
                root.stop();
            else
                root.start(mode.startsWith("region"), mode.endsWith("sound"));
        }

        target: "recorder"
    }

    // Global shortcuts, e.g. hl.dsp.global("caelestia:recordRegion"); pressing again stops
    RecordShortcut {
        name: "record"
        description: "Toggle fullscreen recording"
        region: false
        sound: false
    }

    RecordShortcut {
        name: "recordSound"
        description: "Toggle fullscreen recording with sound"
        region: false
        sound: true
    }

    RecordShortcut {
        name: "recordRegion"
        description: "Toggle region recording"
        region: true
        sound: false
    }

    RecordShortcut {
        name: "recordRegionSound"
        description: "Toggle region recording with sound"
        region: true
        sound: true
    }

    Connections {
        function onSecondsChanged(): void {
            root.elapsed++;
        }

        enabled: root.running
        target: Time
    }

    // qmllint disable unresolved-type
    component RecordShortcut: CustomShortcut {
        // qmllint enable unresolved-type
        required property bool region
        required property bool sound

        onPressed: root.running ? root.stop() : root.start(region, sound)
    }
}
