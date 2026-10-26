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
    } else if (root.iconType === "prayer") {
      // Adhan speaker: a minaret with an arched top, a balcony, a spire and two
      // sound waves. The geometry is IconOven's `adhan-speaker` icon
      // (https://iconoven.com/icons, MIT, © Appic Marketing), traced on its own
      // 24-unit grid, so only that icon's shape is used - the stroke ratio is
      // the source's 1.5/24, floored at 1px for sizes below the pill's 18px.
      var u = s / 24
      var px = function (v) { return inset + v * u }
      var py = function (v) { return v * u }

      ctx.lineWidth = Math.max(1, 1.5 * u)

      // Minaret body: a tapering trapezoid with rounded shoulders.
      ctx.beginPath()
      ctx.moveTo(px(6.75), py(21.25))
      ctx.lineTo(px(11.75), py(21.25))
      ctx.quadraticCurveTo(px(12.25), py(21.25), px(12.2), py(20.75))
      ctx.lineTo(px(11.3), py(11))
      ctx.quadraticCurveTo(px(11.25), py(10.5), px(10.75), py(10.5))
      ctx.lineTo(px(7.75), py(10.5))
      ctx.quadraticCurveTo(px(7.25), py(10.5), px(7.2), py(11))
      ctx.lineTo(px(6.3), py(20.75))
      ctx.quadraticCurveTo(px(6.25), py(21.25), px(6.75), py(21.25))
      ctx.stroke()

      // Arched top standing on the balcony line, under the spire.
      ctx.beginPath()
      ctx.moveTo(px(7.75), py(10.75))
      ctx.lineTo(px(7.75), py(7))
      ctx.arc(px(9.25), py(7), 1.5 * u, Math.PI, Math.PI * 2, false)
      ctx.lineTo(px(10.75), py(10.5))
      ctx.closePath()
      ctx.stroke()

      // Balcony ledge and spire.
      ctx.beginPath()
      ctx.moveTo(px(6), py(10.5))
      ctx.lineTo(px(12.5), py(10.5))
      ctx.moveTo(px(9.25), py(2.75))
      ctx.lineTo(px(9.25), py(5.5))
      ctx.stroke()

      // Two concentric sound waves, bulging away from the minaret.
      ctx.beginPath()
      ctx.arc(px(11.248), py(6.5), 3.5 * u, -0.558, 0.558, false)
      ctx.stroke()
      ctx.beginPath()
      ctx.arc(px(11.248), py(6.5), 6.75 * u, -0.558, 0.558, false)
      ctx.stroke()
    }
  }
}
