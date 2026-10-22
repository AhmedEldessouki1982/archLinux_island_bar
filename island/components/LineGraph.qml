import QtQuick
import QtQuick.Shapes
import "../config"

Item {
  id: root

  property var samples: []
  property color color: Theme.accent
  property real maxValue: 100
  property bool active: false

  readonly property real step: width / Math.max(1, (samples ? samples.length : 1) - 1)
  property bool shiftedPath: false
  readonly property var paths: buildPaths()

  clip: true

  Repeater {
    model: 4
    Rectangle {
      required property int index
      x: 0
      y: (index + 1) * root.height / 4
      width: root.width
      height: Theme.graphBorderWidth
      color: Theme.graphGrid
    }
  }
  Repeater {
    model: 6
    Rectangle {
      required property int index
      x: (index + 1) * root.width / 6
      y: 0
      width: Theme.graphBorderWidth
      height: root.height
      color: Theme.graphGrid
    }
  }

  Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.width: Theme.graphBorderWidth
    border.color: Theme.cardBorderColor
  }

  Item {
    id: graphGroup
    width: root.width + root.step
    height: root.height

    Shape {
      width: parent.width
      height: parent.height
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        strokeColor: "transparent"
        strokeWidth: 0
        fillColor: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.18)
        PathSvg { path: root.paths.area }
      }
      ShapePath {
        strokeColor: root.color
        strokeWidth: Theme.graphLineWidth
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        PathSvg { path: root.paths.line }
      }
    }
  }

  NumberAnimation {
    id: scrollAnimation
    target: graphGroup
    property: "x"
    from: 0
    to: -root.step
    duration: Theme.graphSampleInterval
    easing.type: Easing.Linear
    onFinished: {
      root.shiftedPath = false
      graphGroup.x = 0
    }
  }

  onSamplesChanged: {
    if (!root.active || !root.samples || root.samples.length < Theme.graphSampleCount) {
      scrollAnimation.stop()
      root.shiftedPath = false
      graphGroup.x = 0
      return
    }
    scrollAnimation.stop()
    graphGroup.x = 0
    root.shiftedPath = true
    scrollAnimation.start()
  }

  onActiveChanged: {
    if (!root.active) {
      scrollAnimation.stop()
      root.shiftedPath = false
      graphGroup.x = 0
    }
  }

  function buildPaths() {
    var values = root.samples || []
    if (values.length < 2 || root.width <= 0 || root.height <= 0)
      return { line: "", area: "" }

    var n = values.length
    var dx = root.width / Math.max(1, n - 1)
    var offset = root.shiftedPath ? dx : 0
    var ys = []
    var xs = []
    for (var i = 0; i < n; i++) {
      var v = Number(values[i])
      if (!isFinite(v) || v < 0 || v > root.maxValue)
        v = i > 0 ? Number(values[i - 1]) : 0
      v = Math.max(0, Math.min(root.maxValue, v))
      xs.push(offset + i * dx)
      ys.push(root.height - (v / root.maxValue) * root.height)
    }

    var d = "M " + xs[0].toFixed(2) + " " + ys[0].toFixed(2)
    for (var j = 0; j < n - 1; j++) {
      var x0 = xs[Math.max(0, j - 1)]
      var y0 = ys[Math.max(0, j - 1)]
      var x1 = xs[j]
      var y1 = ys[j]
      var x2 = xs[j + 1]
      var y2 = ys[j + 1]
      var x3 = xs[Math.min(n - 1, j + 2)]
      var y3 = ys[Math.min(n - 1, j + 2)]
      var c1x = x1 + (x2 - x0) / 6
      var c2x = x2 - (x3 - x1) / 6
      var lo = Math.min(y1, y2)
      var hi = Math.max(y1, y2)
      var c1y = Math.max(lo, Math.min(hi, y1 + (y2 - y0) / 6))
      var c2y = Math.max(lo, Math.min(hi, y2 - (y3 - y1) / 6))
      d += " C " + c1x.toFixed(2) + " " + c1y.toFixed(2)
        + " " + c2x.toFixed(2) + " " + c2y.toFixed(2)
        + " " + x2.toFixed(2) + " " + y2.toFixed(2)
    }
    var area = d + " L " + xs[n - 1].toFixed(2) + " " + root.height.toFixed(2)
      + " L " + xs[0].toFixed(2) + " " + root.height.toFixed(2) + " Z"
    return { line: d, area: area }
  }
}
