import QtQuick

// Displays one hand and its chip stack. No player names.
Item {
    id: root

    property var player: null
    property bool human: false
    property bool reveal: false
    property bool drawEnabled: false
    property var selectedIndices: []
    property string chipPlacement: "below"  // above, below, right
    property string discardDirection: "down" // down, left, right

    property int cardWidth: 56
    property int cardHeight: 82
    property int cardSpacing: 5
    property int chipSize: 65
    property int chipGap: 9

    property string seatName: ""
    property int labelHeight: 24
    property bool activeTurn: false

    signal cardClicked(int cardIndex)

    readonly property int cardsWidth: 5 * cardWidth + 4 * cardSpacing
    readonly property int cardsHeight: cardHeight + 14
    readonly property int sideSpace: chipSize + chipGap

    implicitWidth: cardsWidth + (chipPlacement === "right" ? 2 * sideSpace : 0)
    implicitHeight: labelHeight + cardsHeight +
                    (chipPlacement === "right" ? 0 : sideSpace)
    width: implicitWidth
    height: implicitHeight

    Text {
        text: root.seatName

        x: cardsRow.x
        y: root.chipPlacement === "above"
           ? root.sideSpace : 0

        width: root.cardsWidth
        height: root.labelHeight

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        color: "white"
        font.pixelSize: 16
        font.bold: true
    }

    Row {
        id: cardsRow
        x: root.chipPlacement === "right" ? root.sideSpace : 0
        y: root.labelHeight +
           (root.chipPlacement === "above" ? root.sideSpace : 0)
        spacing: root.cardSpacing

        Repeater {
            model: root.player ? root.player.hand : []

            delegate: Item {
                id: cardSlot
                required property int index
                required property var modelData

                width: root.cardWidth
                height: root.cardsHeight


                PlayingCard {
                    id: cardVisual

                    width: root.cardWidth
                    height: root.cardHeight

                    card: cardSlot.modelData

                    faceUp: root.human ||
                            (root.reveal && root.player && !root.player.folded)

                    selectable: root.human && root.drawEnabled
                    drawHint: root.human && root.drawEnabled

                    selected: root.selectedIndices.includes(cardSlot.index)

                    // Human: selected cards move up as before.
                    // Computers: selected cards fade out without moving.
                    y: root.human ? (selected ? 0 : 12) : 0
                    x: 0

                    opacity: root.human || !selected ? 1 : 0

                    Behavior on y {
                        NumberAnimation { duration: 180 }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 250 }
                    }

                    onClicked: root.cardClicked(cardSlot.index)
                }

            }
        }
    }

    PokerChip {
        id: seatChip
        width: root.chipSize
        height: root.chipSize
        amount: root.player ? root.player.chips : 0

        x: root.chipPlacement === "right"
           ? cardsRow.x + root.cardsWidth + root.chipGap
           : cardsRow.x + (root.cardsWidth - width) / 2

        y: root.chipPlacement === "above" ? 0 :
           root.chipPlacement === "below"
           ? cardsRow.y + root.cardsHeight + root.chipGap
           : cardsRow.y + (root.cardsHeight - height) / 2
    }


    Rectangle {
        anchors.centerIn: seatChip

        width: seatChip.width + 8
        height: seatChip.height + 8
        radius: width / 2

        color: "transparent"
        border.color: "#FFD700"
        border.width: 3

        visible: root.activeTurn
        z: 1
    }

}
