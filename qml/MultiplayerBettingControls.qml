import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "MultiplayerEngine.js" as Engine

Item {
    id: root
    width: 440
    height: 76

    property var gameState: null
    property string pendingAction: "bet"

    signal actionRequested(string action, int amount)

    readonly property bool myTurn: gameState &&
        gameState.turnIndex === 0 &&
        (gameState.phase === "betting1" || gameState.phase === "betting2")
    readonly property var actions: myTurn ? Engine.availableActions(gameState) : []
    readonly property int toCall: myTurn
        ? gameState.currentBet - gameState.players[0].roundBet : 0
    readonly property int maximum: myTurn ? Engine.maxBetTo(gameState, 0) : 0
    readonly property int minimum: myTurn
        ? Math.min(maximum, Engine.minBetTo(gameState)) : 0
    readonly property int enteredAmount: Number(amountField.text)
    readonly property bool validAmount: /^\d+$/.test(amountField.text) &&
        Number.isSafeInteger(enteredAmount) &&
        enteredAmount >= minimum && enteredAmount <= maximum &&
        enteredAmount > (myTurn ? gameState.currentBet : 0)

    function openAmountDialog(action) {
        pendingAction = action
        amountField.text = String(minimum)
        amountPopup.open()
    }

    Row {
        anchors.centerIn: parent
        spacing: 10

        RoundActionButton {
            text: "Check"
            visible: root.actions.includes("check")
            onClicked: root.actionRequested("check", 0)
        }
        RoundActionButton {
            text: "Bet"
            visible: root.actions.includes("bet")
            onClicked: root.openAmountDialog("bet")
        }
        RoundActionButton {
            text: "Call\n" + root.toCall
            visible: root.actions.includes("call")
            onClicked: root.actionRequested("call", 0)
        }
        RoundActionButton {
            text: "Raise"
            visible: root.actions.includes("raise")
            onClicked: root.openAmountDialog("raise")
        }
        RoundActionButton {
            text: "Fold"
            visible: root.actions.includes("fold")
            onClicked: root.actionRequested("fold", 0)
        }
    }

    Popup {
        id: amountPopup
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 260
        padding: 20
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

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
                font.bold: true
                font.pixelSize: 20
                color: "black"
                Layout.alignment: Qt.AlignHCenter
            }

            TextField {
                id: amountField
                Layout.fillWidth: true
                font.pixelSize: 24
                color: "black"
                horizontalAlignment: Text.AlignHCenter
                inputMethodHints: Qt.ImhDigitsOnly
                selectByMouse: true
                validator: IntValidator {
                    bottom: 1
                    top: Math.max(1, root.maximum)
                }
            }

            Label {
                text: root.minimum + " – " + root.maximum
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
                    amountPopup.close()
                    root.actionRequested(action, amount)
                }
            }
        }
    }
}
