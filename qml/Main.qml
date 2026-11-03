import Felgo
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

        const playerResult = GameEngine.exchangeCards(
            playerHand,
            selectedIndices,
            remainingDeck
        )

        const computerIndices =
            GameEngine.randomExchangeIndices()

        const computerResult = GameEngine.exchangeCards(
            computerHand,
            computerIndices,
            playerResult.remainingDeck
        )

        playerHand = playerResult.hand
        computerHand = computerResult.hand
        remainingDeck = computerResult.remainingDeck

        playerDrawCount = selectedIndices.length
        computerDrawCount = computerIndices.length
        selectedIndices = []

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
        for (let step = 0;
             step < 4 && gameState.acting === "computer";
             step++) {

            const options =
                GameEngine.availableActions(gameState)

            if (options.length === 0)
                break

            const action = options[
                Math.floor(Math.random() * options.length)
            ]

            let amount = 0

            if (action === "bet" || action === "raise") {
                const maxTo = GameEngine.maxBetTo(
                    gameState, "computer"
                )

                const fullMin = action === "bet"
                    ? gameState.minBet
                    : gameState.currentBet + gameState.lastRaise

                const low = Math.min(fullMin, maxTo)

                amount = low

                // Occasionally use the largest allowed bet.
                if (maxTo > low && Math.random() < 0.3)
                    amount = maxTo
            }

            gameState = GameEngine.applyBettingAction(
                gameState, action, amount
            )

            finishIfNeeded()
        }
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

    Rectangle {
        anchors.fill: parent
        color: "darkgreen"

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16

            Text {
                text: "COMPUTER — " + root.gameState.chips.computer
                      + " chips"
                      + (root.computerHandName
                         ? " — " + root.computerHandName : "")

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
                        faceUp: root.revealComputer
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
                text: "POT: " + root.gameState.pot
                color: "yellow"
                font.pixelSize: 25
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: root.gameState.phase === "betting1"
                      ? "Betting round 1"
                      : root.gameState.phase === "draw"
                        ? "Draw cards (0–5)"
                        : root.gameState.phase === "betting2"
                          ? "Betting round 2"
                          : root.gameState.phase === "finished"
                            ? "Hand finished" : ""

                color: "white"
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

            Text {
                text: root.message
                visible: text.length > 0
                color: "yellow"
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
                text: "PLAYER — " + root.gameState.chips.player
                      + " chips"
                      + (root.playerHandName
                         ? " — " + root.playerHandName : "")

                visible: !root.drawAvailable
                color: "white"
                font.pixelSize: 22
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
