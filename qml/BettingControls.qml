
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "GameEngine.js" as GameEngine

RowLayout {
    id: root
    spacing: 10

    property var gameState: null
    property string pendingAction: "bet"

    signal actionRequested(string action, int amount)

    readonly property var actions:
        gameState && gameState.acting === "player"
        ? GameEngine.availableActions(gameState) : []

    readonly property int toCall: gameState
        ? gameState.currentBet - gameState.roundBets.player : 0

    readonly property int maxTotal: gameState
        ? GameEngine.maxBetTo(gameState, "player") : 0

    readonly property int minTotal: gameState
        ? Math.min(maxTotal,
            pendingAction === "bet"
            ? gameState.minBet
            : gameState.currentBet + gameState.lastRaise)
        : 0

    readonly property int enteredAmount: Number(amountField.text)

    readonly property bool validAmount:
        /^\d+$/.test(amountField.text) &&
        Number.isSafeInteger(enteredAmount) &&
        enteredAmount >= minTotal &&
        enteredAmount <= maxTotal

    function openBetDialog(action) {
        pendingAction = action
        amountField.text = String(minTotal)
        amountDialog.open()
        amountField.forceActiveFocus()
    }

    RoundActionButton {
        text: "Check"
        visible: root.actions.includes("check")
        onClicked: root.actionRequested("check", 0)
    }

    RoundActionButton {
        text: "Bet"
        visible: root.actions.includes("bet")
        onClicked: root.openBetDialog("bet")
    }

    RoundActionButton {
        text: "Call\n" + root.toCall
        visible: root.actions.includes("call")
        onClicked: root.actionRequested("call", 0)
    }

    RoundActionButton {
        text: "Raise"
        visible: root.actions.includes("raise")
        onClicked: root.openBetDialog("raise")
    }

    RoundActionButton {
        text: "Fold"
        visible: root.actions.includes("fold")
        onClicked: root.actionRequested("fold", 0)
    }

    Popup {
        id: amountDialog

        parent: Overlay.overlay
        anchors.centerIn: parent

        width: 260
        padding: 20

        modal: true
        focus: true

        closePolicy: Popup.CloseOnEscape |
                     Popup.CloseOnPressOutside

        background: Rectangle {
            color: "white"
            radius: 12
            border.color: "black"
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 12

            Label {
                text: root.pendingAction === "bet" ? "Bet" : "Raise"
                font.pixelSize: 20
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            TextField {
                id: amountField

                Layout.fillWidth: true
                font.pixelSize: 24
                horizontalAlignment: Text.AlignHCenter
                selectByMouse: true

                inputMethodHints: Qt.ImhDigitsOnly

                validator: IntValidator {
                    bottom: 1
                    top: Math.max(1, root.maxTotal)
                }
            }

            Label {
                text: root.minTotal + " – " + root.maxTotal
                color: "gray"
                Layout.alignment: Qt.AlignHCenter
            }

            RoundActionButton {
                text: "OK"
                enabled: root.validAmount
                Layout.alignment: Qt.AlignHCenter

                onClicked: {
                    const amount = root.enteredAmount
                    const action = root.pendingAction

                    amountDialog.close()
                    root.actionRequested(action, amount)
                }
            }
        }
    }
}
