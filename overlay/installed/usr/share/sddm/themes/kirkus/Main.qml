// kirkus login screen for SDDM (Qt 6).
//
// The kirkus lockup is drawn with exactly the same arithmetic as the Plymouth boot splash, the GRUB
// menu background and the Plasma startup splash, so from power-on to desktop it never moves. Under
// it, the password field, which carries your name. Clock at the top, session, user and power
// controls along the bottom, so nothing competes with the centre. Colours are the brand palette:
// navy #0b1020, blue #5590b4, cream #fff8ec, slate #aeb6c8.
import QtQuick

Rectangle {
    id: root
    width: 1440
    height: 900
    color: "black"

    // ---- shared layout (same numbers as kirkus.script and the GRUB background) ----

    // ---- state ----
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool busy: false
    property string errorText: ""
    property date now: new Date()
    readonly property bool capsOn: (typeof keyboard !== "undefined") && keyboard.capsLock

    readonly property color textColor: "#fff8ec"      // cream
    readonly property color dimColor: "#8a92a4"       // slate, dimmed
    readonly property color accent: "#5590b4"         // brand blue
    readonly property color accentHover: "#6aa3c6"
    // the wordmark's typeface; installed by kirk-install-fonts. If it's missing, Qt substitutes a
    // standard sans automatically.
    readonly property string fontFamily: "Space Grotesk"

    // The models can't be indexed directly, so mirror the bits we need through invisible repeaters.
    Repeater {
        id: users
        model: userModel
        delegate: Item {
            visible: false
            property string login: model.name
            property string fullName: model.realName
        }
    }
    Repeater {
        id: sessions
        model: sessionModel
        delegate: Item {
            visible: false
            property string label: model.name
        }
    }

    function userLogin() {
        var u = users.itemAt(userIndex);
        return u ? u.login : userModel.lastUser;
    }
    function userLabel() {
        var u = users.itemAt(userIndex);
        if (!u) return userModel.lastUser;
        return u.fullName !== "" ? u.fullName : u.login;
    }
    function sessionLabel() {
        var s = sessions.itemAt(sessionIndex);
        return s ? s.label : "";
    }
    function doLogin() {
        if (busy) return;
        errorText = "";
        busy = true;
        sddm.login(userLogin(), password.text, sessionIndex);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false;
            root.errorText = "Incorrect password";
            password.selectAll();
            shake.start();
            password.forceActiveFocus();
        }
        function onLoginSucceeded() {
            root.errorText = "";
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // ---- clock, top centre ----
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 44
        text: Qt.formatDate(root.now, "dddd, MMMM d") + "     "
              + Qt.formatTime(root.now, Qt.locale().timeFormat(Locale.ShortFormat))
        color: root.dimColor
        font.family: root.fontFamily
        font.pixelSize: 15
    }

    // ---- the lockup: identical to the boot splash ----
    Image {
        id: lockup
        source: "lockup.png"
        x: Math.floor(root.width / 2 - implicitWidth / 2)
        y: Math.floor(root.height / 2 - implicitHeight / 2) - 50
    }

    // ---- login form, under the lockup ----
    Column {
        id: form
        anchors.horizontalCenter: parent.horizontalCenter
        y: lockup.y + lockup.implicitHeight + 84
        spacing: 12
        opacity: 0

        NumberAnimation on opacity {
            from: 0
            to: 1
            duration: 450
            easing.type: Easing.OutCubic
        }


        // password, as a pill with a go button inside
        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: 280
            height: 42
            radius: 21
            color: "#0b1020"                // navy
            border.width: 1
            border.color: password.activeFocus ? root.accent : "#232a3d"
            transform: Translate { id: shakeOffset; x: 0 }

            Behavior on border.color { ColorAnimation { duration: 150 } }

            SequentialAnimation {
                id: shake
                NumberAnimation { target: shakeOffset; property: "x"; to: -10; duration: 50 }
                NumberAnimation { target: shakeOffset; property: "x"; to: 10; duration: 70 }
                NumberAnimation { target: shakeOffset; property: "x"; to: -6; duration: 60 }
                NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 50 }
            }

            TextInput {
                id: password
                anchors.left: parent.left
                anchors.right: go.left
                anchors.leftMargin: 18
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                passwordCharacter: "●"
                color: root.textColor
                selectionColor: root.accent
                font.family: root.fontFamily
                font.pixelSize: 15
                clip: true
                focus: true
                enabled: !root.busy
                Keys.onReturnPressed: root.doLogin()
                Keys.onEnterPressed: root.doLogin()
                onTextChanged: if (root.errorText !== "") root.errorText = ""

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Password for " + (users.count > 0 ? root.userLabel() : userModel.lastUser)
                    color: "#5f677a"
                    font: password.font
                    visible: password.text.length === 0
                }
            }

            Rectangle {
                id: go
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 16
                color: goArea.containsMouse ? root.accentHover : root.accent
                opacity: password.text.length > 0 && !root.busy ? 1 : 0.35

                Text {
                    anchors.centerIn: parent
                    text: "→"
                    color: root.textColor
                    font.family: root.fontFamily
                    font.pixelSize: 17
                }
                MouseArea {
                    id: goArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.doLogin()
                }
            }
        }

        // wrong password, or a caps lock warning
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 20
            text: root.errorText !== "" ? root.errorText : (root.capsOn ? "Caps Lock is on" : "")
            color: root.errorText !== "" ? "#ff8a80" : root.dimColor
            font.family: root.fontFamily
            font.pixelSize: 13
        }
    }

    // ---- bottom bar: session (and user, if several) on the left, power on the right ----
    // (inline components can't see the ids in this file, so no root.* references in here)
    component Action: Text {
        id: action
        signal activated()
        color: actionArea.containsMouse ? "#fff8ec" : "#8a92a4"
        font.family: "Space Grotesk"
        font.pixelSize: 13
        MouseArea {
            id: actionArea
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.activated()
        }
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.bottomMargin: 22
        height: 24

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 24
            Action {
                visible: sessions.count > 0
                text: root.sessionLabel() + (sessions.count > 1 ? "  \u203A" : "")
                onActivated: if (sessions.count > 1) root.sessionIndex = (root.sessionIndex + 1) % sessions.count
            }
            Action {
                visible: users.count > 1
                text: "Switch User  \u203A"
                onActivated: {
                    root.userIndex = (root.userIndex + 1) % users.count;
                    password.text = "";
                    root.errorText = "";
                    password.forceActiveFocus();
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 24
            Action { text: "Sleep"; visible: sddm.canSuspend; onActivated: sddm.suspend() }
            Action { text: "Restart"; visible: sddm.canReboot; onActivated: sddm.reboot() }
            Action { text: "Shut Down"; visible: sddm.canPowerOff; onActivated: sddm.powerOff() }
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}
