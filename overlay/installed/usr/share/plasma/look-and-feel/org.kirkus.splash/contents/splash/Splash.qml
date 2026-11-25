// kirkus startup splash (shown after login while Plasma loads).
//
// The kirkus bird, in exactly the spot and at exactly the size the login screen draws it. It starts at
// the login screen's faded opacity and brightens to full, so logging in looks like the bird lighting up.
import QtQuick

Rectangle {
    id: root
    color: "#16171b"                     // Ink

    // KSplash sets this as Plasma starts up; this splash doesn't need to react to it.
    property int stage

    Image {
        source: "images/mark.png"
        x: Math.floor(root.width / 2 - implicitWidth / 2)
        y: Math.floor(root.height / 2 - implicitHeight / 2) - 50
        opacity: 0.3                      // the login screen's opacity

        NumberAnimation on opacity {
            from: 0.3; to: 1.0
            duration: 1200
            easing.type: Easing.InOutSine
        }
    }
}
