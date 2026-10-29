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
// so this window does no I/O of its own. It reads `service.times`, but only
// after the service says those times are today's for this place: after midnight,
// or after a change of city, yesterday's list would otherwise be presented as
// today's. What it lists is exactly what the alarms are counting down to.
PanelWindow {
  id: root
  visible: false
  color: Theme.transparent
  exclusionMode: ExclusionMode.Ignore
  aboveWindows: true
  focusable: true

  property var service: null
  property int popupW: Theme.prayerPopupWidth
  // Display cutout on this output; shell.qml passes the same value it gives the
  // pill, so the card keeps its gap below the island however far down it sits.
  property int topInset: 0
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
    // Same placement as the charge-limit card: horizontally centred, top edge a
    // fixed gap below the island. Its own height therefore never moves it.
    x: Math.round(((root.screen ? root.screen.width : root.width) - root.popupW) / 2)
    y: root.topInset + Theme.pillHeight + Theme.popupTopGap

    Rectangle {
      anchors.fill: parent
      radius: Theme.cardRadius
      color: Theme.cardFill
      border.width: Theme.cardBorderWidth
      border.color: Theme.cardBorderColor

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 1
        anchors.rightMargin: 1
        anchors.topMargin: 1
        height: 1
        radius: Math.max(0, parent.radius - 1)
        color: Theme.cardHighlight
      }

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 1
        anchors.rightMargin: 1
        anchors.bottomMargin: 1
        height: 1
        radius: Math.max(0, parent.radius - 1)
        color: Theme.cardEdgeDark
      }
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
          text: root.timesKnown() ? String(root.service.city || "") : ""
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

  // The service, not this window, decides whether what it holds is today's for
  // this place. Asking it keeps a stale list from being labelled as today's.
  function timesKnown() {
    var svc = root.service
    return !!svc && typeof svc.haveTimes === "function" && svc.haveTimes()
  }

  // Every prayer of today, plus which one is next. A time that has passed is
  // dimmed, the next one is the yellow row, the rest wait at full contrast -
  // the same "this is the active one" language as the charge-limit options.
  function buildRows() {
    if (!root.timesKnown()) return []
    var svc = root.service
    var times = svc.times
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

  function open() {
    root.nowMs = Date.now()
    root.visible = true
  }

  function close() {
    root.visible = false
  }
}
