
import Felgo
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "GameEngine.js" as GameEngine

App {
    id: root

    width: 900
    height: 600

    property var playerHand: []
    property var computerHand: []
    property var remainingDeck: []

    function dealCards() {
        const result = GameEngine.startHand()

        playerHand = result.playerHand
        computerHand = result.computerHand
        remainingDeck = result.remainingDeck
    }

    Component.onCompleted: dealCards()

    Rectangle {
        anchors.fill: parent
        color: "darkgreen"

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 25

            Text {
                text: "OPPONENT"
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
                        card: modelData
                        faceUp: false
                    }
                }
            }

            Text {
                text: "POT: 20"
                color: "yellow"
                font.pixelSize: 25
                Layout.alignment: Qt.AlignHCenter
            }

            Row {
                spacing: 8
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: root.playerHand

                    delegate: PlayingCard {
                        card: modelData
                        faceUp: true
                    }
                }
            }

            Text {
                text: "PLAYER"
                color: "white"
                font.pixelSize: 22
                Layout.alignment: Qt.AlignHCenter
            }

            Button {
                text: "Deal Cards"
                Layout.alignment: Qt.AlignHCenter
                onClicked: root.dealCards()
            }
        }
    }
}
