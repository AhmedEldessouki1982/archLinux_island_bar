import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../components"
import "../config"

// Today's five prayer times, in the same frame as the charge-limit popup: the
// same card fill, radius, border, padding and width, one row per prayer instead
// of a tappable option.
//
// The data is already here - PrayerService fetched and cached it for the alarm -
// so this window does no I/O of its own. It reads `service.times` and marks the
// next prayer from the clock at the moment it was opened. The service is used
// rather than the weather card's location so what the popup lists is exactly
// what the alarms are counting down to.
PanelWindow {
  id: root
  visible: false
  color: Theme.transparent
  exclusionMode: ExclusionMode.Ignore
  aboveWindows: true
  focusable: true

  property var service: null
  property var anchorItem: null
  property int popupW: Theme.prayerPopupWidth
  // The instant "next" is measured against. Pinned when the popup opens so the
  // highlight cannot move while it is being read.
  property double nowMs: 0

  WlrLayershell.layer: WlrLayer.Overlay
  anchors.top: true
  anchors.left: true
  anchors.right: true
  anchors.bottom: true

  MouseArea {
    anchors.fill: parent
    onClicked: root.close()
  }

  Item {
    id: container
    width: root.popupW
    height: root.containerHeight
    opacity: 1
    x: 0
    y: 0

    Rectangle {
      anchors.fill: parent
      radius: Theme.cardRadius
      color: Theme.cardFill
      border.width: Theme.cardBorderWidth
      border.color: Theme.cardBorderColor
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Theme.chargePopupPad
      spacing: Theme.chargePopupGap

      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gapSmall

        Txt {
          Layout.fillWidth: true
          text: "PRAYERS"
          variant: "caption"
          elide: Text.ElideRight
        }
        Txt {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignRight
          text: root.service ? String(root.service.city || "") : ""
          color: Theme.comment
          variant: "caption"
          elide: Text.ElideRight
        }
      }

      Repeater {
        model: root.rows

        delegate: Rectangle {
          id: row
          required property var modelData
          Layout.fillWidth: true
          Layout.preferredHeight: Theme.prayerPopupRowHeight
          radius: Theme.chipRadius
          color: row.modelData.next ? Theme.chargeLimitActiveTint : Theme.transparent
          border.width: row.modelData.next ? Theme.cardBorderWidth : 0
          border.color: Theme.chargeLimitActive

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.cardPadX
            anchors.rightMargin: Theme.cardPadX
            spacing: Theme.gapSmall

            Txt {
              Layout.fillWidth: true
              text: row.modelData.name
              color: root.rowColor(row.modelData)
              variant: "body"
              elide: Text.ElideNone
            }

            Txt {
              Layout.preferredWidth: Theme.prayerPopupTimeWidth
              horizontalAlignment: Text.AlignRight
              text: row.modelData.time
              color: root.rowColor(row.modelData)
              variant: "body"
              elide: Text.ElideNone
            }
          }
        }
      }

      Txt {
        visible: root.rows.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.prayerPopupRowHeight
        text: "No times yet"
        color: Theme.comment
        variant: "body"
        elide: Text.ElideRight
      }
    }
  }

  readonly property var rows: root.buildRows()

  // Every prayer of today, plus which one is next. A time that has passed is
  // dimmed, the next one is the yellow row, the rest wait at full contrast -
  // the same "this is the active one" language as the charge-limit options.
  function buildRows() {
    var svc = root.service
    var times = svc && svc.times ? svc.times : ({})
    var names = svc && svc.prayerNames ? svc.prayerNames : []
    var now = root.nowMs
    var next = ""
    var best = Infinity
    for (var i = 0; i < names.length; i++) {
      var t = Number(times[names[i]])
      if (isFinite(t) && t >= now && t < best) {
        best = t
        next = names[i]
      }
    }
    var out = []
    for (var j = 0; j < names.length; j++) {
      var name = names[j]
      var ms = Number(times[name])
      if (!isFinite(ms)) continue
      out.push({
        name: name,
        time: Qt.formatTime(new Date(ms), "HH:mm"),
        next: name === next,
        passed: ms < now
      })
    }
    return out
  }

  function rowColor(row) {
    if (row.next) return Theme.chargeLimitActive
    return row.passed ? Theme.comment : Theme.foreground
  }

  readonly property int contentRowCount: Math.max(1, root.rows.length)
  readonly property int containerHeight: Theme.chargePopupPad * 2 + Theme.fontSizeBody
    + root.contentRowCount * Theme.prayerPopupRowHeight
    + root.contentRowCount * Theme.chargePopupGap

  Shortcut {
    sequence: "Escape"
    enabled: root.visible
    onActivated: root.close()
  }

  function open(anchor) {
    root.anchorItem = anchor || null
    root.nowMs = Date.now()
    root.visible = true
    if (root.anchorItem) {
      var point = root.anchorItem.mapToGlobal(Qt.point(0, root.anchorItem.height))
      container.x = Math.max(Theme.chargePopupPad,
        Math.min(point.x + root.anchorItem.width - root.popupW,
          (root.screen ? root.screen.width : root.width) - root.popupW - Theme.chargePopupPad))
      container.y = point.y + Theme.chargePopupOffset
    }
  }

  function close() {
    root.visible = false
  }
}
