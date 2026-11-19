import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.modules.aichat as AiChat
import qs.modules.bar as Bar
import qs.modules.dashboard as Dashboard
import qs.modules.launcher as Launcher
import qs.modules.notifications as Notifications
import qs.modules.osd as Osd
import qs.modules.session as Session
import qs.modules.sidebar as Sidebar
import qs.modules.utilities as Utilities
import qs.modules.bar.popouts as BarPopouts
import qs.modules.utilities.toasts as Toasts

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property Bar.BarWrapper bar
    required property real borderThickness

    // A bottom bar owns the bottom-right corner, so the right column flips: utilities top-right, notifications bottom-right
    readonly property bool rightFlipped: bar.side === "bottom"
    readonly property alias osd: osd
    readonly property alias osdWrapper: osdWrapper
    readonly property alias notifications: notifications
    readonly property alias session: session
    readonly property alias sessionWrapper: sessionWrapper
    readonly property alias launcher: launcher
    readonly property alias dashboard: dashboard
    readonly property alias popouts: popoutsWrapper.content
    readonly property alias popoutsWrapper: popoutsWrapper
    readonly property alias utilities: utilities
    readonly property alias toasts: toasts
    readonly property alias sidebar: sidebar
    readonly property alias aichat: aichat

    anchors.fill: parent
    anchors.margins: borderThickness
    // The bar's side is as deep as the bar; every other side is the border
    anchors.leftMargin: bar.side === "left" ? bar.thickness : borderThickness
    anchors.rightMargin: bar.side === "right" ? bar.thickness : borderThickness
    anchors.topMargin: bar.side === "top" ? bar.thickness : borderThickness
    anchors.bottomMargin: bar.side === "bottom" ? bar.thickness : borderThickness

    Item {
        id: osdWrapper

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: sessionWrapper.anchors.rightMargin + session.width * (1 - session.offsetScale)
        clip: sidebar.visible || session.visible

        implicitWidth: osd.implicitWidth * (1 - osd.offsetScale)
        implicitHeight: osd.implicitHeight

        Osd.Wrapper {
            id: osd

            screen: root.screen
            screenState: root.screenState
            sidebarOrSessionVisible: sidebar.visible || session.visible

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }

    Notifications.Wrapper {
        id: notifications

        screenState: root.screenState
        sidebarPanel: sidebar
        osdPanel: osdWrapper
        sessionPanel: sessionWrapper
        utilitiesPanel: utilities

        fromBottom: root.rightFlipped
        anchors.top: root.rightFlipped ? undefined : parent.top
        anchors.bottom: root.rightFlipped ? parent.bottom : undefined
        anchors.right: parent.right
    }

    Item {
        id: sessionWrapper

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: sidebar.width * (1 - sidebar.offsetScale)
        clip: sidebar.visible

        implicitWidth: session.implicitWidth * (1 - session.offsetScale)
        implicitHeight: session.implicitHeight

        Session.Wrapper {
            id: session

            screenState: root.screenState
            sidebarVisible: sidebar.visible

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }

    Launcher.Wrapper {
        id: launcher

        screen: root.screen
        screenState: root.screenState
        panels: root

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: launcher.floating ? undefined : parent.bottom
        y: launcher.floating ? Math.round(parent.height * 0.2) : 0
    }

    Dashboard.Wrapper {
        id: dashboard

        screenState: root.screenState

        // A top bar owns the top edge, so the dashboard rises from the bottom (the left edge is kept for the AI sidebar)
        fromBottom: root.bar.side === "top"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: fromBottom ? undefined : parent.top
        anchors.bottom: fromBottom ? parent.bottom : undefined
    }

    BarPopouts.ClipWrapper {
        id: popoutsWrapper

        screen: root.screen
        borderThickness: root.borderThickness
    }

    Utilities.Wrapper {
        id: utilities

        screenState: root.screenState
        sidebar: sidebar
        popouts: popoutsWrapper.content

        fromTop: root.rightFlipped
        anchors.top: root.rightFlipped ? parent.top : undefined
        anchors.bottom: root.rightFlipped ? undefined : parent.bottom
        anchors.right: parent.right
    }

    Toasts.Toasts {
        id: toasts

        anchors.bottom: root.rightFlipped ? undefined : sidebar.visible ? parent.bottom : utilities.top
        anchors.top: root.rightFlipped ? (sidebar.visible ? parent.top : utilities.bottom) : undefined
        anchors.right: sidebar.left
        anchors.margins: Tokens.padding.medium
    }

    Sidebar.Wrapper {
        id: sidebar

        screenState: root.screenState

        flipped: root.rightFlipped
        anchors.top: root.rightFlipped ? utilities.bottom : notifications.bottom
        anchors.bottom: root.rightFlipped ? notifications.top : utilities.top
        anchors.right: parent.right
        anchors.topMargin: root.rightFlipped ? 0 : -notifications.anchors.topMargin
        anchors.bottomMargin: root.rightFlipped ? -notifications.anchors.bottomMargin : 0
    }

    AiChat.Wrapper {
        id: aichat

        screenState: root.screenState

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
    }
}
