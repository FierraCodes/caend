import QtQuick
import qs.components

Item {
    id: root

    required property ScreenState screenState
    required property Item sidebarPanel
    property alias osdPanel: content.osdPanel
    property alias sessionPanel: content.sessionPanel
    property alias utilitiesPanel: content.utilitiesPanel
    property alias fromBottom: content.fromBottom

    visible: height > 0
    anchors.topMargin: fromBottom ? 0 : -5
    anchors.bottomMargin: fromBottom ? -5 : 0
    implicitWidth: Math.max(sidebarPanel.width, content.implicitWidth)
    implicitHeight: content.implicitHeight

    Content {
        id: content

        anchors.topMargin: -root.anchors.topMargin
        anchors.bottomMargin: -root.anchors.bottomMargin
        screenState: root.screenState
    }
}
