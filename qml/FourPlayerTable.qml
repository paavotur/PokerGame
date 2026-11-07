import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "MultiplayerEngine.js" as Engine
import "MultiplayerAI.js" as PokerAI
import "PokerHandEvaluator.js" as Hands

Rectangle {
    id: root
    color: "#176b43"

    property var game: Engine.createGame()
    property var selectedIndices: []
    property var computerSelections: ({})
    property bool computerDrawing: false
    property bool revealComputer: false
    property string winnerText: ""
    property string errorText: ""
    property var lastActions: ["", "", "", ""]

    property bool chipsMoving: false
    property int animatingPlayerId: -1

    readonly property bool playerCanDraw:
        game.phase === "draw" && game.players[0].inHand &&
        !game.players[0].folded && !game.players[0].drawn &&
        !computerDrawing

    readonly property int playersAbleToAnte:
        game.players.filter(p => p.chips >= game.ante).length


    readonly property int highlightedPlayerId:
        chipsMoving
            ? animatingPlayerId
            : (game.phase === "betting1" ||
               game.phase === "betting2")
                ? game.turnIndex
                : -1



    function startNewHand() {
        if (game.phase !== "ready" && game.phase !== "finished")
            return
        if (playersAbleToAnte < 2)
            return
        if (chipsMoving)
            return

        computerTurnTimer.stop()
        computerDrawTimer.stop()
        drawFinishTimer.stop()
        selectedIndices = []
        computerSelections = ({})
        computerDrawing = false
        revealComputer = false
        winnerText = ""
        errorText = ""
        lastActions = ["", "", "", ""]

        game = Engine.startHand(game)
        potStack.amount = game.pot
        advanceGame()
    }

    function newGame() {
        game = Engine.createGame()
        startNewHand()
    }

    function toggleCard(index) {
        if (!root.chipsMoving && !playerCanDraw)
            return
        const indices = selectedIndices.slice()
        const at = indices.indexOf(index)
        if (at < 0)
            indices.push(index)
        else
            indices.splice(at, 1)
        selectedIndices = indices
    }

    function playerAction(action, amount) {
        if (game.turnIndex !== 0 || chipsMoving)
            return

        try {
            const before = game

            const next = Engine.applyBettingAction(
                before, action, amount
            )

            setPlayerAction(
                0,
                describeAction(before, next, 0, action, amount)
            )

            errorText = ""

            // Animate chips moving to the pot.
            // The next turn starts after the animation.
            animateBettingAction(0, before, next)

        } catch (error) {
            errorText = String(error)
            console.log(errorText)
        }
    }

    function drawPlayerCards() {
        if (!root.chipsMoving && !playerCanDraw)
            return
        try {
            const count = selectedIndices.length
            game = Engine.drawCards(game, 0, selectedIndices)

            setPlayerAction(
                0,
                count === 0 ? "Stand pat" : "Draw " + count
            )
            selectedIndices = []
            startComputerDraw()
        } catch (error) {
            errorText = String(error)
            console.log(errorText)
        }
    }

    function startComputerDraw() {
        if (game.phase !== "draw" || computerDrawing)
            return

        const selections = {}
        for (let i = 1; i < game.players.length; i++) {
            const p = game.players[i]
            if (p.inHand && !p.folded && !p.drawn)
                selections[i] = PokerAI.chooseDiscardIndices(p.hand)
        }

        computerSelections = selections
        computerDrawing = true
        computerDrawTimer.restart()
    }

    function finishComputerDraw() {
        if (!computerDrawing || game.phase !== "draw")
            return

        try {
            let next = game
            for (let i = 1; i < game.players.length; i++) {
                const p = next.players[i]
                if (p.inHand && !p.folded && !p.drawn)
                    next = Engine.drawCards(next, i,
                        computerSelections[i] || [])
                        const count = (computerSelections[i] || []).length

                        setPlayerAction(
                            i,
                            count === 0 ? "Stand pat" : "Draw " + count
                        )
            }
            // Replace cards, but remain in draw phase.
            game = next

            // Allow replacement cards to become visible.
            computerSelections = ({})

            // Wait for the animation before advancing turns.
            drawFinishTimer.restart()

        } catch (error) {
            errorText = String(error)
            console.log(errorText)
        }
    }

    function playComputerTurn() {
        if (game.turnIndex <= 0 ||
            (game.phase !== "betting1" &&
             game.phase !== "betting2"))
            return

        try {
            const playerId = game.turnIndex
            const before = game

            const decision = PokerAI.chooseBettingAction(game)

            const next = Engine.applyBettingAction(
                before,
                decision.action,
                decision.amount
            )

            setPlayerAction(
                playerId,
                describeAction(
                    before,
                    next,
                    playerId,
                    decision.action,
                    decision.amount
                )
            )

            animateBettingAction(playerId, before, next)

        } catch (error) {
            errorText = String(error)
            console.log(errorText)
        }
    }

    function advanceGame() {
        if (game.phase === "showdown") {
            game = Engine.settleShowdown(game, Hands.compareHands)
            revealComputer = true
        }

        if (game.phase === "finished") {
            const winners = game.winnerIds.map(id =>
                id === 0 ? "You" : "Player" + id
            )

            if (winners.length === 1) {
                winnerText = game.winnerIds[0] === 0
                    ? "YOU WIN!"
                    : winners[0] + " WINS!"
            } else {
                winnerText = winners.join(" & ") + " WIN!"
            }

            return
        }

        if (game.phase === "draw") {
            // If human folded, complete drawing for computer players automatically.
            if (!root.chipsMoving && !playerCanDraw && !computerDrawing)
                startComputerDraw()
            return
        }

        if ((game.phase === "betting1" || game.phase === "betting2") &&
            game.turnIndex > 0) {
            computerTurnTimer.interval = 1000 + Math.floor(Math.random() * 401)
            computerTurnTimer.restart()
        }
    }

    function setPlayerAction(playerId, text) {
        const actions = lastActions.slice()
        actions[playerId] = text
        lastActions = actions
    }

    function describeAction(before, after, playerId, action, amount) {
        if (action === "check")
            return "Check"

        if (action === "fold")
            return "Fold"

        let description = ""

        if (action === "call") {
            const player = before.players[playerId]
            const owed = before.currentBet - player.roundBet
            const paid = Math.min(owed, player.chips)

            description = "Call " + paid
        } else if (action === "bet") {
            description = "Bet " + amount
        } else if (action === "raise") {
            description = "Raise to " + amount
        }

        if (after.players[playerId].allIn)
            description += " (All-in)"

        return description
    }

    function animateBettingAction(playerId, before, after) {
        // How many chips did this player actually pay?
        const paid = before.players[playerId].chips -
                     after.players[playerId].chips

        if (paid > 0) {
            chipsMoving = true
            animatingPlayerId = playerId
        }

        game = after

        if (paid <= 0) {
            // Check or Fold: no chips to animate.
            potStack.amount = after.pot
            advanceGame()
            return
        }

        const seats = [
            humanSeat,
            topSeat,
            leftSeat,
            rightSeat
        ]

        potStack.flyFrom(
            seats[playerId].chipVisual,
            after.pot,
            function() {
                root.chipsMoving = false
                root.animatingPlayerId = -1
                root.advanceGame()
            }
        )
    }

        Timer {
        id: drawFinishTimer
        interval: 300
        repeat: false

        onTriggered: {
            if (!root.computerDrawing ||
                root.game.phase !== "draw")
                return

            try {
                root.game = Engine.completeDraw(root.game)
                root.computerDrawing = false
                root.advanceGame()
            } catch (error) {
                root.errorText = String(error)
                console.log(root.errorText)
            }
        }
    }

    Timer {
        id: computerTurnTimer
        repeat: false
        onTriggered: root.playComputerTurn()
    }

    Timer {
        id: computerDrawTimer
        interval: 650
        repeat: false
        onTriggered: root.finishComputerDraw()
    }

    RoundActionButton {
        text: "?"
        width: 50
        height: 50
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 16
        onClicked: rankingsPopup.open()
    }

    PlayerSeat {
        id: topSeat
        seatName: "Player1"
        player: root.game.players[1]
        lastAction: root.lastActions[1]

        chipPlacement: "right"
        discardDirection: "down"
        opacity: root.game.phase === "ready" ? 0 : 1

        cardWidth: 62
        cardHeight: 90
        cardSpacing: 5
        chipSize: 75

        reveal: root.revealComputer
        selectedIndices: root.computerSelections[1] || []

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 12

        activeTurn: root.highlightedPlayerId === 1
    }

    PlayerSeat {
        id: leftSeat
        seatName: "Player2"
        player: root.game.players[2]
        lastAction: root.lastActions[2]
        isDealer: root.game.dealerIndex === 2

        chipPlacement: "below"
        discardDirection: "right"
        opacity: root.game.phase === "ready" ? 0 : 1

        cardWidth: 62
        cardHeight: 90
        cardSpacing: 5
        chipSize: 75

        reveal: root.revealComputer
        selectedIndices: root.computerSelections[2] || []

        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.verticalCenter: parent.verticalCenter

        activeTurn: root.highlightedPlayerId === 2
    }

    PlayerSeat {
        id: rightSeat
        seatName: "Player3"
        player: root.game.players[3]
        lastAction: root.lastActions[3]
        isDealer: root.game.dealerIndex === 3

        chipPlacement: "below"
        discardDirection: "left"
        opacity: root.game.phase === "ready" ? 0 : 1

        cardWidth: 62
        cardHeight: 90
        cardSpacing: 5
        chipSize: 75

        reveal: root.revealComputer
        selectedIndices: root.computerSelections[3] || []

        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.verticalCenter: parent.verticalCenter

        activeTurn: root.highlightedPlayerId === 3
    }

    PotStack {
        id: potStack

        anchors.fill: parent
        z: 10

        showPile: root.game.phase !== "ready" &&
                  root.winnerText === ""
    }

    Text {
        anchors.centerIn: parent
        z: 11

        text: root.winnerText
        visible: text !== ""

        color: "#ffe99a"
        font.pixelSize: 26
        font.bold: true
    }

    PlayerSeat {
        id: humanSeat
        seatName: "Me"
        player: root.game.players[0]
        lastAction: root.lastActions[0]
        isDealer: root.game.dealerIndex === 0

        human: true
        chipPlacement: "right"
        opacity: root.game.phase === "ready" ? 0 : 1

        cardWidth: 62
        cardHeight: 90
        chipSize: 75
        drawEnabled: root.playerCanDraw
        selectedIndices: root.selectedIndices
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: controlsArea.top
        anchors.bottomMargin: 18
        onCardClicked: cardIndex => root.toggleCard(cardIndex)

        activeTurn: root.highlightedPlayerId === 0
    }

    Item {
        id: controlsArea
        width: parent.width
        height: 84
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18

        MultiplayerBettingControls {
            anchors.centerIn: parent
            gameState: root.game
            visible: root.game.turnIndex === 0 &&
                     (root.game.phase === "betting1" ||
                      root.game.phase === "betting2")
            onActionRequested: (action, amount) => root.playerAction(action, amount)
        }

        RoundActionButton {
            anchors.centerIn: parent
            text: "Draw"
            visible: root.playerCanDraw
            onClicked: root.drawPlayerCards()
        }

        RoundActionButton {
            anchors.centerIn: parent
            text: "Deal"

            visible: (root.game.phase === "ready" ||
                      root.game.phase === "finished") &&
                     root.playersAbleToAnte >= 2

            onClicked: root.startNewHand()
        }

        RoundActionButton {
            anchors.centerIn: parent
            text: "New Game"
            visible: root.game.phase === "finished" &&
                     root.playersAbleToAnte < 2
            onClicked: root.newGame()
        }
    }

    Text {
        text: root.errorText
        visible: text.length > 0
        color: "#ffe99a"
        anchors.bottom: controlsArea.top
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Popup {
        id: rankingsPopup
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        focus: true
        width: 300
        padding: 20
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            color: "white"
            radius: 12
            border.color: "black"
            border.width: 1
        }
        contentItem: ColumnLayout {
            spacing: 10
            Label {
                text: "POKER HAND RANKINGS"
                font.bold: true
                font.pixelSize: 18
                color: "black"
                Layout.alignment: Qt.AlignHCenter
            }
            Repeater {
                model: [
                    "1. Royal Flush", "2. Straight Flush",
                    "3. Four of a Kind", "4. Full House",
                    "5. Flush", "6. Straight",
                    "7. Three of a Kind", "8. Two Pair",
                    "9. One Pair", "10. High Card"
                ]
                delegate: Label {
                    required property string modelData
                    text: modelData
                    color: "black"
                    Layout.fillWidth: true
                }
            }
        }
    }
}
