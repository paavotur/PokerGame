
import QtQuick
import QtQuick.Controls

Button {
    id: root

    implicitWidth: 76
    implicitHeight: 76

    font.pixelSize: 14
    font.bold: true

    contentItem: Text {
        text: root.text
        font: root.font
        color: "black"

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
    }

    background: Rectangle {
        radius: width / 2

        color: root.down || root.hovered ? "lightgrey" : "white"

        border.color: "black"
        border.width: 2

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }
}
