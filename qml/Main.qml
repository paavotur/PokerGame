import Felgo
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "GameEngine.js" as GameEngine
import "PokerHandEvaluator.js" as PokerHands

App {
    id: root
    width: 900
    height: 600

    property var playerHand: []
    property var computerHand: []
    property var remainingDeck: []
    property var selectedIndices: []
    property bool drawAvailable: true
    property int playerDrawCount: 0
    property int computerDrawCount: 0


    property string playerHandName: ""
    property string computerHandName: ""
    property string winnerText: ""

    function dealCards() {
        const result = GameEngine.startHand()
        playerHand = result.playerHand
        computerHand = result.computerHand
        remainingDeck = result.remainingDeck
        selectedIndices = []
        drawAvailable = true
        playerDrawCount = 0
        computerDrawCount = 0
    }

    function toggleCard(index) {
        if (!drawAvailable)
            return

        const nextSelection = selectedIndices.slice()
        const selectedPosition = nextSelection.indexOf(index)

        if (selectedPosition === -1)
            nextSelection.push(index)
        else
            nextSelection.splice(selectedPosition, 1)

        // Reassigning triggers QML bindings to update.
        selectedIndices = nextSelection
    }

    function drawCards() {
        if (!drawAvailable)
            return

        // Both players draw from the same remaining deck.
        const playerNewHandAndRemainingDeck = GameEngine.exchangeCards(
            playerHand, selectedIndices, remainingDeck)
        const computerIndices = GameEngine.randomExchangeIndices()
        const computerNewHandAndRemainingDeck = GameEngine.exchangeCards(
            computerHand, computerIndices, playerNewHandAndRemainingDeck.remainingDeck)

        playerHand = playerNewHandAndRemainingDeck.hand
        computerHand = computerNewHandAndRemainingDeck.hand
        remainingDeck = computerNewHandAndRemainingDeck.remainingDeck
        playerDrawCount = selectedIndices.length
        computerDrawCount = computerIndices.length
        selectedIndices = []
        drawAvailable = false


        // Evaluate both hands
        const playerResult = PokerHands.evaluateHand(playerHand)
        const computerResult = PokerHands.evaluateHand(computerHand)

        playerHandName = playerResult.name
        computerHandName = computerResult.name

        const winner = PokerHands.compareHands(
            playerHand, computerHand
        )

        if (winner === 1)
            winnerText = "YOU WIN!"
        else if (winner === -1)
            winnerText = "COMPUTER WINS!"
        else
            winnerText = "IT'S A TIE!"

    }

    Component.onCompleted: dealCards()

    Rectangle {
        anchors.fill: parent
        color: "darkgreen"

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16

            Text {
                text: "COMPUTER: " +  root.computerHandName
                color: "white"
                font.pixelSize: 22
                Layout.alignment: Qt.AlignHCenter
            }

            Row {
                spacing: 8
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: root.computerHand
                    delegate: PlayingCard {
                        required property var modelData
                        card: modelData
                        faceUp: !root.drawAvailable
                        selectable: false
                    }
                }
            }

            Text {
                text: root.drawAvailable ? "Computer waits to draw" :
                      "Computer changed " + root.computerDrawCount + " cards"
                color: "white"
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "POT: 20"
                color: "yellow"
                font.pixelSize: 25
                Layout.alignment: Qt.AlignHCenter
            }


            Text {
                text: root.winnerText
                visible: text !== ""

                color: "yellow"
                font.pixelSize: 26
                font.bold: true

                Layout.alignment: Qt.AlignHCenter
            }


            Row {
                spacing: 8
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: root.playerHand

                    delegate: Item {
                        id: cardSlot
                        required property int index
                        required property var modelData

                        width: 75
                        height: 120

                        PlayingCard {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: selected ? 0 : 12
                            card: cardSlot.modelData
                            selected: root.selectedIndices.indexOf(cardSlot.index) !== -1
                            selectable: root.drawAvailable
                            onClicked: root.toggleCard(cardSlot.index)

                            Behavior on y {
                                NumberAnimation { duration: 120 }
                            }
                        }
                    }
                }
            }

            Text {
                text: root.drawAvailable
                      ? "Select 0-5 cards to replace (" + root.selectedIndices.length + " selected)"
                      : "You changed " + root.playerDrawCount + " cards"
                color: "white"
                Layout.alignment: Qt.AlignHCenter
            }


            Text {
                text: "Player: " + root.playerHandName
                visible: !root.drawAvailable
                color: "white"
                font.pixelSize: 22
                Layout.alignment: Qt.AlignHCenter
            }


            RowLayout {
                spacing: 16
                Layout.alignment: Qt.AlignHCenter

                Button {
                    text: "Draw"
                    enabled: root.drawAvailable
                    onClicked: root.drawCards()
                }

                Button {
                    text: "Deal New Hand"
                    onClicked: root.dealCards()
                }
            }
        }
    }
}
