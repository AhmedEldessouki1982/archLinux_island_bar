import QtQuick
import "../config"

// Stroke-only weather glyphs, painted once per condition or day/night change.
// No fonts, emoji, images, glow or shadow.
Item {
  id: root
  implicitWidth: 52
  implicitHeight: 52
  property int weatherCode: -1
  property bool isDay: true

  readonly property color glyphColor: Theme.cyan

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: true
    renderTarget: Canvas.Image

    property int code: root.weatherCode
    property bool day: root.isDay
    property color strokeColor: root.glyphColor

    onCodeChanged: requestPaint()
    onDayChanged: requestPaint()
    onStrokeColorChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)

      var s = Math.min(width, height)
      ctx.save()
      ctx.scale(s / 52, s / 52)

      ctx.strokeStyle = strokeColor
      ctx.lineWidth = 2.8
      ctx.lineCap = "round"
      ctx.lineJoin = "round"
      ctx.fillStyle = "transparent"

      var code = root.weatherCode
      var day = root.isDay

      function sun(cx, cy, r) {
        ctx.beginPath()
        ctx.arc(cx, cy, r, 0, Math.PI * 2)
        ctx.stroke()
        for (var i = 0; i < 8; i++) {
          var a = i * Math.PI / 4
          var ir = r + 3.2
          var or = r + 7.2
          ctx.beginPath()
          ctx.moveTo(cx + Math.cos(a) * ir, cy + Math.sin(a) * ir)
          ctx.lineTo(cx + Math.cos(a) * or, cy + Math.sin(a) * or)
          ctx.stroke()
        }
      }

      function moon(cx, cy, r) {
        // crescent silhouette drawn with two arcs
        ctx.beginPath()
        ctx.arc(cx, cy, r, 0.9 * Math.PI, -0.9 * Math.PI, true)
        ctx.stroke()
        ctx.beginPath()
        ctx.arc(cx + r * 0.38, cy, r * 0.82, -0.7 * Math.PI, 0.7 * Math.PI, false)
        ctx.stroke()
      }

      function cloud(x, y, sc) {
        // soft puff cloud, stroked only
        var baseY = y + 10 * sc
        ctx.beginPath()
        ctx.arc(x + 10 * sc, baseY, 6 * sc, Math.PI, 0)
        ctx.arc(x + 18 * sc, baseY - 2 * sc, 8 * sc, Math.PI, 0)
        ctx.arc(x + 28 * sc, baseY + 1 * sc, 6 * sc, Math.PI, 0)
        ctx.arc(x + 18 * sc, baseY + 2 * sc, 9 * sc, 0, Math.PI)
        ctx.closePath()
        ctx.stroke()
      }

      function rain(x, y, count) {
        for (var i = 0; i < count; i++) {
          var rx = x + 10 + i * 8
          var ry = y + 26
          ctx.beginPath()
          ctx.moveTo(rx, ry)
          ctx.lineTo(rx - 2, ry + 6)
          ctx.stroke()
        }
      }

      function snow(x, y, count) {
        for (var i = 0; i < count; i++) {
          var sx = x + 12 + i * 8
          var sy = y + 28
          ctx.beginPath()
          ctx.arc(sx, sy, 1.4, 0, Math.PI * 2)
          ctx.stroke()
        }
      }

      function bolt(x, y) {
        ctx.beginPath()
        ctx.moveTo(x + 20, y + 20)
        ctx.lineTo(x + 15, y + 28)
        ctx.lineTo(x + 20, y + 27)
        ctx.lineTo(x + 16, y + 34)
        ctx.stroke()
      }

      if (code === 0) {
        // clear
        if (day) sun(26, 24, 9)
        else moon(28, 24, 9)
      } else if (code >= 1 && code <= 2) {
        // partly cloudy
        if (day) sun(18, 18, 7)
        else moon(18, 18, 7)
        cloud(12, 10, 0.9)
      } else if (code === 3) {
        // cloudy
        cloud(8, 6, 1.0)
      } else if (code === 45 || code === 48) {
        // fog/haze/dust
        cloud(8, 4, 1.0)
        for (var f = 0; f < 4; f++) {
          ctx.beginPath()
          ctx.moveTo(12, 32 + f * 4)
          ctx.lineTo(40, 32 + f * 4)
          ctx.stroke()
        }
      } else if (code >= 51 && code <= 67) {
        // rain/drizzle/freezing rain
        cloud(8, 6, 1.0)
        rain(8, 6, code >= 61 ? 4 : 3)
      } else if (code >= 71 && code <= 77) {
        // snow
        cloud(8, 6, 1.0)
        snow(8, 6, 4)
      } else if (code >= 80 && code <= 82) {
        // showers
        cloud(8, 6, 1.0)
        rain(8, 6, code === 82 ? 4 : 3)
      } else if (code >= 95 && code <= 99) {
        // thunderstorm
        cloud(8, 6, 1.0)
        bolt(8, 6)
        rain(8, 10, 3)
      } else if (code === -1) {
        // unknown: show a simple disk outline
        ctx.beginPath()
        ctx.arc(26, 26, 10, 0, Math.PI * 2)
        ctx.stroke()
      } else {
        // safe default: treat like cloudy
        cloud(8, 6, 1.0)
      }

      ctx.restore()
    }
  }
}
