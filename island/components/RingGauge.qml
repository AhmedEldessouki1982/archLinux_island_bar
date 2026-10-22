import QtQuick
import "."
import "../config"

// Flat storage ring: a dim full-circle track plus a rounded arc, with the
// percentage centred inside it. The diameter is a theme token and never scales
// with the card, so every ring in the panel has the same size; its arc and
// percentage follow the shared green / yellow / orange / red disk thresholds.
//
// Both canvases repaint only when an input actually changes: an idle ring costs
// nothing and there is no animation left running when the value settles.
Item {
  id: root

  // 0..100, negative = unknown (ring drawn empty, "--" shown).
  property real value: -1
  property int diameter: Theme.ringDiameter
  property int thickness: Theme.ringThickness

  readonly property bool known: root.value >= 0
  readonly property color valueColor: root.known
    ? Theme.storageColor(root.value) : Theme.comment

  implicitWidth: root.diameter
  implicitHeight: root.diameter

  // Animated arc fraction. The Behavior only runs while the value is actually
  // changing; when it settles no timer and no repaint is left behind.
  property real fraction: root.known ? Math.max(0, Math.min(100, root.value)) / 100 : 0
  Behavior on fraction {
    NumberAnimation {
      duration: Math.min(250, Theme.animDurationFast + 100)
      easing.type: Easing.OutCubic
    }
  }

  Canvas {
    id: ringCanvas
    anchors.fill: parent
    antialiasing: true
    renderTarget: Canvas.Image

    property real fraction: root.fraction
    property color arcColor: root.valueColor
    property color trackColor: Theme.selection
    property int strokeWidth: root.thickness

    onFractionChanged: requestPaint()
    onArcColorChanged: requestPaint()
    onTrackColorChanged: requestPaint()
    onStrokeWidthChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)

      var lw = strokeWidth
      var r = (Math.min(width, height) - lw) / 2
      var cx = width / 2
      var cy = height / 2

      ctx.lineCap = "round"
      ctx.lineWidth = lw
      ctx.lineJoin = "round"

      // dim full-circle track
      ctx.beginPath()
      ctx.strokeStyle = trackColor
      ctx.arc(cx, cy, r, 0, Math.PI * 2, false)
      ctx.stroke()

      // value arc, from 12 o'clock clockwise
      if (fraction > 0) {
        ctx.beginPath()
        ctx.strokeStyle = arcColor
        var start = -Math.PI / 2
        var end = start + Math.PI * 2 * fraction
        // A tiny arc with round caps would paint a dot at 0% — start from a
        // hair above zero so the cap sits on the 12 o'clock mark.
        ctx.arc(cx, cy, r, start, Math.max(end, start + 0.0001), false)
        ctx.stroke()
      }
    }
  }

  // Percentage, centred in the ring, in the panel's value type.
  Txt {
    anchors.centerIn: parent
    width: parent.width
    height: parent.height
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    text: root.known ? Format.percent(root.value) : "--"
    color: root.valueColor
    variant: "value"
    elide: Text.ElideNone
    clip: true
  }
}
