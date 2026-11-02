
import QtQuick

Rectangle {
    id: root

    property var card: null
    property bool faceUp: true

    width: 75
    height: 105
    radius: 7

    color: faceUp ? "white" : "dark blue"
    border.color: "white"
    border.width: 1

    function rankText(rank) {
        switch (rank) {
        case 14: return "A"
        case 13: return "K"
        case 12: return "Q"
        case 11: return "J"
        default: return String(rank)
        }
    }

    Text {
        anchors.centerIn: parent

        text: {
            if (!root.faceUp)
                return "$"

            if (!root.card)
                return ""

            return root.rankText(root.card.rank)
                   + root.card.suit
        }

        font.pixelSize: 27
        font.bold: true

        color: {
            if (!root.faceUp)
                return "white"

            if (root.card &&
                (root.card.suit === "♥" ||
                 root.card.suit === "♦"))
                return "red"

            return "black"
        }
    }
}
