import QtQuick
import "../config"

// Flat ring gauge: dim full-circle track plus a rounded-cap arc that is drawn
// over it. Everything is painted in two small canvases (ring + drive glyph),
// and both repaint only when their inputs change, so an idle gauge costs
// nothing.
Item {
  id: root

  // 0..100, negative = unknown (ring drawn empty, "--" shown).
  property real value: -1
  property string label: ""
  property string subLabel: ""
  property string iconType: "drive"

  property int diameter: 58
  property int thickness: 4

  readonly property bool known: root.value >= 0
  readonly property real clamped: Math.max(0, Math.min(100, root.value))
  readonly property color valueColor: root.known ? Theme.diskColor(root.value) : Theme.comment
  readonly property int glyphSize: Math.round(root.diameter * 0.26)

  implicitWidth: root.diameter
  implicitHeight: root.diameter + (root.label !== "" ? 32 : 0)
  width: implicitWidth
  height: implicitHeight

  // Animated arc fraction. The Behavior only runs while the value is actually
  // changing; when it settles there is no timer and no repaint left behind.
  property real fraction: root.known ? root.clamped / 100 : 0
  Behavior on fraction {
    NumberAnimation {
      duration: Math.min(250, Theme.animDurationFast + 100)
      easing.type: Easing.OutCubic
    }
  }

  Canvas {
    id: ringCanvas
    x: 0
    y: 0
    width: root.diameter
    height: root.diameter
    antialiasing: true
    renderTarget: Canvas.Image

    property real fraction: root.fraction
    property color arcColor: root.valueColor
    property color trackColor: Qt.rgba(Theme.selection.r, Theme.selection.g, Theme.selection.b, 0.85)
    property int strokeWidth: root.thickness

    onFractionChanged: requestPaint()
    onArcColorChanged: requestPaint()
    onTrackColorChanged: requestPaint()
    onStrokeWidthChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)

      var lw = strokeWidth
      var r = (width - lw) / 2
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
        // a tiny arc with round caps would paint a dot at 0% — start from a
        // hair above zero so the cap sits on the 12 o'clock mark
        ctx.arc(cx, cy, r, start, Math.max(end, start + 0.0001), false)
        ctx.stroke()
      }
    }
  }

  // Drive glyph, painted once per size/colour change.
  Canvas {
    id: glyphCanvas
    width: root.glyphSize
    height: root.glyphSize
    anchors.horizontalCenter: parent.horizontalCenter
    y: root.diameter * 0.30
    antialiasing: true
    renderTarget: Canvas.Image

    property color strokeColor: root.known ? root.valueColor : Theme.comment
    property string glyph: root.iconType

    onStrokeColorChanged: requestPaint()
    onGlyphChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)

      var s = Math.min(width, height)
      ctx.strokeStyle = strokeColor
      ctx.lineWidth = Math.max(1, s * 0.09)
      ctx.lineCap = "round"
      ctx.lineJoin = "round"

      // A disk drive in side view: a wide rounded rectangle with a small
      // activity slot on the lower left and a dot on the lower right.
      var w = s * 0.86
      var h = s * 0.58
      var x = (width - w) / 2
      var y = (height - h) / 2
      var rr = h * 0.2

      ctx.beginPath()
      ctx.moveTo(x + rr, y)
      ctx.lineTo(x + w - rr, y)
      ctx.quadraticCurveTo(x + w, y, x + w, y + rr)
      ctx.lineTo(x + w, y + h - rr)
      ctx.quadraticCurveTo(x + w, y + h, x + w - rr, y + h)
      ctx.lineTo(x + rr, y + h)
      ctx.quadraticCurveTo(x, y + h, x, y + h - rr)
      ctx.lineTo(x, y + rr)
      ctx.quadraticCurveTo(x, y, x + rr, y)
      ctx.stroke()

      // activity slot
      ctx.beginPath()
      ctx.moveTo(x + w * 0.2, y + h * 0.68)
      ctx.lineTo(x + w * 0.46, y + h * 0.68)
      ctx.stroke()

      // indicator dot
      ctx.beginPath()
      ctx.fillStyle = strokeColor
      ctx.arc(x + w * 0.76, y + h * 0.68, Math.max(0.7, s * 0.055), 0, Math.PI * 2, false)
      ctx.fill()
    }
  }

  // Percentage, centred in the ring, monospace by way of the theme font.
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    y: root.diameter * 0.46
    text: root.known ? Math.round(root.value) + "%" : "--"
    color: root.known ? Theme.foreground : Theme.comment
    font.family: Theme.fontFamily
    font.pixelSize: Math.max(9, Math.round(root.diameter * 0.22))
    font.bold: true
  }

  Column {
    visible: root.label !== ""
    anchors.horizontalCenter: parent.horizontalCenter
    y: root.diameter + 4
    spacing: 1

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.label
      color: Theme.comment
      font.family: Theme.fontFamily
      font.pixelSize: 9
      font.bold: true
      font.letterSpacing: 1.1
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      visible: root.subLabel !== ""
      text: root.subLabel
      color: root.known ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.62) : Theme.comment
      font.family: Theme.fontFamily
      font.pixelSize: 9
    }
  }
}
