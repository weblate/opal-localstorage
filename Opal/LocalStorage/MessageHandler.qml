//@ This file is part of opal-localstorage.
//@ https://github.com/Pretty-SFOS/opal-localstorage
//@ SPDX-License-Identifier: GPL-3.0-or-later
//@ SPDX-FileCopyrightText: 2018-2026 Mirian Margiani

import QtQuick 2.0
import Sailfish.Silica 1.0
import "private"
import "."

/*!
    \qmltype MessageHandler
    \inqmlmodule Opal.LocalStorage
    \since version 0.2.0

    \brief Handle database errors and other signals.

    The \c MessageHandler serves as a gateway for signals sent from
    your database implementation that should be handled in the GUI.

    By default, it automatically shows popups when fatal database
    errors occur. For example, when the loaded database has an
    unexpected version or when migration fails.

    \section2 Usage

    To handling message with the message handler, add it to your main
    QML file.

    \qml
    // ...
    import Opal.LocalStorage 1.0 as L

    ApplicationWindow {
        // ...

        L.MessageHandler {}
    }
    \endqml

    \section2 Custom signals

    Custom events can be sent from your database script using the
    \l Database::notify and \l Database::notifyEnd functions.

    These events will trigger the \l userSignalReceived signal which
    you can handle:

    \qml
    MessageHandler {
        onUserSignalReceived: {
            switch (event) {
            case "my-event":
                showOverlay(handle, "You won!",
                            "You won the lottery. Wow.")
                break
            case "end":
                hideOverlay(handle)
                break
            default:
                console.warn("bug: unknown event received:", event, JSON.stringify(data))
                break
        }
    }
    \endqml

    \sa LocalStorage, Database
*/
Item {
    id: root

    /*!
      This property enables dismissible overlays for all storage signals.

      \defaultValue false
    */
    property bool debugMode: false

    /*!
      This signal is triggered when the storage backend sends an event.

      See \l MessageHandler for an example how to handle this signal.

      See \l Database::notify for a description of the parameters.

      \sa MessageHandler, Database::notify, Database::notifyEnd
    */
    signal userSignalReceived(var event, var handle, var busy, var data)

    // Registry of all currently visible overlays:
    // {event: overlay object}
    property var __events: ({})

    // All user events are registered here:
    // {event: 1}
    // This is used to determine whether an "end" event should
    // be handled internally or by the user.
    property var __userEvents: ({})

    // Logging category prefix.
    readonly property string _lc: "[Opal.LocalStorage] MessageHandler:"

    // Internal signal called by the storage script.
    signal __databaseSignalReceived(var event, var handle, var busy, var data)

    /*!
      This function shows a blocking overlay for an event.

      The overlay will block all user interaction with the app
      until it is hidden again using the \l hideOverlay function.

      The event's \a handle must be provided so the overlay can
      be hidden again. Subsequent calls to this function will
      overlay overlays over laying overlays.

      While an overlay with a certain \a handle is already visible,
      it will not be shown again.

      Define the strings \a title and \a description to include
      content in overlay. If \a busy is \c true, the overlay will
      include a busy spinner.

      Optionally add detailed pre-formatted information in the
      \a smallprint string. This may be used to show details for
      bug reporting.

      \sa hideOverlay
    */
    function showOverlay(handle, title, description, busy, smallprint) {
        var obj = overlayComponent.createObject(
            __silica_applicationwindow_instance,
            {text: title, hintText: description, smallprint: smallprint || "", busy: busy})

        if (obj === null) {
            console.error(_lc, "failed to show status overlay!")
        } else {
            obj.show()
        }

        if (__events.hasOwnProperty(handle)) {
            console.warn(_lc, "replacing event with handle", handle)
            _hideOverlay(handle)
        }

        __events[handle] = obj
    }

    /*!
      This function hides an overlay for an event.

      Call this to hide the overlay for an event with
      the handle \a handle that was previously shown using
      \l showOverlay.

      \sa hideOverlay
    */
    function hideOverlay(handle) {
        if (__events.hasOwnProperty(handle)) {
            __events[handle].hide(true)
            delete __events[handle]
        }
    }

    /*!
      Mark an overlay as dismissible.

      By default, overlays cannot be dismissed by the user. They are
      only hidden if the implementation explicitly calls \l hideOverlay
      for a specific overlay.

      Call \l allowDismissOverlay to allow the user to dismiss an
      overlay manually. This is useful for showing messages for errors
      that still allow the app to function properly.
    */
    function allowDismissOverlay(handle) {
        if (__events.hasOwnProperty(handle)) {
            __events[handle].allowDismiss = true
            __events[handle].dismissed.connect(function(){
                if (__events.hasOwnProperty(handle)) {
                    delete __events[handle]
                }
            })
        }
    }

    // Register the internal event signal with the storage script.
    function _register(force) {
        if (!force && !!LocalStorage._DB_STATUS_SIGNAL) {
            console.warn(_lc, "database status signal already set!")
        } else {
            console.log(_lc, "database event handler installed")
            LocalStorage._DB_STATUS_SIGNAL = __databaseSignalReceived
        }
    }

    visible: false
    parent: __silica_applicationwindow_instance

    on__DatabaseSignalReceived: {
        function _show(title, hint, smallprint, dismissible) {
            showOverlay(handle, title, hint, busy, smallprint)

            if (!!dismissible) {
                allowDismissOverlay(handle)
            }
        }

        if (/^user-/.test(handle)) {
            __userEvents[handle] = 1
            userSignalReceived(event, handle, busy, data)

            if (debugMode) {
                _show(event,
                      "user signal",
                      "Event: %1<br><br>Data:<br><pre>%2</pre>".arg(event).arg(JSON.stringify(data, 2, 2)),
                      true
                )
            }

            return
        }

        switch (event) {
        case "end":
            if (!__userEvents.hasOwnProperty(handle)) {
                hideOverlay(handle)
            }
            break
        case "init":
        case "upgrade":
            // these events should be quick and don't need an overlay
            break
        case "query-failed":
            if (!!data.notify || debugMode) {
                _show(qsTranslate("Opal.LocalStorage", "Database query failed"),
                      qsTranslate("Opal.LocalStorage", "An error occurred while accessing " +
                                  "the database.") + (!!data.fatal ? " " +
                          qsTranslate("Opal.LocalStorage", "Try restarting the app.") + " " +
                          qsTranslate("Opal.LocalStorage", "Please report this issue if it happens again.") : ""),
                      "Exception: %1<br><br>Query: <pre>%2</pre><br><br>Values: %3<br>Read-only: %4<br><br>Stack:<br>%5".arg(
                          data.exception).arg(
                          data.query).arg(
                          JSON.stringify(data.values)).arg(
                          !!data.readOnly ? "true" : "false").arg(
                          data.exception.stack.split('\n').join('<br><br>')),
                      !data.fatal || debugMode
                )
            }
            break
        case "upgrade-failed":
            _show(qsTranslate("Opal.LocalStorage", "Database upgrade failed"),
                  qsTranslate("Opal.LocalStorage",
                              "An error occurred while upgrading " +
                              "the database from version %1 to version %2. " +
                              "Please report this issue.").arg(data.from).arg(data.to),
                  "%1<br><br>Stack:<br>%2".arg(data.exception).arg(
                      data.exception.stack.split('\n').join('<br><br>')),
                  false || debugMode
            )
            break
        case "invalid-version":
            _show(qsTranslate("Opal.LocalStorage", "Invalid database version"),
                  qsTranslate("Opal.LocalStorage",
                              "The app cannot start because " +
                              "the database has version %1 " +
                              "but only version %2 is supported.").
                  arg(data.got).arg(data.expected),
                  "",
                  false || debugMode)
            break
        case "maintenance":
            _show(qsTranslate("Opal.LocalStorage", "Database Maintenance"),
                  qsTranslate("Opal.LocalStorage", "Please be patient and allow up to 30 seconds for this."),
                  "",
                  false || debugMode)
            break
        default:
            _show(qsTranslate("Opal.LocalStorage", "Database issue"),
                  qsTranslate("Opal.LocalStorage",
                              "An unexpected issue occurred in the database. " +
                              "Try restarting the app."),
                  "Event: %1<br><br>Data:<br><pre>%2</pre>".arg(event).arg(JSON.stringify(data, 2, 2)),
                  false || debugMode
            )
            break
        }
    }

    Component {
        id: overlayComponent
        BlockingOverlay {}
    }

    Component.onCompleted: {
        _register()
    }
}
