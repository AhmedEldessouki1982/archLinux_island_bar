import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../config"

PanelWindow {
  id: root
  visible: false
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  aboveWindows: true

  WlrLayershell.layer: WlrLayer.Overlay
  anchors.top: true
  anchors.left: true
  anchors.right: true
  anchors.bottom: true

  property var layer: null

  Timer {
    id: autoCloseTimer
    interval: 3000
    onTriggered: root.close()
  }

  function toggle() {
    root.visible = !root.visible
  }

  function close() {
    root.visible = false
  }

  onVisibleChanged: {
    if (root.visible) autoCloseTimer.restart()
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.close()
  }

  Rectangle {
    width: 380
    height: 320
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: 5
    anchors.topMargin: 5
    radius: 12
    color: Theme.background
    border.width: 1
    border.color: Theme.selection
    clip: true

    ColumnLayout {
      anchors.fill: parent
      spacing: 0

      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        Layout.leftMargin: 12
        Layout.rightMargin: 8

        Text {
          text: "Notifications"
          color: Theme.foreground
          font.family: Theme.fontFamily
          font.pixelSize: 12
          font.bold: true
          font.letterSpacing: 0.5
        }

        Item { Layout.fillWidth: true }

        Text {
          text: "Clear all"
          color: Theme.red
          font.family: Theme.fontFamily
          font.pixelSize: 10
          font.bold: true

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.layer) root.layer.clearHistory()
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.selection
      }

      ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: root.layer ? root.layer.historyModel : null

        delegate: Rectangle {
          width: ListView.view.width
          height: col.implicitHeight + 14
          color: "transparent"

          RowLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Text {
              text: model.appIcon !== "" ? "" : "🔔"
              color: Theme.accent
              font.family: Theme.fontFamily
              font.pixelSize: 14
              Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1

              Text {
                text: model.summary
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
              Text {
                text: model.body
                color: Theme.comment
                font.family: Theme.fontFamily
                font.pixelSize: 10
                elide: Text.ElideRight
                maximumLineCount: 2
                visible: model.body !== ""
                Layout.fillWidth: true
              }
            }

            Text {
              text: model.appName
              color: Theme.comment
              font.family: Theme.fontFamily
              font.pixelSize: 9
              Layout.alignment: Qt.AlignTop
            }
          }

          MouseArea {
            anchors.fill: parent
            onClicked: {
              root.layer.historyModel.remove(index, 1)
              if (root.layer.historyModel.count === 0) {
                root.layer.notificationCount = 0
                root.layer.showBanners = false
              }
            }
          }
        }

        Rectangle {
          anchors.fill: parent
          color: "transparent"
          visible: (root.layer ? root.layer.historyModel.count : 0) === 0

          Text {
            anchors.centerIn: parent
            text: "No notifications"
            color: Theme.comment
            font.family: Theme.fontFamily
            font.pixelSize: 11
          }
        }
      }
    }
  }
}
