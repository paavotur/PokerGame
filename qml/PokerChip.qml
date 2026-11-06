
import QtQuick

Item {
    id: root

    property int amount: 0

    width: 100
    height: 100

    Canvas {
        id: canvas
        anchors.fill: parent

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            const cx = width / 2
            const cy = height / 2
            const r = Math.min(width, height) * 0.46

            function circle(radius, color, offsetY = 0) {
                ctx.beginPath()
                ctx.arc(cx, cy + offsetY, radius,
                        0, Math.PI * 2)
                ctx.fillStyle = color
                ctx.fill()
            }

            // Bottom shadow
            circle(r + 1, "#222222", 3)

            // Black outer edge
            circle(r + 1, "#111111")

            // Red chip body
            circle(r, "#d71919")

            // Six large white edge segments
            for (let i = 0; i < 6; i++) {
                const angle = -Math.PI / 2 +
                              i * Math.PI / 3

                const start = angle - 0.23
                const end = angle + 0.23

                ctx.beginPath()

                ctx.arc(cx, cy, r * 0.97,
                        start, end, false)

                ctx.arc(cx, cy, r * 0.78,
                        end, start, true)

                ctx.closePath()
                ctx.fillStyle = "#ffffff"
                ctx.fill()
            }

            // Inner red ring
            circle(r * 0.73, "#a80e0e")
            circle(r * 0.70, "#e21b1b")

            // White center
            circle(r * 0.67, "#ffffff")

            // Thin center outline
            ctx.beginPath()
            ctx.arc(cx, cy, r * 0.67,
                    0, Math.PI * 2)

            ctx.strokeStyle = "#bbbbbb"
            ctx.lineWidth = 1
            ctx.stroke()

            // Subtle highlight on top edge
            ctx.beginPath()
            ctx.arc(cx, cy, r * 0.94,
                    Math.PI * 1.12,
                    Math.PI * 1.88)

            ctx.strokeStyle = "rgba(255,255,255,0.25)"
            ctx.lineWidth = 2
            ctx.stroke()
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.amount

        color: "black"
        font.bold: true

        font.pixelSize: String(root.amount).length > 3
                        ? 16 : 20
    }
}
