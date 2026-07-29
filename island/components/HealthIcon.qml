import QtQuick
import "../config"

Canvas {
  id: root
  width: 16
  height: 16

  property color iconColor: Theme.foreground

  onIconColorChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.clearRect(0, 0, width, height)

    ctx.beginPath()
    ctx.moveTo(8, 14)
    ctx.bezierCurveTo(8, 14, 1, 10, 1, 6)
    ctx.bezierCurveTo(1, 3, 3.5, 1, 8, 4.5)
    ctx.bezierCurveTo(12.5, 1, 15, 3, 15, 6)
    ctx.bezierCurveTo(15, 10, 8, 14, 8, 14)

    ctx.fillStyle = root.iconColor
    ctx.globalAlpha = 0.2
    ctx.fill()
    ctx.globalAlpha = 1.0

    ctx.strokeStyle = root.iconColor
    ctx.lineWidth = 1.5
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    ctx.stroke()

    ctx.beginPath()
    ctx.moveTo(4, 8)
    ctx.lineTo(6.5, 8)
    ctx.lineTo(8, 4)
    ctx.lineTo(9.5, 12)
    ctx.lineTo(11, 7)
    ctx.lineTo(14, 7)
    ctx.stroke()
  }

  SequentialAnimation {
    loops: Animation.Infinite
    running: true
    NumberAnimation { target: root; property: "scale"; from: 1.0; to: 1.06; duration: 500; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "scale"; from: 1.06; to: 1.0; duration: 500; easing.type: Easing.InOutSine }
    PauseAnimation { duration: 900 }
  }
}
