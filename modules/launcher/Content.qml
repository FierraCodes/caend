pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.launcher.services

Item {
    id: root

    required property ScreenState screenState
    required property var panels
    required property real maxHeight
    property bool floating // Spotlight layout: search on top, results below

    readonly property int padding: Tokens.padding.large
    readonly property int rounding: Tokens.rounding.extraLarge

    implicitWidth: listWrapper.width + padding * 2
    implicitHeight: search.height + listWrapper.height + padding + (floating ? search.anchors.topMargin : search.anchors.bottomMargin)

    Item {
        id: listWrapper

        implicitWidth: list.width
        implicitHeight: list.height + root.padding

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: root.floating ? undefined : search.top
        anchors.bottomMargin: root.padding
        anchors.top: root.floating ? search.bottom : undefined
        anchors.topMargin: root.padding

        ContentList {
            id: list

            content: root
            screenState: root.screenState
            panels: root.panels
            maxHeight: root.maxHeight - search.implicitHeight - root.padding * 3
            search: search
            padding: root.padding
            rounding: root.rounding
        }
    }

    SearchBar {
        id: search

        objectName: "launcherSearch"

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: root.floating ? undefined : parent.bottom
        anchors.top: root.floating ? parent.top : undefined
        anchors.margins: root.padding
        anchors.bottomMargin: root.floating ? root.padding : CUtils.clamp(root.padding - Config.border.thickness, 0, root.padding)

        topPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)
        bottomPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)

        placeholderText: Tr.tr("Search, calculate or run (\"%1\" for actions)").arg(GlobalConfig.launcher.actionPrefix)

        onAccepted: {
            const currentItem = list.currentList?.currentItem;
            if (currentItem) {
                if (list.showWallpapers) {
                    if (Colours.scheme === "dynamic" && currentItem.modelData.path !== Wallpapers.actualCurrent)
                        Wallpapers.previewColourLock = true;
                    Wallpapers.setWallpaper(currentItem.modelData.path);
                    root.screenState.launcher = false;
                } else if (text.startsWith(`${GlobalConfig.launcher.actionPrefix}calc `)) {
                    currentItem.onClicked();
                } else {
                    currentItem.modelData?.onClicked(list.currentList);
                }
            }
        }

        Keys.onUpPressed: list.currentList?.decrementCurrentIndex()
        Keys.onDownPressed: list.currentList?.incrementCurrentIndex()

        Keys.onEscapePressed: root.screenState.launcher = false

        Keys.onPressed: event => {
            // Shift+Delete removes the selected clipboard entry from history
            if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier) && text.startsWith(GlobalConfig.launcher.clipboardPrefix)) {
                const entry = list.currentList?.currentItem?.modelData?.entry;
                if (entry) {
                    Spotlight.deleteClipboard(entry);
                    event.accepted = true;
                    return;
                }
            }

            if (!GlobalConfig.launcher.vimKeybinds)
                return;

            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                    list.currentList?.incrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                    list.currentList?.decrementCurrentIndex();
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Tab) {
                list.currentList?.incrementCurrentIndex();
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                list.currentList?.decrementCurrentIndex();
                event.accepted = true;
            }
        }

        Component.onCompleted: {
            forceActiveFocus();
            if (root.screenState.launcherQuery)
                text = root.screenState.launcherQuery;
        }

        Connections {
            function onLauncherChanged(): void {
                if (!root.screenState.launcher) {
                    search.text = "";
                    root.screenState.launcherQuery = "";
                }
            }

            function onLauncherQueryChanged(): void {
                if (root.screenState.launcherQuery)
                    search.text = root.screenState.launcherQuery;
            }

            function onSessionChanged(): void {
                if (!root.screenState.session)
                    search.forceActiveFocus();
            }

            target: root.screenState
        }
    }
}
