import QtQuick
import "../config"

Canvas {
  id: root
  antialiasing: true
  width: Theme.iconSize
  height: Theme.iconSize

  property color color: Theme.foreground
  property bool connected: false
  property string type: "wifi"

  onConnectedChanged: requestPaint()
  onColorChanged: requestPaint()
  onTypeChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.clearRect(0, 0, width, height)
    ctx.strokeStyle = root.color
    ctx.fillStyle = root.color
    ctx.lineWidth = Theme.iconLineWidth
    ctx.lineCap = "round"
    ctx.lineJoin = "round"

    if (!root.connected) {
      ctx.beginPath()
      ctx.arc(8, 8, 6, 0, Math.PI * 2)
      ctx.stroke()
      ctx.beginPath()
      ctx.moveTo(4, 4)
      ctx.lineTo(12, 12)
      ctx.stroke()
      return
    }

    if (root.type === "ethernet") {
      drawEthernet(ctx)
    } else {
      drawWifi(ctx)
    }
  }

  function drawWifi(ctx) {
    ctx.lineWidth = Theme.iconLineWidth
    ctx.lineCap = "round"
    for (var r = 2; r >= 0; r--) {
      ctx.beginPath()
      ctx.arc(8, 13, 1.5 + r * 3, -Math.PI / 2 - 0.6, -Math.PI / 2 + 0.6)
      ctx.stroke()
    }
    ctx.beginPath()
    ctx.arc(8, 13, 1.5, 0, Math.PI * 2)
    ctx.fill()
  }

  function drawEthernet(ctx) {
    ctx.lineWidth = Theme.iconLineWidth
    ctx.strokeRect(2, 4, 12, 9)
    ctx.lineWidth = Theme.iconLineWidth
    for (var i = 0; i < 4; i++) {
      ctx.beginPath()
      var x = 3 + i * 3
      ctx.moveTo(x, 6)
      ctx.lineTo(x, 11)
      ctx.stroke()
    }
  }
}
