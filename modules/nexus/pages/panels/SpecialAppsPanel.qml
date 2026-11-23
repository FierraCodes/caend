pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common

PageBase {
    id: root

    property string newName
    property string newClass
    property string newCommand

    // QVariantList config: edits replace the whole list
    function update(fn: var): void {
        const list = GlobalConfig.general.specialWorkspaces.map(r => Object.assign({}, r));
        fn(list);
        GlobalConfig.general.specialWorkspaces = list;
    }

    function add(): void {
        const name = newName.trim();
        if (!name || !newCommand.trim())
            return;
        update(list => list.push({
                name,
                class: newClass.trim() || `^${name}$`,
                command: ["sh", "-c", newCommand.trim()]
            }));
        nameField.clear();
        classField.clear();
        commandField.clear();
        newName = newClass = newCommand = "";
    }

    title: Tr.tr("Special workspaces")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Workspaces")
        }

        ListEditor {
            function labelFor(item: var): string {
                return `${item.name}  ·  ${item.class ?? ""}`;
            }

            function toggledFor(item: var): bool {
                return item.enabled ?? true;
            }

            z: 1
            first: true
            values: GlobalConfig.general.specialWorkspaces
            onItemMoved: (from, to) => root.update(list => list.splice(to, 0, ...list.splice(from, 1)))
            onItemRemoved: index => root.update(list => list.splice(index, 1))
            onItemToggled: (index, checked) => root.update(list => list[index].enabled = checked)
        }

        SectionHeader {
            text: Tr.tr("Add a workspace")
        }

        TextFieldRow {
            id: nameField

            first: true
            label: Tr.tr("Name")
            subtext: Tr.tr("Toggle it with: caelestia shell ipc call special toggle <name>")
            placeholderText: "music"
            onValueEdited: value => root.newName = value
        }

        TextFieldRow {
            id: classField

            label: Tr.tr("Window class")
            subtext: Tr.tr("Regex for the app's window class. Empty matches the name")
            placeholderText: "^([Ss]potify)$"
            onValueEdited: value => root.newClass = value
        }

        TextFieldRow {
            id: commandField

            label: Tr.tr("Command")
            subtext: Tr.tr("Launched when no matching window is open")
            placeholderText: "sonora"
            onValueEdited: value => root.newCommand = value
        }

        RowButton {
            last: true
            icon: "add"
            text: Tr.tr("Add workspace")
            disabled: !root.newName.trim() || !root.newCommand.trim()
            onClicked: root.add()
        }
    }
}
