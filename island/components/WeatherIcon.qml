import QtQuick
import "../config"

Item {
  id: root
  implicitWidth: 32
  implicitHeight: 32

  property int weatherCode: -1
  readonly property color iconColor: root.weatherCode === 0 || (root.weatherCode >= 1 && root.weatherCode <= 3)
    ? Theme.yellow : root.weatherCode >= 51 && root.weatherCode <= 82
      ? Theme.cyan : root.weatherCode >= 95 ? Theme.orange : Theme.foreground

  Canvas {
    id: icon
    anchors.fill: parent
    renderTarget: Canvas.Image
    antialiasing: true

    function cloud(ctx, x, y, scale) {
      ctx.beginPath()
      ctx.arc(x + 8 * scale, y + 8 * scale, 5 * scale, Math.PI, 0)
      ctx.arc(x + 14 * scale, y + 6 * scale, 7 * scale, Math.PI, 0)
      ctx.arc(x + 21 * scale, y + 9 * scale, 5 * scale, Math.PI, 0)
      ctx.lineTo(x + 3 * scale, y + 9 * scale)
      ctx.stroke()
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var code = root.weatherCode
      ctx.save()
      ctx.scale(width / 32, height / 32)
      ctx.strokeStyle = root.iconColor
      ctx.fillStyle = root.iconColor
      ctx.lineWidth = 1.7
      ctx.lineCap = "round"
      ctx.lineJoin = "round"

      if (code === 0) {
        ctx.beginPath(); ctx.arc(16, 16, 6, 0, Math.PI * 2); ctx.stroke()
        for (var i = 0; i < 8; i++) {
          var a = i * Math.PI / 4
          ctx.beginPath(); ctx.moveTo(16 + Math.cos(a) * 10, 16 + Math.sin(a) * 10)
          ctx.lineTo(16 + Math.cos(a) * 13, 16 + Math.sin(a) * 13); ctx.stroke()
        }
      } else if (code >= 1 && code <= 3) {
        ctx.beginPath(); ctx.arc(11, 10, 5, 0, Math.PI * 2); ctx.stroke()
        icon.cloud(ctx, 4, 10, 1)
      } else if (code === 45 || code === 48) {
        for (var f = 0; f < 4; f++) {
          ctx.beginPath(); ctx.moveTo(5 + (f % 2) * 3, 9 + f * 5)
          ctx.lineTo(27 - ((f + 1) % 2) * 3, 9 + f * 5); ctx.stroke()
        }
      } else {
        icon.cloud(ctx, 3, 5, 1)
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
          for (var r = 0; r < 3; r++) {
            ctx.beginPath(); ctx.moveTo(10 + r * 6, 21); ctx.lineTo(8 + r * 6, 26); ctx.stroke()
          }
        } else if (code >= 71 && code <= 77) {
          for (var s = 0; s < 3; s++) {
            ctx.beginPath(); ctx.arc(9 + s * 7, 24, 1.3, 0, Math.PI * 2); ctx.fill()
          }
        } else if (code >= 95 && code <= 99) {
          ctx.beginPath(); ctx.moveTo(17, 19); ctx.lineTo(13, 25); ctx.lineTo(18, 24); ctx.lineTo(15, 29); ctx.stroke()
        }
      }
      ctx.restore()
    }

    Connections {
      target: root
      function onWeatherCodeChanged() { icon.requestPaint() }
      function onIconColorChanged() { icon.requestPaint() }
    }
  }
}
