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

  Timer {
    id: autoCloseTimer
    interval: 5000
    onTriggered: root.close()
  }

  property int year: new Date().getFullYear()
  property int month: new Date().getMonth()

  property int cw: 260
  property int ch: 280

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: root.rebuild()
  }

  ListModel { id: gridModel }

  function rebuild() {
    gridModel.clear()
    var first = new Date(root.year, root.month, 1)
    var startDow = first.getDay()
    var days = new Date(root.year, root.month + 1, 0).getDate()
    var now = new Date()
    for (var i = 0; i < startDow; i++)
      gridModel.append({ label: "", isToday: false, isPast: false })
    for (var d = 1; d <= days; d++) {
      gridModel.append({
        label: String(d),
        isToday: d === now.getDate() && root.month === now.getMonth() && root.year === now.getFullYear(),
        isPast: new Date(root.year, root.month, d) < new Date(now.getFullYear(), now.getMonth(), now.getDate())
      })
    }
  }

  function prevMonth() {
    root.month -= 1
    if (root.month < 0) {
      root.month = 11
      root.year -= 1
    }
    root.rebuild()
  }

  function nextMonth() {
    root.month += 1
    if (root.month > 11) {
      root.month = 0
      root.year += 1
    }
    root.rebuild()
  }

  function toggle() {
    root.visible = !root.visible
    if (root.visible) root.rebuild()
  }

  function close() {
    root.visible = false
  }

  onVisibleChanged: {
    if (root.visible) autoCloseTimer.restart()
  }

  Component.onCompleted: {
    root.rebuild()
    root.cw = Math.max(260, contentLayout.implicitWidth + 24)
    root.ch = Math.max(260, contentLayout.implicitHeight + 24)
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.close()
  }

  Rectangle {
    width: root.cw
    height: root.ch
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.topMargin: 46
    radius: 12
    color: Theme.background
    border.width: 1
    border.color: Theme.selection

    MouseArea {
      anchors.fill: parent
      onClicked: {}
    }

    ColumnLayout {
      id: contentLayout
      anchors.fill: parent
      anchors.margins: 12
      spacing: 8

      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
          text: "◀"
          color: Theme.comment
          font.pixelSize: 10

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.prevMonth()
          }
        }

        Text {
          text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
          color: Theme.foreground
          font.pixelSize: 12
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
          Layout.fillWidth: true
        }

        Text {
          text: "▶"
          color: Theme.comment
          font.pixelSize: 10

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.nextMonth()
          }
        }
      }

      Grid {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        columns: 7
        spacing: 2

        Repeater {
          model: ["S", "M", "T", "W", "T", "F", "S"]

          Text {
            width: 30
            height: 18
            text: modelData
            color: Theme.comment
            font.pixelSize: 8
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
        }
      }

      Grid {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        columns: 7
        spacing: 2

        Repeater {
          model: gridModel

          Rectangle {
            required property string label
            required property bool isToday
            required property bool isPast
            width: 30
            height: 30
            radius: 15
            color: isToday ? Theme.accent : "transparent"

            Text {
              anchors.centerIn: parent
              text: parent.label
              color: isToday ? Theme.background
                             : (isPast ? Theme.comment : Theme.foreground)
              font.pixelSize: 11
              font.bold: isToday
            }
          }
        }
      }
    }
  }
}
