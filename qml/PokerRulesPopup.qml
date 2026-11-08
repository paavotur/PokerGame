
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root

    property int currentTab: 0
    property int startingChips: 1000
    property int ante: 20
    property int minBet: 50

    parent: Overlay.overlay
    anchors.centerIn: Overlay.overlay

    width: Math.min(470, parent.width - 24)
    height: Math.min(530, parent.height - 24)
    padding: 18

    modal: true
    focus: true

    closePolicy: Popup.CloseOnEscape |
                 Popup.CloseOnPressOutside

    onOpened: {
        currentTab = 0
        rulesFlick.contentY = 0
    }

    background: Rectangle {
        color: "white"
        radius: 12
        border.color: "#333333"
        border.width: 2
    }

    contentItem: ColumnLayout {
        spacing: 14

        // Header
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Poker Rules"
                font.pixelSize: 22
                font.bold: true
                color: "black"
            }

            Item {
                Layout.fillWidth: true
            }

            Button {
                id: closeButton
                text: "×"
                implicitWidth: 36
                implicitHeight: 36
                onClicked: root.close()

                background: Rectangle {
                    radius: 18
                    color: closeButton.down ||
                           closeButton.hovered
                           ? "#dddddd" : "white"
                }

                contentItem: Text {
                    text: closeButton.text
                    color: "black"
                    font.pixelSize: 24
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Tabs
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: ["How to Play", "Betting", "Hands"]

                delegate: Button {
                    id: tabButton

                    required property int index
                    required property string modelData

                    text: modelData
                    Layout.fillWidth: true
                    implicitHeight: 40

                    onClicked: {
                        root.currentTab = index
                        rulesFlick.contentY = 0
                    }

                    background: Rectangle {
                        radius: 6
                        color: root.currentTab === tabButton.index
                               ? "#176b43" : "#eeeeee"
                    }

                    contentItem: Text {
                        text: tabButton.text
                        font.pixelSize: 13
                        font.bold: true

                        color: root.currentTab === tabButton.index
                               ? "white" : "black"

                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // Scrollable tab content
        Flickable {
            id: rulesFlick

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            contentWidth: width
            contentHeight: rulesContent.implicitHeight

            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            Column {
                id: rulesContent

                width: rulesFlick.width - 12
                spacing: 12

                // HOW TO PLAY
                Column {
                    visible: root.currentTab === 0
                    width: parent.width
                    spacing: 12

                    Text {
                        text: "Five Card Draw"
                        font.pixelSize: 18
                        font.bold: true
                        color: "black"
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: 15
                        color: "#333333"

                        text:
                            "1. Four players compete: you and three computers.\n\n" +
                            "2. Everyone starts with " + root.startingChips + " chips.\n\n" +
                            "3. Each player pays an ante of " + root.ante + " chips.\n\n" +
                            "4. Everyone receives five cards.\n\n" +
                            "5. First betting round.\n\n" +
                            "6. Players exchange 0–5 cards, one at a time.\n\n" +
                            "7. Second betting round.\n\n" +
                            "8. Remaining players reveal their hands. The best hand wins the pot."
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: 15
                        color: "#333333"

                        text: "The dealer rotates clockwise after every hand. " +
                              "The next active player clockwise from the dealer acts first."
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: 15
                        color: "#333333"

                        text: "If you cannot afford the next ante after a hand finishes, the game ends."
                    }
                }

                // BETTING
                Column {
                    visible: root.currentTab === 1
                    width: parent.width
                    spacing: 12

                    Text {
                        text: "No-Limit Betting"
                        font.pixelSize: 18
                        font.bold: true
                        color: "black"
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: 15
                        color: "#333333"

                        text: "Ante: " + root.ante +
                              " chips\nMinimum opening bet: " +
                              root.minBet + " chips\n\n" +
                              "Check – Continue without betting.\n\n" +
                              "Bet – Place the first bet.\n\n" +
                              "Call – Match the current bet.\n\n" +
                              "Raise – Increase the current bet.\n\n" +
                              "Fold – Give up your hand.\n\n" +
                              "All-in – Risk all your remaining chips."
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: 15
                        color: "#333333"

                        text: "In No-Limit poker, you can bet as much as your available effective stack allows.\n\n" +
                              "A raise must normally be at least as large as the previous full raise.\n\n" +
                              "If everyone else folds, the last remaining player wins immediately."
                    }
                }

                // HAND RANKINGS
                Column {
                    visible: root.currentTab === 2
                    width: parent.width
                    spacing: 5

                    Repeater {
                        model: [
                            "Royal Flush",
                            "Straight Flush",
                            "Four of a Kind",
                            "Full House",
                            "Flush",
                            "Straight",
                            "Three of a Kind",
                            "Two Pair",
                            "One Pair",
                            "High Card"
                        ]

                        delegate: Rectangle {
                            required property int index
                            required property string modelData

                            width: rulesContent.width
                            height: 34
                            radius: 4

                            color: index % 2 === 0
                                   ? "#f3f3f3" : "white"

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter

                                text: (index + 1) + ". " + modelData
                                color: "black"
                                font.pixelSize: 16
                            }
                        }
                    }
                }
            }
        }
    }
}
