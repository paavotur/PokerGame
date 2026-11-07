
import QtQuick

Item {
    id: root

    property int amount: 0
    property bool showPile: true
    property int nextAmount: 0
    property var finishCallback: null

    // Three overlapping poker chips in the center.
    Item {
        id: pile

        width: 110
        height: 95
        anchors.centerIn: parent
        visible: root.showPile

        PokerChip {
            x: 0
            y: 18
            width: 72
            height: 72
            showAmount: false
        }

        PokerChip {
            x: 26
            y: 16
            width: 72
            height: 72
            showAmount: false
        }

        PokerChip {
            x: 14
            y: 0
            width: 72
            height: 72

            amount: root.amount
            showAmount: true
        }
    }

    // The chip moving from a player toward the pot.
    PokerChip {
        id: flyingChip

        width: 48
        height: 48

        showAmount: false
        visible: false
        z: 10
    }

    function flyFrom(chipItem, updatedPot, callback) {
        if (flight.running)
            return

        nextAmount = updatedPot
        finishCallback = callback

        // Convert player chip coordinates into table coordinates.
        const point = chipItem.mapToItem(
            root,
            (chipItem.width - flyingChip.width) / 2,
            (chipItem.height - flyingChip.height) / 2
        )

        flyingChip.x = point.x
        flyingChip.y = point.y
        flyingChip.opacity = 1
        flyingChip.visible = true

        flight.start()
    }

    ParallelAnimation {
        id: flight

        NumberAnimation {
            target: flyingChip
            property: "x"

            to: pile.x + 14 + (72 - flyingChip.width) / 2

            duration: 450
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: flyingChip
            property: "y"

            to: pile.y + (72 - flyingChip.height) / 2

            duration: 450
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: flyingChip
            property: "opacity"

            from: 1
            to: 0.7
            duration: 450
        }

        onFinished: {
            flyingChip.visible = false

            // Update the displayed pot when the chip arrives.
            root.amount = root.nextAmount

            const callback = root.finishCallback
            root.finishCallback = null

            if (callback)
                callback()
        }
    }
}
