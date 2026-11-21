// kirkus startup splash (shown after login while Plasma loads).
//
// Same as the boot splash: the kirkus lockup at exactly the spot every other screen draws it, so when
// you log in the password field simply disappears, and the K's chevron pulses until the desktop
// arrives.
import QtQuick

Rectangle {
    id: root
    color: "black"

    // KSplash sets this as Plasma starts up; this splash doesn't need to react to it.
    property int stage

    Image {
        id: lockup
        source: "images/lockup-base.png"
        x: Math.floor(root.width / 2 - implicitWidth / 2)
        y: Math.floor(root.height / 2 - implicitHeight / 2) - 50
    }

    // the chevron is its own layer, the same size and position as the lockup
    Image {
        source: "images/accent.png"
        x: lockup.x
        y: lockup.y

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            NumberAnimation { to: 0.65; duration: 1250; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 1250; easing.type: Easing.InOutSine }
        }
    }
}
