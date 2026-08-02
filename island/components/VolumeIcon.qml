import QtQuick
import "../config"

Canvas {
  id: root
  width: 108
  height: 20

  property color color: Theme.foreground
  property real volume: 0
  property bool muted: false
  property bool headphoneConnected: false

  signal scrollRequested(real delta)
  signal toggleMuteRequested()

  onVolumeChanged: requestPaint()
  onColorChanged: requestPaint()
  onMutedChanged: requestPaint()
  onHeadphoneConnectedChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.clearRect(0, 0, width, height)
    ctx.strokeStyle = root.color
    ctx.fillStyle = root.color
    ctx.lineWidth = 1.5
    ctx.lineCap = "round"
    ctx.lineJoin = "round"

    var cx = 8, cy = 10

    if (root.headphoneConnected) {
      drawHeadphone(ctx, cx, cy)
    } else {
      drawSpeaker(ctx, cx, cy)
    }

    // meter bar
    var mx = cx + 17, my = cy - 5, mw = 60, mh = 10
    ctx.strokeStyle = Theme.selection
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.rect(mx, my, mw, mh)
    ctx.stroke()

    ctx.fillStyle = root.muted ? Theme.red : (root.volume > 0 ? Theme.accent : Theme.selection)
    var fillW = Math.max(0, Math.min(mw - 2, (mw - 2) * root.volume))
    ctx.beginPath()
    ctx.rect(mx + 1, my + 1, fillW, mh - 2)
    ctx.fill()

    // slider thumb at fill end
    var thumbColor = root.muted ? Theme.red : (root.volume > 0 ? Theme.accent : Theme.selection)
    ctx.fillStyle = Theme.background
    ctx.beginPath()
    ctx.arc(mx + 1 + fillW, my + mh / 2, 3.5, 0, Math.PI * 2)
    ctx.fill()
    ctx.strokeStyle = thumbColor
    ctx.lineWidth = 1.5
    ctx.beginPath()
    ctx.arc(mx + 1 + fillW, my + mh / 2, 3.5, 0, Math.PI * 2)
    ctx.stroke()

    // percentage text
    ctx.fillStyle = root.color
    ctx.font = "bold 8px monospace"
    ctx.textAlign = "left"
    ctx.textBaseline = "bottom"
    ctx.fillText(Math.round(root.volume * 100) + "%", mx + mw + 4, cy + 6)
  }

  function drawSpeaker(ctx, cx, cy) {
    // speaker body
    ctx.beginPath()
    ctx.rect(cx - 5, cy - 4, 4, 8)
    ctx.fill()

    ctx.beginPath()
    ctx.moveTo(cx - 1, cy - 5)
    ctx.lineTo(cx + 4, cy - 9)
    ctx.lineTo(cx + 4, cy + 9)
    ctx.lineTo(cx - 1, cy + 5)
    ctx.closePath()
    ctx.fill()

    // sound waves when not muted
    if (!root.muted) {
      ctx.strokeStyle = root.color
      ctx.lineWidth = 1.5

      ctx.beginPath()
      ctx.arc(cx + 7, cy, 3, 5.8, 6.6, false)
      ctx.stroke()

      if (root.volume > 0.3) {
        ctx.beginPath()
        ctx.arc(cx + 7, cy, 6, 5.8, 6.6, false)
        ctx.stroke()
      }
    }
  }

  function drawHeadphone(ctx, cx, cy) {
    // headband arc (downward-opening)
    ctx.lineWidth = 2.5
    ctx.strokeStyle = root.color
    ctx.beginPath()
    ctx.arc(cx, cy - 2, 4.5, Math.PI * 1.15, Math.PI * 1.85, false)
    ctx.stroke()

    // left ear cup
    ctx.lineWidth = 1.5
    ctx.fillStyle = root.color
    ctx.strokeStyle = root.color
    ctx.beginPath()
    ctx.rect(cx - 5.5, cy - 1, 3.5, 6)
    ctx.fill()
    if (root.muted) {
      ctx.beginPath()
      ctx.moveTo(cx - 5.5, cy - 1)
      ctx.lineTo(cx - 2, cy + 5)
      ctx.stroke()
      ctx.beginPath()
      ctx.moveTo(cx - 2, cy - 1)
      ctx.lineTo(cx - 5.5, cy + 5)
      ctx.stroke()
    }

    // right ear cup
    ctx.beginPath()
    ctx.rect(cx + 2, cy - 1, 3.5, 6)
    ctx.fill()
    if (root.muted) {
      ctx.beginPath()
      ctx.moveTo(cx + 2, cy - 1)
      ctx.lineTo(cx + 5.5, cy + 5)
      ctx.stroke()
      ctx.beginPath()
      ctx.moveTo(cx + 5.5, cy - 1)
      ctx.lineTo(cx + 2, cy + 5)
      ctx.stroke()
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onWheel: wheel => {
      var delta = wheel.angleDelta.y > 0 ? -0.05 : 0.05
      root.scrollRequested(delta)
    }
    onClicked: root.toggleMuteRequested()
  }
}
