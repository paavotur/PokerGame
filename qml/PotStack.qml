
import QtQuick

Item {
    id: root

    property int amount: 0
    property bool showPile: true
    property int nextAmount: 0
    property var finishCallback: null

    // Four overlapping poker chips in the center.
    Item {
        id: pile
        anchors.fill: parent
        visible: root.showPile

        readonly property int chipSize: 68

        // Back chip
        PokerChip {
            width: pile.chipSize
            height: pile.chipSize

            x: (pile.width - width) / 2
            y: (pile.height - height) / 2 - 23

            showAmount: false
        }

        // Bottom-left chip
        PokerChip {
            width: pile.chipSize
            height: pile.chipSize

            x: (pile.width - width) / 2 - 30
            y: (pile.height - height) / 2 + 20

            rotation: -12
            showAmount: false
        }

        // Bottom-right chip
        PokerChip {
            width: pile.chipSize
            height: pile.chipSize

            x: (pile.width - width) / 2 + 30
            y: (pile.height - height) / 2 + 20

            rotation: 12
            showAmount: false
        }

        // Top chip displays the pot amount
        PokerChip {
            id: topChip

            width: pile.chipSize
            height: pile.chipSize

            anchors.centerIn: parent

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

            to: topChip.x +
                (topChip.width - flyingChip.width) / 2

            duration: 450
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: flyingChip
            property: "y"

            to: topChip.y +
                (topChip.height - flyingChip.height) / 2

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
