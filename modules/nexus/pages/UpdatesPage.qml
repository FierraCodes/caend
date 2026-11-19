pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// System (pacman/AUR) and shell (git) updates, with a small live log of whatever is running
PageBase {
    id: root

    property int repoCount: -1
    property int aurCount: -1
    property list<string> shellCommits: []
    property bool shellChecked
    property string log
    property string running // Label of the job writing to the log

    // ANSI colour/cursor codes would show up as junk in the log
    function strip(line: string): string {
        return line.replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "").replace(/\r/g, "");
    }

    function run(label: string, script: string): void {
        if (job.running)
            return;
        log = "";
        running = label;
        job.command = ["sh", "-c", `${script} 2>&1`];
        job.running = true;
    }

    function check(): void {
        repoCheck.running = true;
        aurCheck.running = true;
        shellCheck.running = true;
    }

    title: Tr.tr("Updates")

    Component.onCompleted: check()

    // checkupdates (pacman-contrib) uses its own db copy, so checking never needs root
    Process {
        id: repoCheck

        command: ["sh", "-c", "command -v checkupdates >/dev/null || exit 3; checkupdates; [ $? -eq 2 ] && exit 0"]
        stdout: StdioCollector {
            onStreamFinished: root.repoCount = text.trim() ? text.trim().split("\n").length : 0
        }
        onExited: code => {
            if (code === 3)
                root.repoCount = -2;
        }
    }

    Process {
        id: aurCheck

        command: ["sh", "-c", "if command -v paru >/dev/null; then paru -Qua; elif command -v yay >/dev/null; then yay -Qua; else exit 3; fi"]
        stdout: StdioCollector {
            onStreamFinished: root.aurCount = text.trim() ? text.trim().split("\n").length : 0
        }
        onExited: code => {
            if (code === 3)
                root.aurCount = -2;
        }
    }

    Process {
        id: shellCheck

        command: ["sh", "-c", 'git -C "$1" fetch -q && git -C "$1" log --format=%s HEAD..@{u}', "sh", Quickshell.shellDir]
        stdout: StdioCollector {
            onStreamFinished: {
                root.shellCommits = text.trim() ? text.trim().split("\n") : [];
                root.shellChecked = true;
            }
        }
    }

    Process {
        id: job

        stdout: SplitParser {
            onRead: line => root.log += root.strip(line) + "\n"
        }
        onExited: code => {
            root.log += code === 0 ? Tr.tr("\n[done]\n") : Tr.tr("\n[exited with code %1]\n").arg(code);
            root.running = "";
            root.check();
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // System
        SectionHeader {
            first: true
            text: Tr.tr("System")
        }

        InfoRow {
            first: true
            icon: "package_2"
            label: Tr.tr("Repository packages")
            value: root.repoCount === -2 ? Tr.tr("Needs pacman-contrib") : root.repoCount < 0 ? Tr.tr("Checking…") : root.repoCount === 0 ? Tr.tr("Up to date") : Tr.tr("%1 available").arg(root.repoCount)
        }

        InfoRow {
            icon: "deployed_code"
            label: Tr.tr("AUR packages")
            value: root.aurCount === -2 ? Tr.tr("No AUR helper") : root.aurCount < 0 ? Tr.tr("Checking…") : root.aurCount === 0 ? Tr.tr("Up to date") : Tr.tr("%1 available").arg(root.aurCount)
        }

        RowButton {
            icon: "system_update_alt"
            text: Tr.tr("Update repository packages")
            subtext: Tr.tr("pacman -Syu, asks for your password")
            disabled: job.running || root.repoCount <= 0
            onClicked: root.run(Tr.tr("System update"), "pkexec pacman -Syu --noconfirm")
        }

        RowButton {
            last: true
            icon: "terminal"
            text: Tr.tr("Open cachy-update")
            subtext: Tr.tr("Full update including AUR, in your terminal")
            onClicked: Quickshell.execDetached([...GlobalConfig.general.apps.terminal, "sh", "-c", "command -v cachy-update >/dev/null && cachy-update || { paru -Syu || yay -Syu || sudo pacman -Syu; }; read -rp 'Press enter to close'"])
        }

        // Shell
        SectionHeader {
            text: Tr.tr("Shell")
        }

        InfoRow {
            first: true
            icon: "commit"
            label: Tr.tr("caend")
            value: !root.shellChecked ? Tr.tr("Checking…") : root.shellCommits.length === 0 ? Tr.tr("Up to date") : Tr.tr("%1 new commits").arg(root.shellCommits.length)
        }

        Repeater {
            model: root.shellCommits.slice(0, 8)

            InfoRow {
                required property string modelData

                icon: "arrow_right"
                label: modelData
            }
        }

        RowButton {
            icon: "download"
            text: Tr.tr("Update shell")
            subtext: Tr.tr("git pull, then rebuild the plugin if it was built here")
            disabled: job.running || root.shellCommits.length === 0
            onClicked: root.run(Tr.tr("Shell update"), `cd "${Quickshell.shellDir}" && git pull --ff-only && { [ -d build ] && cmake --build build || true; }`)
        }

        RowButton {
            last: true
            icon: "restart_alt"
            text: Tr.tr("Restart shell")
            subtext: Tr.tr("Needed after a shell update")
            disabled: job.running
            onClicked: Quickshell.execDetached(["sh", "-c", "caelestia shell -k; sleep 0.5; caelestia shell -d"])
        }

        // Log
        SectionHeader {
            text: root.running ? Tr.tr("Output — %1").arg(root.running) : Tr.tr("Output")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: 280

            StyledFlickable {
                id: logView

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                clip: true
                contentWidth: width
                contentHeight: logText.implicitHeight
                // Follow new output like a terminal
                onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

                StyledText {
                    id: logText

                    width: logView.width
                    text: root.log || Tr.tr("Nothing running")
                    font: Tokens.font.mono.small
                    color: root.log ? Colours.palette.m3onSurface : Colours.palette.m3outline
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                }
            }
        }
    }
}
