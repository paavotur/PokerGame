import QtQuick

Item {
    id: root

    property int amount: 0

    width: 90
    height: 90

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            const cx = width / 2
            const cy = height / 2
            const outerR = Math.min(width, height) / 2 - 2
            const innerR = outerR * 0.52

            // Outer black chip
            ctx.beginPath()
            ctx.arc(cx, cy, outerR, 0, Math.PI * 2)
            ctx.fillStyle = "black"
            ctx.fill()

            // Inner white center
            ctx.beginPath()
            ctx.arc(cx, cy, innerR, 0, Math.PI * 2)
            ctx.fillStyle = "white"
            ctx.fill()

            // White edge marks
            for (let i = 0; i < 6; i++) {
                ctx.save()
                ctx.translate(cx, cy)
                ctx.rotate(i * Math.PI / 3)

                ctx.fillStyle = "white"
                ctx.beginPath()
                ctx.moveTo(-7, -outerR + 8)
                ctx.lineTo(7, -outerR + 8)
                ctx.lineTo(12, -outerR + 22)
                ctx.lineTo(-12, -outerR + 22)
                ctx.closePath()
                ctx.fill()

                ctx.restore()
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.amount
        color: "black"
        font.pixelSize: 20
        font.bold: true
    }
}
