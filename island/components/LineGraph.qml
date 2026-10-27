import QtQuick
import QtQuick.Shapes
import "../config"

Item {
  id: root

  property var samples: []
  property color color: Theme.accent
  property real maxValue: 100

  // Built straight from `samples`: the line steps once per sample. There is no
  // scroll animation — shifting a 60 point bezier one step per sample forced
  // the Shape to re-tessellate at the refresh rate for the whole interval,
  // which cost about 15% of a core whenever the panel was open.
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
    width: root.width
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

  function buildPaths() {
    var values = root.samples || []
    if (values.length < 2 || root.width <= 0 || root.height <= 0)
      return { line: "", area: "" }

    var n = values.length
    var dx = root.width / Math.max(1, n - 1)
    var ys = []
    var xs = []
    for (var i = 0; i < n; i++) {
      var v = Number(values[i])
      if (!isFinite(v) || v < 0 || v > root.maxValue)
        v = i > 0 ? Number(values[i - 1]) : 0
      v = Math.max(0, Math.min(root.maxValue, v))
      xs.push(i * dx)
      var usableHeight = Math.max(1, root.height - 2 * Theme.graphInset)
      ys.push(Theme.graphInset + usableHeight - (v / root.maxValue) * usableHeight)
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
