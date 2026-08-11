import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../config"

PanelWindow {
  id: root
  visible: false
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  aboveWindows: true

  property var batteryService: null
  property int popupW: 260

  WlrLayershell.layer: WlrLayer.Overlay

  anchors.top: true
  anchors.left: true
  anchors.right: true
  anchors.bottom: true

  Timer {
    id: autoCloseTimer
    interval: 6000
    onTriggered: root.close()
  }

  onVisibleChanged: {
    if (root.visible) autoCloseTimer.restart()
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.close()
  }

  Item {
    id: container
    width: root.popupW
    height: 12 + 20 + 8 + 46 * 3 + 8 * 2 + 12
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.topMargin: 44
    opacity: 0

    Behavior on opacity {
      NumberAnimation { duration: Theme.animDurationNormal; easing: Easing.OutQuad }
    }

    Rectangle {
      id: card
      anchors.fill: parent
      radius: 12
      color: Theme.background
      border.width: 1
      border.color: Theme.selection
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      anchors.topMargin: 12
      anchors.bottomMargin: 12
      spacing: 8

      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
          text: "CHARGE LIMIT"
          color: Theme.comment
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeLabel
          font.bold: true
          font.letterSpacing: 1.2
          Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        Text {
          text: root.batteryService ? root.batteryService.chargeLimit + "%" : "--"
          color: Theme.yellow
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeValue
          font.bold: true
          Layout.alignment: Qt.AlignVCenter
        }
      }

      Repeater {
        model: [
          { pct: 58, title: "Max Protection", sub: "Limit charging to 58%" },
          { pct: 79, title: "Balanced Protection", sub: "Limit charging to 79%" },
          { pct: 100, title: "Fully Charged", sub: "Allow charging to 100%" }
        ]

        delegate: Rectangle {
          required property var modelData
          Layout.fillWidth: true
          Layout.preferredHeight: 46
          radius: 8
          color: root.cardColorFor(root.isActive(modelData.pct))
          border.width: 1
          border.color: root.isActive(modelData.pct) ? Theme.yellow : root.cardBorderColor()
          antialiasing: true

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.batteryService) root.batteryService.setLimit(modelData.pct)
              root.close()
            }
          }

          RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            Rectangle {
              width: 14
              height: 14
              radius: 7
              border.width: 2
              border.color: root.isActive(modelData.pct) ? Theme.yellow : Theme.comment
              color: "transparent"
              Layout.alignment: Qt.AlignVCenter

              Rectangle {
                width: 6
                height: 6
                radius: 3
                anchors.centerIn: parent
                visible: root.isActive(modelData.pct)
                color: Theme.yellow
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1

              Text {
                text: modelData.title
                color: root.isActive(modelData.pct) ? Theme.yellow : Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeValue
                font.bold: true
              }

              Text {
                text: modelData.sub
                color: Theme.comment
                font.family: Theme.fontFamily
                font.pixelSize: 11
              }
            }
          }
        }
      }
    }
  }

  function isActive(pct) {
    return root.batteryService !== null && root.batteryService.chargeLimit === pct
  }

  function cardColorFor(active) {
    return active ? Qt.rgba(Theme.yellow.r, Theme.yellow.g, Theme.yellow.b, 0.12)
                  : Qt.rgba(Theme.selection.r, Theme.selection.g, Theme.selection.b, 0.3)
  }

  function cardBorderColor() {
    return Qt.rgba(Theme.selection.r, Theme.selection.g, Theme.selection.b, 0.55)
  }

  function open() {
    root.visible = true
    container.opacity = 0
    container.opacity = 1
  }

  function close() {
    container.opacity = 0
    root.visible = false
  }
}
