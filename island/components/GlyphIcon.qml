import QtQuick
import "../config"

Canvas {
  id: root

  property string iconType: "moon"
  property bool active: false
  property color strokeColor: Theme.label

  implicitWidth: Theme.toggleIconSize
  implicitHeight: Theme.toggleIconSize
  renderTarget: Canvas.Image
  antialiasing: true

  onIconTypeChanged: requestPaint()
  onActiveChanged: requestPaint()
  onStrokeColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    ctx.clearRect(0, 0, width, height)
    var s = Math.min(width, height)
    var inset = (width - s) / 2
    ctx.strokeStyle = root.strokeColor
    ctx.lineWidth = Theme.toggleIconLineWidth
    ctx.lineCap = "round"
    ctx.lineJoin = "round"

    if (root.iconType === "moon") {
      ctx.beginPath()
      ctx.arc(inset + s * 0.5, s * 0.5, s * 0.34, 0.72, Math.PI * 1.72, false)
      ctx.stroke()
      if (root.active) {
        ctx.beginPath()
        ctx.moveTo(inset + s * 0.67, s * 0.25)
        ctx.lineTo(inset + s * 0.86, s * 0.10)
        ctx.stroke()
      }
    } else if (root.iconType === "eye") {
      ctx.beginPath()
      if (root.active) {
        ctx.moveTo(inset + s * 0.08, s * 0.5)
        ctx.quadraticCurveTo(inset + s * 0.5, s * 0.08, inset + s * 0.92, s * 0.5)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(inset + s * 0.08, s * 0.5)
        ctx.quadraticCurveTo(inset + s * 0.5, s * 0.92, inset + s * 0.92, s * 0.5)
      } else {
        ctx.moveTo(inset + s * 0.12, s * 0.7)
        ctx.quadraticCurveTo(inset + s * 0.5, s * 0.35, inset + s * 0.88, s * 0.7)
      }
      ctx.stroke()
      if (root.active) {
        ctx.beginPath()
        ctx.arc(inset + s * 0.5, s * 0.5, s * 0.13, 0, Math.PI * 2)
        ctx.stroke()
      } else {
        ctx.beginPath()
        ctx.moveTo(inset + s * 0.3, s * 0.57)
        ctx.lineTo(inset + s * 0.25, s * 0.48)
        ctx.moveTo(inset + s * 0.5, s * 0.48)
        ctx.lineTo(inset + s * 0.5, s * 0.38)
        ctx.moveTo(inset + s * 0.7, s * 0.57)
        ctx.lineTo(inset + s * 0.75, s * 0.48)
        ctx.stroke()
      }
    } else if (root.iconType === "bluetooth") {
      ctx.beginPath()
      ctx.moveTo(inset + s * 0.5, s * 0.1)
      ctx.lineTo(inset + s * 0.5, s * 0.9)
      ctx.moveTo(inset + s * 0.5, s * 0.1)
      ctx.lineTo(inset + s * 0.83, s * 0.34)
      ctx.lineTo(inset + s * 0.18, s * 0.68)
      ctx.moveTo(inset + s * 0.18, s * 0.32)
      ctx.lineTo(inset + s * 0.83, s * 0.67)
      ctx.lineTo(inset + s * 0.5, s * 0.9)
      ctx.stroke()
    }
  }
}
