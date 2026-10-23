import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../components"
import "../config"

PanelWindow {
  id: root
  visible: false
  color: Theme.transparent
  exclusionMode: ExclusionMode.Ignore
  aboveWindows: true
  focusable: true

  property var batteryService: null
  property var anchorItem: null
  property int popupW: Theme.chargePopupWidth

  WlrLayershell.layer: WlrLayer.Overlay
  anchors.top: true
  anchors.left: true
  anchors.right: true
  anchors.bottom: true

  Timer {
    id: successCloseTimer
    interval: 400
    repeat: false
    onTriggered: root.close()
  }

  Connections {
    target: root.batteryService
    function onChargeLimitSetConfirmedChanged() {
      if (root.batteryService && root.batteryService.chargeLimitSetConfirmed)
        successCloseTimer.restart()
    }
  }

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
          text: root.batteryService && root.batteryService.chargeLimitRead
            ? "CHARGE LIMIT" : "LIMIT N/A"
          variant: "caption"
          elide: Text.ElideRight
        }
        Txt {
          Layout.preferredWidth: Theme.chargeLimitValueWidth
          horizontalAlignment: Text.AlignRight
          text: root.batteryService && root.batteryService.chargeLimitRead
            ? Format.percent(root.batteryService.chargeLimit)
            : (root.batteryService && root.batteryService.chargeLimitReading ? "wait" : "")
          color: root.batteryService && root.batteryService.chargeLimitRead
            ? Theme.chargeLimitActive : Theme.comment
          variant: root.batteryService && root.batteryService.chargeLimitRead ? "value" : "body"
          elide: Text.ElideRight
        }
      }

      Repeater {
        model: root.batteryService && root.batteryService.chargeLimitSupported
          && root.batteryService.chargeLimitRead ? [
          { pct: 60, detail: "Longest battery life" },
          { pct: 80, detail: "Balanced" },
          { pct: 100, detail: "Full capacity" }
        ] : []

        delegate: Rectangle {
          id: option
          required property var modelData
          Layout.fillWidth: true
          Layout.preferredHeight: Theme.chargePopupRowHeight
          radius: Theme.chipRadius
          color: root.isActive(modelData.pct) ? Theme.chargeLimitActiveTint
            : (rowMouse.containsMouse ? Theme.cardHoverFill : Theme.cardFill)
          border.width: Theme.cardBorderWidth
          border.color: root.isActive(modelData.pct) ? Theme.chargeLimitActive : Theme.cardBorderColor

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.batteryService && !root.batteryService.chargeLimitReading
              && !root.batteryService.chargeLimitSetting
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.batteryService) root.batteryService.setLimit(option.modelData.pct)
            }
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.cardPadX
            anchors.rightMargin: Theme.cardPadX
            spacing: Theme.gapSmall

            Rectangle {
              Layout.preferredWidth: Theme.chargeRadioSize
              Layout.preferredHeight: Theme.chargeRadioSize
              radius: Theme.chargeRadioSize / 2
              color: Theme.transparent
              border.width: Theme.cardBorderWidth
              border.color: root.isActive(option.modelData.pct)
                ? Theme.chargeLimitActive : Theme.comment
              Rectangle {
                anchors.centerIn: parent
                width: Theme.chargeRadioDot
                height: Theme.chargeRadioDot
                radius: Theme.chargeRadioDot / 2
                visible: root.isActive(option.modelData.pct)
                color: Theme.chargeLimitActive
              }
            }

            Txt {
              Layout.preferredWidth: Theme.chargeLimitValueWidth
              text: Format.percent(option.modelData.pct)
              color: root.isActive(option.modelData.pct)
                ? Theme.chargeLimitActive : Theme.foreground
              variant: "value"
              elide: Text.ElideNone
            }

            Txt {
              Layout.fillWidth: true
              text: option.modelData.detail
              variant: "caption"
              elide: Text.ElideRight
            }
          }
        }
      }

      Txt {
        visible: root.batteryService && root.batteryService.chargeLimitError
        Layout.fillWidth: true
        text: "Could not set limit"
        color: Theme.red
        variant: "caption"
        elide: Text.ElideNone
      }
    }
  }

  readonly property int optionCount: root.batteryService && root.batteryService.chargeLimitSupported
    && root.batteryService.chargeLimitRead ? 3 : 0
  readonly property int contentRowCount: 1 + root.optionCount
    + (root.batteryService && root.batteryService.chargeLimitError ? 1 : 0)
  readonly property int containerHeight: Theme.chargePopupPad * 2 + Theme.fontSizeValue
    + root.optionCount * Theme.chargePopupRowHeight
    + (root.batteryService && root.batteryService.chargeLimitError ? Theme.fontSizeCaption : 0)
    + Math.max(0, root.contentRowCount - 1) * Theme.chargePopupGap

  Shortcut {
    sequence: "Escape"
    enabled: root.visible
    onActivated: root.close()
  }

  function isActive(pct) {
    return root.batteryService !== null && root.batteryService.chargeLimitRead
      && root.batteryService.chargeLimit === pct
  }

  function open(anchor) {
    root.anchorItem = anchor || null
    if (root.batteryService) root.batteryService.refreshChargeLimit()
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
    successCloseTimer.stop()
    root.visible = false
  }
}
