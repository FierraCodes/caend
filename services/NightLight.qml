pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Warm screen tint via hyprsunset (Hyprland). One long-lived process while enabled, no polling.
Singleton {
    id: root

    property bool enabled
    property int temperature: 4500

    Process {
        running: root.enabled && Compositor.isHyprland
        command: ["hyprsunset", "-t", String(root.temperature)]
    }
}
