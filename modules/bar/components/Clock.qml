pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3tertiary
    readonly property int padding: Config.bar.clock.background ? Tokens.padding.medium : Tokens.padding.extraSmall
    readonly property var font: Tokens.font.body.builders.small.scale(1.1)
    readonly property bool horizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    // Stacked lines overlap a little so the digits sit tight
    readonly property real stackSpacing: -4

    function fontFor(text: string, metricWidth: int): font {
        // We don't count seconds for the max width because it changes too often
        const scale = text === "11" ? 1.15 : Math.min(1.05, Math.max(hourMetrics.width, minMetrics.width) / metricWidth);
        return root.font.width(scale * 100).letterSpacing(scale).build();
    }

    implicitWidth: horizontal ? layout.implicitWidth + root.padding * 2 : Tokens.sizes.bar.innerWidth
    implicitHeight: horizontal ? Math.max(Tokens.sizes.bar.innerWidth, layout.implicitHeight) : layout.implicitHeight + root.padding * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Config.bar.clock.background ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    GridLayout {
        id: layout

        anchors.centerIn: parent
        flow: root.horizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
        rowSpacing: Tokens.spacing.extraSmall
        columnSpacing: Tokens.spacing.extraSmall

        Loader {
            Layout.alignment: Qt.AlignCenter
            asynchronous: true
            active: Config.bar.clock.showIcon
            visible: active

            sourceComponent: MaterialIcon {
                text: "calendar_month"
                color: root.colour
            }
        }

        Loader {
            Layout.alignment: Qt.AlignCenter
            asynchronous: true
            active: Config.bar.clock.showDate
            visible: active

            sourceComponent: GridLayout {
                flow: layout.flow
                rowSpacing: layout.rowSpacing - 4
                columnSpacing: layout.columnSpacing

                StyledText {
                    Layout.alignment: Qt.AlignCenter
                    text: Time.format("ddd")
                    font: Tokens.font.body.builders.small.scale(0.9).build()
                    color: root.colour
                }

                StyledText {
                    Layout.alignment: Qt.AlignCenter
                    text: Time.format("d")
                    font: root.font.scale(1.1).build()
                    color: root.colour
                }

                StyledRect {
                    Layout.fillWidth: !root.horizontal
                    Layout.fillHeight: root.horizontal
                    Layout.leftMargin: root.horizontal ? Tokens.padding.extraSmall / 2 : -Tokens.padding.extraSmall
                    Layout.rightMargin: root.horizontal ? Tokens.padding.extraSmall / 2 : -Tokens.padding.extraSmall
                    Layout.topMargin: root.horizontal ? 0 : 4
                    Layout.bottomMargin: root.horizontal ? 0 : Tokens.padding.extraSmall / 2
                    implicitWidth: 1
                    implicitHeight: 1
                    color: Colours.palette.m3outlineVariant
                }
            }
        }

        // Hour over minute (over seconds) on every bar orientation
        ColumnLayout {
            Layout.alignment: Qt.AlignCenter
            spacing: root.stackSpacing

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Time.hourStr
                font: root.fontFor(text, hourMetrics.width)
                color: root.colour

                TextMetrics {
                    id: hourMetrics

                    font: root.font.build()
                    text: Time.hourStr
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Time.minuteStr
                font: root.fontFor(text, minMetrics.width)
                color: root.colour

                TextMetrics {
                    id: minMetrics

                    font: root.font.build()
                    text: Time.minuteStr
                }
            }

            Loader {
                Layout.alignment: Qt.AlignHCenter
                asynchronous: true
                active: Config.bar.clock.showSeconds
                visible: active

                sourceComponent: StyledText {
                    text: Time.format("ss")
                    font: root.fontFor(text, secMetrics.width)
                    color: root.colour

                    TextMetrics {
                        id: secMetrics

                        font: root.font.build()
                        text: Time.format("ss")
                    }
                }
            }
        }

        Loader {
            Layout.topMargin: root.horizontal ? 0 : -layout.rowSpacing + root.stackSpacing
            Layout.alignment: Qt.AlignCenter
            asynchronous: true
            active: Units.twelveHourClock
            visible: active

            sourceComponent: StyledText {
                text: Time.amPmStr.toLowerCase()
                font: Tokens.font.body.builders.small.scale(0.9).build()
                color: root.colour
            }
        }
    }
}
