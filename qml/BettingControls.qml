
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "GameEngine.js" as GameEngine

RowLayout {
    id: root
    spacing: 8

    property var gameState: null

    signal actionRequested(string action, int amount)

    readonly property bool playerTurn:
        gameState !== null &&
        gameState.acting === "player" &&
        (gameState.phase === "betting1" ||
         gameState.phase === "betting2")

    readonly property var actions: playerTurn
        ? GameEngine.availableActions(gameState) : []

    readonly property int toCall: playerTurn
        ? gameState.currentBet - gameState.roundBets.player : 0

    readonly property int maxTotal: playerTurn
        ? GameEngine.maxBetTo(gameState, "player") : 0

    readonly property int normalMin: playerTurn
        ? (gameState.currentBet === 0
           ? gameState.minBet
           : gameState.currentBet + gameState.lastRaise) : 0

    readonly property int minTotal: Math.min(normalMin, maxTotal)

    readonly property int target: Number(amountField.text)

    readonly property bool validAmount:
        /^\d+$/.test(amountField.text) &&
        Number.isSafeInteger(target) &&
        target > (playerTurn ? gameState.currentBet : 0) &&
        target >= minTotal &&
        target <= maxTotal

    onGameStateChanged: {
        if (playerTurn)
            amountField.text = String(minTotal)
    }

    Button {
        text: "Check"
        visible: root.actions.includes("check")
        onClicked: root.actionRequested("check", 0)
    }

    Button {
        text: "Call " + root.toCall
        visible: root.actions.includes("call")
        onClicked: root.actionRequested("call", 0)
    }

    Button {
        text: "Fold"
        visible: root.actions.includes("fold")
        onClicked: root.actionRequested("fold", 0)
    }

    TextField {
        id: amountField

        visible: root.actions.includes("bet") ||
                 root.actions.includes("raise")

        Layout.preferredWidth: 110
        placeholderText: "Bet: " + root.minTotal + "–" + root.maxTotal
        inputMethodHints: Qt.ImhDigitsOnly

        validator: IntValidator {
            bottom: 1
            top: 1000000000
        }
    }

    Button {
        text: "Bet"
        visible: root.actions.includes("bet")
        enabled: root.validAmount

        onClicked: root.actionRequested("bet", root.target)
    }

    Button {
        text: "Raise"
        visible: root.actions.includes("raise")
        enabled: root.validAmount

        onClicked: root.actionRequested("raise", root.target)
    }
}
