//@ This file is part of opal-localstorage.
//@ https://github.com/Pretty-SFOS/opal-localstorage
//@ SPDX-License-Identifier: GPL-3.0-or-later
//@ SPDX-FileCopyrightText: 2018-2026 Mirian Margiani

import QtQuick 2.0
import Sailfish.Silica 1.0
import "."

Rectangle {
    id: root
    objectName: "BlockingOverlay"

    property alias text: label.text
    property alias hintText: label.hintText
    property alias smallprint: label.smallprintText
    property alias busy: label.running
    property bool allowDismiss: false
    property bool _destroyAfterHiding: false

    signal dismissed

    readonly property bool _portrait: (__silica_applicationwindow_instance.orientation
                                      & Orientation.PortraitMask) !== 0

    function show() {
        state = "shown"
    }

    function hide(destroyAfter) {
        state = "hidden"
        _destroyAfterHiding = destroyAfter
    }

    function dismiss() {
        // may be called even if allowDismiss is false to
        // support dismissing after custom actions
        hide(true)
        dismissed()
    }

    state: "hidden"
    visible: false
    opacity: 0.0
    parent: __silica_applicationwindow_instance.contentItem
    rotation: __silica_applicationwindow_instance._rotatingItem.rotation
    color: Theme.highlightDimmerColor
    anchors.centerIn: parent
    width: _portrait ? parent.width : parent.height
    height: _portrait ? parent.height : parent.width

    SilicaFlickable {
        id: flick
        anchors.fill: parent
        anchors.centerIn: parent
        contentHeight: column.height + Theme.horizontalPageMargin
        contentWidth: root.width

        Loader {
            active: allowDismiss
            sourceComponent: Component {
                PullDownMenu {
                    MenuItem {
                        text: qsTranslate("Opal.LocalStorage", "Dismiss", "as in “hide (dismiss) this popup message”")
                        onClicked: dismiss()
                    }
                }
            }
        }

        Loader {
            active: allowDismiss
            sourceComponent: Component {
                PushUpMenu {
                    MenuItem {
                        text: qsTranslate("Opal.LocalStorage", "Dismiss", "as in “hide (dismiss) this popup message”")
                        onClicked: dismiss()
                    }
                }
            }
        }

        VerticalScrollDecorator { flickable: flick }

        Column {
            id: column

            height: childrenRect.height
            width: parent.width

            Item {
                width: parent.width
                height: body.height > root.height ?
                    3 * Theme.horizontalPageMargin : (root.height-body.height)/2
            }

            Column {
                id: body

                width: parent.width
                height: childrenRect.height
                spacing: Theme.paddingLarge

                ExtendedBusyLabel {
                    id: label
                    running: root.visible
                }
            }
        }
    }

    states: [
        State {
            name: "shown"
            PropertyChanges{
                target: root
                visible: true
            }
            PropertyChanges {
                target: root
                opacity: 1.0
            }
        },
        State {
            name:"hidden"
            PropertyChanges {
                target: root
                opacity: 0.0
            }
            PropertyChanges {
                target: root
                visible: false
            }
        }
    ]

    transitions: [
        Transition {
            to: "shown"
            SequentialAnimation {
                NumberAnimation {
                    target: root
                    property: "visible"
                    duration: 0
                }
               NumberAnimation {
                   target: root
                   property: "opacity"
                   duration: 200
                   easing.type: Easing.InOutQuad
               }
            }
        },
        Transition {
            to: "hidden"
            SequentialAnimation {
               NumberAnimation {
                   target: root
                   property: "opacity"
                   duration: 300
                   easing.type: Easing.InOutQuad
               }
               NumberAnimation {
                   target: root
                   property: "visible"
                   duration: 0
               }
               ScriptAction {
                   script: {
                       if (root._destroyAfterHiding) {
                           root.destroy()
                       }
                   }
               }
            }
        }
    ]
}
