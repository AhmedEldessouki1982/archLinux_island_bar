import QtQuick
import QtQuick.Shapes

// DropShape — the shared "drop" silhouette used by both the island pill and
// the health panel, so their geometry is identical by construction.
//
// The surface hangs from the top edge of the screen: its top-left and
// top-right corners are *concave* (inverted) radii, so there is no seam where
// the shape meets the screen edge, and the bottom corners are ordinary convex
// radii.
//
// One closed path, one fill colour, one alpha. There are no separate ear
// items and no Rectangles layered underneath, so the ears can never show a
// seam or a different tint from the body.
//
//   (0,0)                                              (W,0)
//     ╲                                                  ╱
//      ╲__                                           __╱
//         │                                         │
//         │                 body                    │
//         │                                         │
//         ╰───────────╯                   ╰──────────╯
//
//   W = bodyWidth + 2 * earRadius      (centred on the window)
//   H = bodyHeight
//
// The border is a second, *open* path that runs from the top-left corner
// around the left, bottom and right edges — never along the top edge, so no
// line is drawn where the shape meets the screen edge.

Item {
  id: root

  // --- public geometry -----------------------------------------------------
  property real bodyWidth: 200
  property real bodyHeight: 40
  property real earRadius: 14
  property real bottomRadius: 14

  // True when the surface hangs off the top screen edge: the top corners are
  // concave ears and the top edge is the screen edge, so it is not stroked.
  // False when the surface floats (below a display cutout), where the top
  // corners become ordinary convex radii and the outline closes all the way
  // round - otherwise the shape would have no top border and read as cropped.
  property bool concaveTop: true

  // --- public paint --------------------------------------------------------
  property color fillColor: "transparent"
  property color borderColor: "transparent"
  property real borderWidth: 1

  // --- derived geometry (whole pixels) -------------------------------------
  // Both radii are clamped to half of the smaller body dimension so the shape
  // stays valid at every size, including mid-transition.
  readonly property real _limit: Math.max(1, Math.round(Math.min(bodyWidth, bodyHeight) / 2))
  readonly property real _ear: Math.max(1, Math.round(Math.min(earRadius, _limit)))
  readonly property real _bot: Math.max(1, Math.round(Math.min(bottomRadius, _limit)))

  readonly property real _w: Math.round(bodyWidth + 2 * _ear)
  readonly property real _h: Math.round(bodyHeight)

  // Half-pixel inset for the border, so a 1px stroke sits fully inside the
  // silhouette instead of straddling the outline.
  readonly property real _i: Math.max(0, borderWidth / 2)

  implicitWidth: _w
  implicitHeight: _h
  width: _w
  height: _h

  Shape {
    id: shape
    anchors.fill: parent
    antialiasing: true

    // ---- fill: one closed path -------------------------------------------
    // ---- hanging shape: concave ears on the screen edge -------------------
    // Each group is drawn only in its own mode: a ShapePath whose fill and
    // stroke are both transparent paints nothing, which is cheaper to read
    // than one path stitched from conditional arcs.
    ShapePath {
      fillColor: root.concaveTop ? root.fillColor : "transparent"
      strokeColor: "transparent"
      strokeWidth: 0
      startX: 0
      startY: 0

      // top-left concave ear: (0,0) -> (E,E), centre (0,E)
      PathArc {
        x: root._ear
        y: root._ear
        radiusX: root._ear
        radiusY: root._ear
        useLargeArc: false
        direction: PathArc.Clockwise
      }

      // left edge
      PathLine {
        x: root._ear
        y: root._h - root._bot
      }

      // bottom-left convex corner: -> (E+B, H), centre (E+B, H-B)
      PathArc {
        x: root._ear + root._bot
        y: root._h
        radiusX: root._bot
        radiusY: root._bot
        useLargeArc: false
        direction: PathArc.Counterclockwise
      }

      // bottom edge
      PathLine {
        x: root._w - root._ear - root._bot
        y: root._h
      }

      // bottom-right convex corner: -> (W-E, H-B)
      PathArc {
        x: root._w - root._ear
        y: root._h - root._bot
        radiusX: root._bot
        radiusY: root._bot
        useLargeArc: false
        direction: PathArc.Counterclockwise
      }

      // right edge (mirror of the left edge, same variables)
      PathLine {
        x: root._w - root._ear
        y: root._ear
      }

      // top-right concave ear: (W-E,E) -> (W,0), centre (W,E)
      PathArc {
        x: root._w
        y: 0
        radiusX: root._ear
        radiusY: root._ear
        useLargeArc: false
        direction: PathArc.Clockwise
      }

      // close along the top edge
      PathLine {
        x: 0
        y: 0
      }
    }

    // ---- border: open path, left + bottom + right only --------------------
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.concaveTop ? root.borderColor : "transparent"
      strokeWidth: root.borderWidth
      capStyle: ShapePath.FlatCap
      joinStyle: ShapePath.RoundJoin
      startX: root._i
      startY: root._i

      // top-left concave ear, inset
      PathArc {
        x: root._i + root._ear
        y: root._i + root._ear
        radiusX: root._ear
        radiusY: root._ear
        useLargeArc: false
        direction: PathArc.Clockwise
      }

      PathLine {
        x: root._i + root._ear
        y: root._h - root._bot - root._i
      }

      PathArc {
        x: root._i + root._ear + root._bot
        y: root._h - root._i
        radiusX: root._bot
        radiusY: root._bot
        useLargeArc: false
        direction: PathArc.Counterclockwise
      }

      PathLine {
        x: root._w - root._ear - root._bot - root._i
        y: root._h - root._i
      }

      PathArc {
        x: root._w - root._ear - root._i
        y: root._h - root._bot - root._i
        radiusX: root._bot
        radiusY: root._bot
        useLargeArc: false
        direction: PathArc.Counterclockwise
      }

      PathLine {
        x: root._w - root._ear - root._i
        y: root._ear + root._i
      }

      PathArc {
        x: root._w - root._i
        y: root._i
        radiusX: root._ear
        radiusY: root._ear
        useLargeArc: false
        direction: PathArc.Clockwise
      }

      // deliberately no closing segment: the top edge stays unstroked
    }

    // ---- floating shape: all four corners convex -------------------------
    // Used when the surface is not touching the screen edge (it hangs below a
    // display cutout instead). Radius E on top, B at the bottom, and the
    // corners are placed at E / B rather than E+B, because there is no ear
    // overhang to absorb.
    ShapePath {
      fillColor: root.concaveTop ? "transparent" : root.fillColor
      strokeColor: "transparent"
      strokeWidth: 0
      startX: root._ear
      startY: 0

      // top edge
      PathLine {
        x: root._w - root._ear
        y: 0
      }

      // top-right convex corner: -> (W,E), centre (W-E,E)
      PathArc {
        x: root._w
        y: root._ear
        radiusX: root._ear
        radiusY: root._ear
        useLargeArc: false
        direction: PathArc.Clockwise
      }

      // right edge
      PathLine {
        x: root._w
        y: root._h - root._bot
      }

      // bottom-right convex corner: -> (W-B,H), centre (W-B,H-B)
      PathArc {
        x: root._w - root._bot
        y: root._h
        radiusX: root._bot
        radiusY: root._bot
        useLargeArc: false
        direction: PathArc.Clockwise
      }

      // bottom edge
      PathLine {
        x: root._bot
        y: root._h
      }

      // bottom-left convex corner: -> (0,H-B), centre (B,H-B)
      PathArc {
        x: 0
        y: root._h - root._bot
        radiusX: root._bot
        radiusY: root._bot
        useLargeArc: false
        direction: PathArc.Clockwise
      }

      // left edge
      PathLine {
        x: 0
        y: root._ear
      }

      // top-left convex corner: -> (E,0), centre (E,E)
      PathArc {
        x: root._ear
        y: 0
        radiusX: root._ear
        radiusY: root._ear
        useLargeArc: false
        direction: PathArc.Clockwise
      }
    }

    // ---- floating border: the same outline, closed and inset -------------
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.concaveTop ? "transparent" : root.borderColor
      strokeWidth: root.borderWidth
      capStyle: ShapePath.FlatCap
      joinStyle: ShapePath.RoundJoin
      startX: root._ear + root._i
      startY: root._i

      PathLine {
        x: root._w - root._ear - root._i
        y: root._i
      }

      PathArc {
        x: root._w - root._i
        y: root._ear + root._i
        radiusX: root._ear
        radiusY: root._ear
        useLargeArc: false
        direction: PathArc.Clockwise
      }

      PathLine {
        x: root._w - root._i
        y: root._h - root._bot - root._i
      }

      PathArc {
        x: root._w - root._bot - root._i
        y: root._h - root._i
        radiusX: root._bot
        radiusY: root._bot
        useLargeArc: false
        direction: PathArc.Clockwise
      }

      PathLine {
        x: root._bot + root._i
        y: root._h - root._i
      }

      PathArc {
        x: root._i
        y: root._h - root._bot - root._i
        radiusX: root._bot
        radiusY: root._bot
        useLargeArc: false
        direction: PathArc.Clockwise
      }

      PathLine {
        x: root._i
        y: root._ear + root._i
      }

      PathArc {
        x: root._ear + root._i
        y: root._i
        radiusX: root._ear
        radiusY: root._ear
        useLargeArc: false
        direction: PathArc.Clockwise
      }

      // closed: the floating shape has a top edge to stroke
      PathLine {
        x: root._ear + root._i
        y: root._i
      }
    }
  }
}
