import QtQuick
import "../config"

Canvas {
  id: root
  width: 108
  height: 20

  property real percent: 100
  property color color: Theme.foreground

  onPercentChanged: requestPaint()
  onColorChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.clearRect(0, 0, width, height)
    ctx.strokeStyle = root.color
    ctx.fillStyle = root.color
    ctx.lineWidth = 1.5
    ctx.lineCap = "round"
    ctx.lineJoin = "round"

    var cx = 8, cy = 10

    // sun circle
    ctx.beginPath()
    ctx.arc(cx, cy, 4, 0, Math.PI * 2)
    ctx.stroke()

    // sun rays (Lucide-style: 4 rays, 2px stroke, round caps)
    ctx.lineWidth = 2
    for (var i = 0; i < 4; i++) {
      var a = i * Math.PI / 2
      ctx.beginPath()
      ctx.moveTo(cx + Math.cos(a) * 5.5, cy + Math.sin(a) * 5.5)
      ctx.lineTo(cx + Math.cos(a) * 8, cy + Math.sin(a) * 8)
      ctx.stroke()
    }

    // meter bar
    var mx = cx + 14, my = cy - 5, mw = 60, mh = 10
    ctx.strokeStyle = Theme.selection
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.rect(mx, my, mw, mh)
    ctx.stroke()

    ctx.fillStyle = root.percent > 20 ? Theme.yellow : Theme.red
    var fillW = Math.max(0, Math.min(mw - 2, (mw - 2) * root.percent / 100))
    ctx.beginPath()
    ctx.rect(mx + 1, my + 1, fillW, mh - 2)
    ctx.fill()

    // percentage text
    ctx.fillStyle = root.color
    ctx.font = "bold 8px monospace"
    ctx.textAlign = "left"
    ctx.textBaseline = "bottom"
    ctx.fillText(Math.round(root.percent) + "%", mx + mw + 4, cy + 6)
  }
}
