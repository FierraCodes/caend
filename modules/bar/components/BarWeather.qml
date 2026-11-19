import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// end4's bar weather pill; click opens the dashboard weather tab
StyledRect {
    id: root

    required property ScreenState screenState

    readonly property bool horizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    // Weather is the last dashboard tab, after whichever of the others are enabled
    readonly property int weatherTab: [Config.dashboard.showDashboard, Config.dashboard.showMedia, Config.dashboard.showPerformance].filter(e => e).length

    implicitWidth: horizontal ? grid.implicitWidth + Tokens.padding.medium * 2 : Tokens.sizes.bar.innerWidth
    implicitHeight: horizontal ? Tokens.sizes.bar.innerWidth : grid.implicitHeight + Tokens.padding.medium * 2

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    StateLayer {
        radius: Tokens.rounding.full
        onClicked: {
            if (root.screenState.dashboard && root.screenState.dashboardTab === root.weatherTab) {
                root.screenState.dashboard = false;
            } else {
                root.screenState.dashboardTab = root.weatherTab;
                root.screenState.dashboard = true;
            }
        }
    }

    Grid {
        id: grid

        anchors.centerIn: parent
        flow: root.horizontal ? Grid.LeftToRight : Grid.TopToBottom
        rows: root.horizontal ? 1 : -1
        columns: root.horizontal ? -1 : 1
        spacing: Tokens.spacing.extraSmall
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        MaterialIcon {
            text: Weather.icon
            color: Colours.palette.m3primary
        }

        StyledText {
            text: Weather.temp
            font: Tokens.font.label.small
            color: Colours.palette.m3onSurface
        }
    }
}
