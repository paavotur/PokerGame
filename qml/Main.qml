import Felgo
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "PokerAI.js" as PokerAI
import "GameEngine.js" as GameEngine
import "PokerHandEvaluator.js" as PokerHands

App {
    id: root
    width: 900
    height: 680

    property var playerHand: []
    property var computerHand: []
    property var remainingDeck: []
    property var selectedIndices: []
    readonly property bool drawAvailable: gameState.phase === "draw"
    property int playerDrawCount: 0
    property int computerDrawCount: 0

    property string playerHandName: ""
    property string computerHandName: ""
    property string winnerText: ""

    property var gameState: GameEngine.createGame()

    property var computerSelectedIndices: []
    property bool computerDrawing: false

    property string message: ""
    property bool revealComputer: false

    function dealCards() {
        if (gameState.phase !== "ready" &&
            gameState.phase !== "finished")
            return

        if (gameState.chips.player < gameState.ante ||
            gameState.chips.computer < gameState.ante) {
            message = "Game over — not enough chips for ante"
            return
        }

        const dealt = GameEngine.startHand()

        playerHand = dealt.playerHand
        computerHand = dealt.computerHand
        remainingDeck = dealt.remainingDeck

        selectedIndices = []
        playerDrawCount = 0
        computerDrawCount = 0

        playerHandName = ""
        computerHandName = ""
        winnerText = ""
        message = ""
        revealComputer = false

        gameState = GameEngine.startBettingHand(gameState)

        runComputerTurn()
    }

    function toggleCard(index) {
        if (!drawAvailable || computerDrawing)
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
        if (!drawAvailable || computerDrawing)
            return

        // Player exchanges selected cards immediately
        const playerResult = GameEngine.exchangeCards(
            playerHand,
            selectedIndices,
            remainingDeck
        )

        playerHand = playerResult.hand
        remainingDeck = playerResult.remainingDeck

        playerDrawCount = selectedIndices.length
        selectedIndices = []

        // Computer selects its cards
        computerSelectedIndices =
            PokerAI.chooseDiscardIndices(computerHand)

        computerDrawing = true

        // Show selected cards before exchanging
        computerDrawTimer.start()
    }


    function finishComputerDraw() {
        if (!computerDrawing || gameState.phase !== "draw")
            return

        const result = GameEngine.exchangeCards(
            computerHand,
            computerSelectedIndices,
            remainingDeck
        )

        computerHand = result.hand
        remainingDeck = result.remainingDeck

        computerDrawCount = computerSelectedIndices.length

        // Move cards back to their normal positions
        computerSelectedIndices = []
        computerDrawing = false

        // Continue the game
        gameState = GameEngine.completeDraw(gameState)

        finishIfNeeded()
        runComputerTurn()
    }


    function playerAction(action, amount) {
        if (gameState.acting !== "player")
            return

        try {
            gameState = GameEngine.applyBettingAction(
                gameState, action, amount
            )

            message = ""

            finishIfNeeded()
            runComputerTurn()

        } catch (error) {
            message = String(error)
        }
    }

    function runComputerTurn() {
        if (gameState.acting !== "computer")
            return

        // Random delay: 500–1500 ms
        computerTurnTimer.interval =
            500 + Math.floor(Math.random() * 1001)

        computerTurnTimer.restart()
    }


    function executeComputerTurn() {
        if (gameState.acting !== "computer")
            return

        const decision = PokerAI.chooseBettingAction(
            gameState,
            computerHand,
            playerDrawCount
        )

        gameState = GameEngine.applyBettingAction(
            gameState,
            decision.action,
            decision.amount
        )

        finishIfNeeded()

        // Schedule another action if needed
        runComputerTurn()
    }


    function finishIfNeeded() {
        if (gameState.phase === "showdown") {
            playerHandName =
                PokerHands.evaluateHand(playerHand).name

            computerHandName =
                PokerHands.evaluateHand(computerHand).name

            const comparison = PokerHands.compareHands(
                playerHand, computerHand
            )

            const winner = comparison > 0 ? "player" :
                           comparison < 0 ? "computer" : "tie"

            gameState = GameEngine.settleShowdown(
                gameState, winner
            )

            revealComputer = true

            winnerText = winner === "tie"
                ? "TIE — POT SPLIT"
                : winner === "player"
                  ? "YOU WIN!"
                  : "COMPUTER WINS!"

        } else if (gameState.phase === "finished" &&
                   gameState.reason === "fold") {

            winnerText = gameState.winner === "player"
                ? "COMPUTER FOLDED — YOU WIN!"
                : "YOU FOLDED — COMPUTER WINS!"
        }
    }

    function resetGame() {
        gameState = GameEngine.createGame()
        dealCards()
    }

    Component.onCompleted: dealCards()

    Timer {
        id: computerTurnTimer
        interval: 1000
        repeat: false

        onTriggered: root.executeComputerTurn()
    }


    Timer {
        id: computerDrawTimer

        interval: 1000
        repeat: false

        onTriggered: root.finishComputerDraw()
    }


    Rectangle {
        anchors.fill: parent
        color: "darkgreen"

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16

            Text {
                text: root.winnerText
                visible: text !== ""

                color: "yellow"
                font.pixelSize: 26
                font.bold: true

                Layout.alignment: Qt.AlignHCenter
            }

            RowLayout {
                spacing: 20
                Layout.alignment: Qt.AlignHCenter

                // Invisible spacer balances the chip on the right
                Item {
                    Layout.preferredWidth: 90
                    Layout.preferredHeight: 90
                }

                Row {
                    spacing: 8

                    Repeater {
                        model: root.computerHand

                        delegate: Item {
                            id: computerCardSlot

                            required property int index
                            required property var modelData

                            width: 75
                            height: 120

                            PlayingCard {
                                anchors.horizontalCenter: parent.horizontalCenter

                                card: computerCardSlot.modelData
                                faceUp: root.revealComputer
                                selectable: false

                                selected: root.computerSelectedIndices.includes(
                                              computerCardSlot.index)

                                y: selected ? 0 : 12

                                Behavior on y {
                                    NumberAnimation {
                                        duration: 180
                                    }
                                }
                            }
                        }
                    }
                }

                PokerChip {
                    amount: root.gameState.chips.computer
                }
            }

            Text {
                text: "POT: " + root.gameState.pot
                color: "yellow"
                font.pixelSize: 25
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: root.message
                visible: text.length > 0
                color: "yellow"
                Layout.alignment: Qt.AlignHCenter
            }

            RowLayout {
                spacing: 20
                Layout.alignment: Qt.AlignHCenter

                // Invisible spacer balances the chip on the right
                Item {
                    Layout.preferredWidth: 90
                    Layout.preferredHeight: 90
                }

                Row {
                    spacing: 8

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
                                card: cardSlot.modelData
                                selected: root.selectedIndices.indexOf(cardSlot.index) !== -1
                                selectable: root.drawAvailable
                                y: selected ? 0 : 12

                                onClicked: root.toggleCard(cardSlot.index)

                                Behavior on y {
                                    NumberAnimation {
                                        duration: 120
                                    }
                                }
                            }
                        }
                    }
                }

                PokerChip {
                    amount: root.gameState.chips.player
                }
            }

            Text {
                text: root.drawAvailable
                      ? "Select 0-5 cards to replace (" + root.selectedIndices.length + " selected)"
                      : "You changed " + root.playerDrawCount + " cards"
                color: "white"
                Layout.alignment: Qt.AlignHCenter
            }

            BettingControls {
                visible: root.gameState.acting === "player"
                gameState: root.gameState

                Layout.alignment: Qt.AlignHCenter

                onActionRequested: (action, amount) => {
                    root.playerAction(action, amount)
                }
            }

            Button {
                text: "Draw"

                visible: root.drawAvailable
                enabled: !root.computerDrawing

                Layout.alignment: Qt.AlignHCenter
                onClicked: root.drawCards()
            }

            Button {
                text: "Deal New Hand"

                visible: root.gameState.phase === "finished" &&
                         root.gameState.chips.player >= root.gameState.ante &&
                         root.gameState.chips.computer >= root.gameState.ante

                Layout.alignment: Qt.AlignHCenter
                onClicked: root.dealCards()
            }

            Button {
                text: "New Game"

                visible: root.gameState.phase === "finished" &&
                         (root.gameState.chips.player < root.gameState.ante ||
                          root.gameState.chips.computer < root.gameState.ante)

                Layout.alignment: Qt.AlignHCenter
                onClicked: root.resetGame()
            }

        }
    }
}
