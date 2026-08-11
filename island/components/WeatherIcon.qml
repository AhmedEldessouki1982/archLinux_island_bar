import QtQuick
import "../config"

Canvas {
  id: root
  antialiasing: true
  width: Theme.iconSize
  height: Theme.iconSize

  property int weatherCode: 0

  onWeatherCodeChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.clearRect(0, 0, width, height)
    ctx.strokeStyle = Theme.yellow
    ctx.fillStyle = Theme.yellow
    ctx.lineWidth = Theme.iconLineWidth
    ctx.lineCap = "round"
    ctx.lineJoin = "round"

    if (root.weatherCode === 0) {
      drawSun(ctx)
    } else if (root.weatherCode <= 3) {
      drawSun(ctx)
      drawCloud(ctx, 9, 9, 0.7, 0.7)
    } else if (root.weatherCode === 45 || root.weatherCode === 48) {
      drawFog(ctx)
    } else if ((root.weatherCode >= 51 && root.weatherCode <= 67) ||
               (root.weatherCode >= 80 && root.weatherCode <= 82)) {
      drawCloud(ctx, 8, 7, 1, 1)
      drawRain(ctx)
    } else if (root.weatherCode >= 71 && root.weatherCode <= 77) {
      drawCloud(ctx, 8, 7, 1, 1)
      drawSnow(ctx)
    } else if (root.weatherCode >= 95 && root.weatherCode <= 99) {
      drawCloud(ctx, 8, 6, 1, 1)
      drawBolt(ctx)
    } else {
      drawCloud(ctx, 8, 8, 1, 1)
    }
  }

  function drawSun(ctx) {
    ctx.beginPath()
    ctx.arc(6, 6, 2.6, 0, Math.PI * 2)
    ctx.stroke()
    for (var i = 0; i < 4; i++) {
      var a = i * Math.PI / 2
      ctx.beginPath()
      ctx.moveTo(6 + Math.cos(a) * 4, 6 + Math.sin(a) * 4)
      ctx.lineTo(6 + Math.cos(a) * 5.8, 6 + Math.sin(a) * 5.8)
      ctx.stroke()
    }
  }

  function drawCloud(ctx, cx, cy, sx, sy) {
    ctx.beginPath()
    ctx.arc(cx - 2.5 * sx, cy, 2 * sx, 0, Math.PI * 2)
    ctx.moveTo(cx - 2.5 * sx + 2 * sx, cy)
    ctx.arc(cx, cy - 1.5 * sy, 2.4 * sx, Math.PI, 0, true)
    ctx.moveTo(cx + 2.4 * sx, cy - 1.5 * sy + 2.4 * sy)
    ctx.arc(cx + 3 * sx, cy, 2 * sx, Math.PI * 0.5, Math.PI * 1.5, false)
    ctx.lineTo(cx - 2.5 * sx, cy + 2 * sx)
    ctx.stroke()
  }

  function drawRain(ctx) {
    ctx.strokeStyle = Theme.cyan
    for (var i = 0; i < 3; i++) {
      ctx.beginPath()
      ctx.moveTo(5 + i * 2.5, 12)
      ctx.lineTo(4 + i * 2.5, 14.5)
      ctx.stroke()
    }
  }

  function drawSnow(ctx) {
    ctx.strokeStyle = Theme.cyan
    for (var i = 0; i < 3; i++) {
      var x = 5 + i * 2.5
      ctx.beginPath()
      ctx.arc(x, 13, 1, 0, Math.PI * 2)
      ctx.stroke()
    }
  }

  function drawFog(ctx) {
    ctx.strokeStyle = Theme.foreground
    for (var i = 0; i < 3; i++) {
      ctx.beginPath()
      var y = 6 + i * 2.8
      ctx.moveTo(3, y)
      ctx.lineTo(13, y)
      ctx.stroke()
    }
  }

  function drawBolt(ctx) {
    ctx.fillStyle = Theme.yellow
    ctx.strokeStyle = "transparent"
    ctx.beginPath()
    ctx.moveTo(9, 9)
    ctx.lineTo(7, 12.5)
    ctx.lineTo(8.5, 12.5)
    ctx.lineTo(7.5, 14.5)
    ctx.lineTo(11, 10.5)
    ctx.lineTo(9.5, 10.5)
    ctx.closePath()
    ctx.fill()
  }
}
