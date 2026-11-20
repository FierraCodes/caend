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
    property alias onLeft: content.onLeft
    property alias centred: content.centred
    property alias floating: content.floating
    // Heading the right column, it is as wide as the sidebar hanging below it
    property bool inColumn: true

    visible: height > 0
    anchors.topMargin: fromBottom || floating ? 0 : -5
    anchors.bottomMargin: fromBottom && !floating ? -5 : 0
    implicitWidth: inColumn ? Math.max(sidebarPanel.width, content.implicitWidth) : content.implicitWidth
    implicitHeight: content.implicitHeight

    Content {
        id: content

        anchors.topMargin: -root.anchors.topMargin
        anchors.bottomMargin: -root.anchors.bottomMargin
        screenState: root.screenState
    }
}
