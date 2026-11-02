import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../components"
import "../config"

// OpenCode Go limit windows: rolling 5h, weekly and monthly, each with the share
// used, a reset countdown and a bar. Same card frame, width, placement under
// the island and click-outside close as the prayer popup.
PanelWindow {
  id: root
  visible: false
  color: Theme.transparent
  exclusionMode: ExclusionMode.Ignore
  aboveWindows: true
  focusable: true

  property var service: null
  property int popupW: Theme.prayerPopupWidth
  // Display cutout on this output, passed the same way as the prayer popup.
  property int topInset: 0
  // The instant countdowns are measured against, pinned when the card opens.
  property double nowMs: 0

  readonly property var windowRows: [
    { key: "rolling", label: "5-hour window" },
    { key: "weekly", label: "Weekly" },
    { key: "monthly", label: "Monthly" }
  ]

  function windowOf(key) {
    var w = root.service ? root.service.windows : null
    return w && w[key] ? w[key] : null
  }

  function percentText(key) {
    var w = root.windowOf(key)
    return w ? Math.round(w.percent) + "% used" : "--"
  }

  // "2h 53m", "6d 13h" - the two largest units, like the console shows them.
  function resetText(key) {
    var w = root.windowOf(key)
    if (!w || !isFinite(w.resetsAtMs)) return "Resets: --"
    var mins = Math.max(0, Math.floor((w.resetsAtMs - root.nowMs) / 60000))
    var days = Math.floor(mins / 1440)
    var hours = Math.floor((mins % 1440) / 60)
    var m = mins % 60
    if (days > 0) return "Resets in " + days + "d " + hours + "h"
    return "Resets in " + hours + "h " + m + "m"
  }

  function fraction(key) {
    var w = root.windowOf(key)
    return w ? Math.max(0, Math.min(100, w.percent)) / 100 : 0
  }

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
    height: content.implicitHeight + Theme.chargePopupPad * 2
    x: Math.round(((root.screen ? root.screen.width : root.width) - root.popupW) / 2)
    y: root.topInset + Theme.pillHeight + Theme.popupTopGap

    Rectangle {
      anchors.fill: parent
      radius: Theme.cardRadius
      color: Theme.cardFill
      border.width: Theme.cardBorderWidth
      border.color: Theme.cardBorderColor
      CardEdges {}
    }

    ColumnLayout {
      id: content
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Theme.chargePopupPad
      spacing: Theme.chargePopupGap

      Txt {
        Layout.fillWidth: true
        text: "OPENCODE GO \u00b7 USAGE"
        variant: "caption"
        elide: Text.ElideRight
      }

      Repeater {
        model: root.windowRows

        delegate: ColumnLayout {
          id: block
          required property var modelData
          Layout.fillWidth: true
          spacing: Theme.gapTight

          RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gapSmall

            Txt {
              Layout.fillWidth: true
              text: block.modelData.label
              color: Theme.foreground
              variant: "body"
              elide: Text.ElideNone
            }
            Txt {
              horizontalAlignment: Text.AlignRight
              text: root.percentText(block.modelData.key)
              color: root.windowOf(block.modelData.key)
                ? Theme.loadColor(root.windowOf(block.modelData.key).percent) : Theme.comment
              variant: "body"
              elide: Text.ElideNone
            }
          }

          Txt {
            Layout.fillWidth: true
            text: root.resetText(block.modelData.key)
            color: Theme.comment
            variant: "caption"
            elide: Text.ElideNone
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.ramBarHeight
            radius: Theme.batteryBarRadius
            color: Theme.ringTrail

            Rectangle {
              width: parent.width * root.fraction(block.modelData.key)
              height: parent.height
              radius: Theme.batteryBarRadius
              color: root.windowOf(block.modelData.key)
                ? Theme.loadColor(root.windowOf(block.modelData.key).percent) : Theme.comment
            }
          }
        }
      }

      Txt {
        visible: !root.service || !root.service.ready
        Layout.fillWidth: true
        text: "Usage unavailable - check the opencode-go key"
        color: Theme.comment
        variant: "caption"
        elide: Text.ElideRight
      }
    }
  }

  Shortcut {
    sequence: "Escape"
    enabled: root.visible
    onActivated: root.close()
  }

  function open() {
    root.nowMs = Date.now()
    if (root.service) root.service.refresh()
    root.visible = true
  }

  function close() {
    root.visible = false
  }
}
