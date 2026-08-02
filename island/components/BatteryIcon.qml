import QtQuick
import "../config"

Canvas {
  id: root
  width: 56
  height: 16

  property int percent: 100
  property bool charging: false
  property color fillColor: root.charging ? Theme.green : (root.percent > 20 ? Theme.foreground : Theme.red)

  onPercentChanged: requestPaint()
  onChargingChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.clearRect(0, 0, width, height)

    var cy = 8
    var bw = 26, bh = 12
    var bx = 0, by = cy - bh / 2
    var r = 2

    ctx.strokeStyle = root.fillColor
    ctx.fillStyle = root.fillColor
    ctx.lineWidth = 1.2

    // nub on right
    ctx.beginPath()
    ctx.rect(bw, by + 3, 3, bh - 6)
    ctx.fill()

    // body outline (rounded rect)
    ctx.beginPath()
    ctx.moveTo(bx + r, by)
    ctx.lineTo(bx + bw - r, by)
    ctx.arcTo(bx + bw, by, bx + bw, by + r, r)
    ctx.lineTo(bx + bw, by + bh - r)
    ctx.arcTo(bx + bw, by + bh, bx + bw - r, by + bh, r)
    ctx.lineTo(bx + r, by + bh)
    ctx.arcTo(bx, by + bh, bx, by + bh - r, r)
    ctx.lineTo(bx, by + r)
    ctx.arcTo(bx, by, bx + r, by, r)
    ctx.closePath()
    ctx.stroke()

    // fill
    var fillW = Math.max(0, Math.min(bw - 4, (bw - 4) * root.percent / 100))
    if (fillW > 0) {
      ctx.beginPath()
      ctx.moveTo(bx + 2 + r, by + 2)
      ctx.lineTo(bx + 2 + fillW - r, by + 2)
      ctx.arcTo(bx + 2 + fillW, by + 2, bx + 2 + fillW, by + 2 + r, r)
      ctx.lineTo(bx + 2 + fillW, by + bh - 2 - r)
      ctx.arcTo(bx + 2 + fillW, by + bh - 2, bx + 2 + fillW - r, by + bh - 2, r)
      ctx.lineTo(bx + 2 + r, by + bh - 2)
      ctx.arcTo(bx + 2, by + bh - 2, bx + 2, by + bh - 2 - r, r)
      ctx.lineTo(bx + 2, by + 2 + r)
      ctx.arcTo(bx + 2, by + 2, bx + 2 + r, by + 2, r)
      ctx.closePath()
      ctx.fill()
    }

    // lightning bolt when charging
    if (root.charging) {
      ctx.fillStyle = Theme.background
      ctx.strokeStyle = "transparent"
      ctx.beginPath()
      ctx.moveTo(bx + 11, by + 1)
      ctx.lineTo(bx + 8, by + 5)
      ctx.lineTo(bx + 10, by + 5)
      ctx.lineTo(bx + 7, by + 10)
      ctx.lineTo(bx + 12, by + 5)
      ctx.lineTo(bx + 10, by + 5)
      ctx.closePath()
      ctx.fill()
    }

    // percentage text
    ctx.fillStyle = root.fillColor
    ctx.font = "bold 12px 'JetBrainsMono Nerd Font'"
    ctx.textAlign = "left"
    ctx.textBaseline = "middle"
    ctx.fillText(Math.round(root.percent) + "%", bx + bw + 8, cy)
  }
}
