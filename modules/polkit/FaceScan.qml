pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import M3Shapes
import Caelestia.Config
import qs.components
import qs.services

// Face ID-style status for the polkit dialog: brackets breathe and a line sweeps while the camera looks,
// the backdrop morphs into a circle with a tick on success, and everything shakes red when the face isn't recognised
Item {
    id: root

    enum State {
        Scanning,
        Failed,
        Success
    }

    property int status: FaceScan.Scanning

    readonly property bool scanning: status === FaceScan.Scanning
    readonly property real box: 46 // Bracket square
    readonly property color fg: status === FaceScan.Success ? Colours.palette.m3onPrimary : status === FaceScan.Failed ? Colours.palette.m3onErrorContainer : Colours.palette.m3onPrimaryContainer

    implicitWidth: 84
    implicitHeight: 84

    onStatusChanged: {
        if (status === FaceScan.Failed)
            shake.restart();
        else if (status === FaceScan.Success)
            pop.restart();
    }

    transform: Translate {
        id: shakeOffset
    }

    SequentialAnimation {
        id: shake

        NumberAnimation {
            target: shakeOffset
            property: "x"
            to: -10
            duration: 55
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: shakeOffset
            property: "x"
            to: 8
            duration: 55
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: shakeOffset
            property: "x"
            to: -6
            duration: 55
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: shakeOffset
            property: "x"
            to: 4
            duration: 55
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: shakeOffset
            property: "x"
            to: 0
            duration: 55
            easing.type: Easing.OutQuad
        }
    }

    SequentialAnimation {
        id: pop

        Anim {
            target: root
            property: "scale"
            to: 1.12
            type: Anim.FastSpatial
        }
        Anim {
            target: root
            property: "scale"
            to: 1
            type: Anim.DefaultSpatial
        }
    }

    MaterialShape {
        id: backdrop

        anchors.centerIn: parent
        implicitSize: root.implicitWidth
        shape: root.status === FaceScan.Success ? MaterialShape.Circle : root.status === FaceScan.Failed ? MaterialShape.Cookie4Sided : MaterialShape.Cookie9Sided
        color: root.status === FaceScan.Success ? Colours.palette.m3primary : root.status === FaceScan.Failed ? Colours.palette.m3errorContainer : Colours.palette.m3primaryContainer
        animationEasing: Tokens.anim.expressiveDefaultSpatial
        animationDuration: Tokens.anim.durations.expressiveDefaultSpatial * Tokens.anim.durations.scale

        RotationAnimation on rotation {
            running: root.scanning
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 9000
        }

        Behavior on color {
            CAnim {}
        }
    }

    // Four rounded corner brackets: one top-left corner, rotated into place
    Item {
        id: brackets

        anchors.centerIn: parent
        width: root.box
        height: root.box
        opacity: root.status === FaceScan.Success ? 0 : 1
        scale: root.status === FaceScan.Success ? 1.35 : 1

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {}
        }

        // Breathing lives on its own item so it doesn't fight the success scale above
        Item {
            anchors.fill: parent

            SequentialAnimation on scale {
                running: root.scanning
                alwaysRunToEnd: true
                loops: Animation.Infinite

                NumberAnimation {
                    to: 0.88
                    duration: 700
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 1
                    duration: 700
                    easing.type: Easing.InOutSine
                }
            }

            Repeater {
                model: 4

                Item {
                    required property int index

                    anchors.fill: parent
                    rotation: index * 90

                    Shape {
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: root.fg
                            strokeWidth: 3
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            startX: 1.5
                            startY: 13

                            PathLine {
                                x: 1.5
                                y: 1.5 + 7
                            }
                            PathArc {
                                x: 1.5 + 7
                                y: 1.5
                                radiusX: 7
                                radiusY: 7
                            }
                            PathLine {
                                x: 13
                                y: 1.5
                            }
                        }
                    }
                }
            }
        }

        // Sweeping scan line
        Rectangle {
            x: 8
            width: parent.width - 16
            height: 2
            radius: 1
            color: root.fg
            opacity: root.scanning ? 0.7 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }

            SequentialAnimation on y {
                running: root.scanning
                loops: Animation.Infinite

                NumberAnimation {
                    from: 6
                    to: root.box - 8
                    duration: 1100
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: root.box - 8
                    to: 6
                    duration: 1100
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    MaterialIcon {
        anchors.centerIn: parent
        animate: true
        text: root.status === FaceScan.Success ? "check" : root.status === FaceScan.Failed ? "password" : "face"
        color: root.fg
        fill: root.status === FaceScan.Success ? 1 : 0
        fontStyle: root.status === FaceScan.Success ? Tokens.font.icon.large : Tokens.font.icon.medium
    }
}
